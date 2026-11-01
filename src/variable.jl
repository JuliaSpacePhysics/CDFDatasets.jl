# Default of the check keywords: read the attribute.
struct FromAttrib end

# ISTP requires FILLVAL on support_data too, where integers are mostly flags and status codes:
# only `data` integers default to their attributes. Per ISTP, components run along dimension 1;
# lengths fit them like `SpaceDataModel.ValidityChecks(x)`.
function _resolve_checks(checks, data, md)
    useattrib = eltype(data) <: AbstractFloat || get(md, "VAR_TYPE", nothing) == "data"
    n = ndims(data) > 1 ? size(data, 1) : 1
    return map(checks, ("FILLVAL", "VALIDMIN", "VALIDMAX")) do c, key
        c isa FromAttrib || return c
        return useattrib ? SDM._fit(get(md, key, nothing), n) : nothing
    end
end

_hascomponents(m) = !isnothing(m) && any(v -> length(v) > 1, (m.fillval, m.validmin, m.validmax))

"""
    CDFVariable(data, name, parentdataset, metadata; fillval, validmin, validmax)

Variable whose reads replace fill and out-of-range values by `NaN` (see [`variable`](@ref)).
"""
struct CDFVariable{T, N, A <: AbstractArray{<:Any, N}, S, P, MD, M <: Union{Nothing, SDM.ValidityChecks}} <: AbstractCDFVariable{T, N}
    data::A
    name::S
    parentdataset::P
    metadata::MD
    mask::M
    function CDFVariable{T}(data::AbstractArray{<:Any, N}, name, parentdataset, metadata, mask) where {T, N}
        return new{T, N, typeof(data), typeof(name), typeof(parentdataset), typeof(metadata), typeof(mask)}(data, name, parentdataset, metadata, mask)
    end
end

CDFVariable(data::AbstractArray{R}, name, parentdataset, metadata, mask::Nothing) where {R} =
    CDFVariable{R}(data, name, parentdataset, metadata, mask)
CDFVariable(data, name, parentdataset, metadata, mask::SDM.ValidityChecks) =
    CDFVariable{_decoded(mask)}(data, name, parentdataset, metadata, mask)

_decoded(::SDM.ValidityChecks{C}) where {C} = C

# Float variables always get checks, as no-ops without attributes, so they share one type and read
# path; `nothing` keeps an integer variable's stored type.
function CDFVariable(data, name, parentdataset, metadata; fillval = FromAttrib(), validmin = FromAttrib(), validmax = FromAttrib())
    fillval, validmin, validmax = _resolve_checks((fillval, validmin, validmax), data, metadata)
    T = eltype(data)
    checked = T <: AbstractFloat || T <: Real && !all(isnothing, (fillval, validmin, validmax))
    mask = checked ? SDM.ValidityChecks(T, fillval, validmin, validmax) : nothing
    return CDFVariable(data, name, parentdataset, metadata, mask)
end

Base.getproperty(var::CDFVariable, s::Symbol) = s === :attrib ? CDM.attrib(var) : getfield(var, s)
Base.propertynames(var::CDFVariable, private::Bool = false) = (fieldnames(CDFVariable)..., :attrib)

Base.parent(var::CDFVariable) = getfield(var, :data)
_mask(var::CDFVariable) = getfield(var, :mask)
Base.size(var::CDFVariable) = size(parent(var))

rebuild(var::CDFVariable{T}, data, mask = _mask(var)) where {T} = CDFVariable{T}(data, CDM.name(var), getfield(var, :parentdataset), CDM.attrib(var), mask)

function Base.view(var::CDFVariable, I...)
    m = _mask(var)
    if _hascomponents(m)
        # Linear indexing mixes components; decode first.
        length(I) == 1 && ndims(var) > 1 && return view(Array(var), I...)
        m = m[first(to_indices(var, I))]
    end
    return rebuild(var, view(parent(var), I...), m)
end

Base.reshape(var::CDFVariable, dims::Dims) =
    _hascomponents(_mask(var)) ? reshape(Array(var), dims) : rebuild(var, reshape(parent(var), dims))

function readregion!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    m = _mask(a)
    isnothing(m) ? readregion!(parent(a), aout, inds...) : _readmasked!(parent(a), aout, m, inds)
    return aout
end

function _readmasked!(data, aout, m, inds)
    # The kernel runs on `Array`s only: on a view it would compile generic reshaped-view indexing.
    # Float data is read straight into `aout` and masked in place.
    inplace = aout isa Array && eltype(aout) === eltype(data)
    raw = inplace ? aout : Array{eltype(data)}(undef, size(aout))
    readregion!(data, raw, inds...)
    out = aout isa Array ? aout : similar(raw, eltype(aout))
    SDM.mask_invalid!(out, raw, m[inds[1]], 1)
    out === aout || copyto!(aout, out)
    return aout
end

CDM.name(var::CDFVariable) = getfield(var, :name)
CDM.dataset(var::CDFVariable) = getfield(var, :parentdataset)
CDM.attribnames(var::CDFVariable) = keys(CDM.attrib(var))
CDM.attrib(var::CDFVariable) = getfield(var, :metadata)
CDM.attrib(var::CDFVariable, name::String) = CDM.attrib(var)[name]
CDM.variable(var::CDFVariable, name::String) = variable(dataset(var), name)

# File variable backing `var`, through storage wrappers.
_filevar(var::CDFVariable) = _filevar(parent(var))
_filevar(data) = data
_filevar(data::FileArray) = data.var
_filevar(data::SubArray) = _filevar(parent(data))

function CDM.dimnames(var::CDFVariable, i::Int)
    d = get(CDM.attrib(var), _isrecorddim(var, i) ? "DEPEND_0" : "DEPEND_$(_storeddim(var, i))", nothing)
    return d isa AbstractString ? String(d) : nothing
end

CDM.dimnames(var::CDFVariable) = ntuple(i -> dimnames(var, i), ndims(var))

is_virtual(var) = get(var.attrib, "VIRTUAL", nothing) == "TRUE"

# Name of the variable backing dimension `i`, after the DEPEND_TIME swap (see `depend_time`).
function dimvarname(var::CDFVariable, i::Int)
    dname = dimnames(var, i)
    # Some CDAWeb masters name a DEPEND missing from the file (`po_h1_tim` `Start_epoch`).
    (isnothing(dname) || !haskey(dataset(var), dname)) && return nothing
    swap = _isrecorddim(var, i) && "DEPEND_TIME" in attribnames(var) && is_virtual(dataset(var)[dname])
    return swap ? attrib(var, "DEPEND_TIME") : dname
end

"""
    depend(var, i) :: Union{CDFVariable, Nothing}

Coordinate variable backing dimension `i` of `var`, or `nothing` when the
dimension has no DEPEND.
"""
function depend(var::CDFVariable, i::Int)
    dname = dimvarname(var, i)
    isnothing(dname) && return nothing
    return dname == dimnames(var, i) ? dataset(var)[dname] : depend_time(var)
end

# Indices of a view into the stored variable (Base flattens nested views), whose integer
# indices drop dimensions: attributes such as `DEPEND_i` number the stored dimensions.
_viewindices(var::CDFVariable) = _viewindices(parent(var))
_viewindices(data::SubArray) = parentindices(data)
_viewindices(data) = nothing

function _storeddim(var::CDFVariable, i)
    inds = _viewindices(var)
    isnothing(inds) && return i
    return findall(map(x -> !(x isa Integer), inds))[i]
end

# The record dimension is the last stored one.
function _isrecorddim(var::CDFVariable, i)
    inds = _viewindices(var)
    return _storeddim(var, i) == (isnothing(inds) ? ndims(var) : length(inds))
end

# The coordinate of the stored variable, sliced like `var`: along its values (first) and records (last).
function depend(var::CDFVariable{T, N, <:SubArray}, i::Int) where {T, N}
    whole = rebuild(var, parent(parent(var)))
    inds, s, R = _viewindices(var), _storeddim(var, i), ndims(whole)
    dvar = depend(whole, s)
    isnothing(dvar) && return nothing
    # A coordinate with other records (e.g. a virtual DEPEND_0 without any) is left whole, not to fit.
    records = size(dvar, ndims(dvar)) == size(whole, R) && (eltype(dvar) <: AbstractDateTime || is_record_varying(dvar))
    s == R && return records ? view(dvar, inds[R]) : dvar
    size(dvar, 1) == size(whole, s) || return dvar
    if records && ndims(dvar) > 1
        return view(dvar, inds[s], ntuple(_ -> :, ndims(dvar) - 2)..., inds[R])
    end
    return view(dvar, inds[s], ntuple(_ -> :, ndims(dvar) - 1)...)
end

CDM.dim(var::CDFVariable, i::Int) = @something depend(var, i) axes(parent(var), i)

cdf_type(var::CDF.CDFVariable) = var.datatype
cdf_type(var::CDFVariable) = cdf_type(_filevar(var))
CDF.is_record_varying(var::CDFVariable) = is_record_varying(_filevar(var))

# https://github.com/JuliaSpacePhysics/CDFDatasets.jl/issues/23
function depend_time(var)
    @debug "Non compliant CDF file, swapping DEPEND_0 with DEPEND_TIME"
    dimvar = dataset(var)[attrib(var, "DEPEND_TIME")]
    return CDFVariable(Mapped(unix2timestamp, parent(dimvar)), CDM.name(dimvar), dataset(dimvar), CDM.attrib(dimvar))
end

# Lazy `f.(parent)`
struct Mapped{T, N, F, P <: AbstractArray{<:Any, N}} <: AbstractLazyArray{T, N}
    f::F
    parent::P
end
Mapped(f, p::AbstractArray) = Mapped{Base.promote_op(f, eltype(p)), ndims(p), typeof(f), typeof(p)}(f, p)
Base.size(m::Mapped) = size(m.parent)
Base.parent(m::Mapped) = m.parent
_filevar(m::Mapped) = _filevar(parent(m))
function readregion!(m::Mapped, dest, inds::AbstractUnitRange...)
    raw = Array{eltype(m.parent)}(undef, map(length, inds))
    readregion!(m.parent, raw, inds...)
    dest .= m.f.(raw)
    return dest
end

# Float64 Unix seconds resolve only ~0.2 µs today; rounding to µs recovers decimal values
# that truncation to ns usually puts just below (e.g. .123 s -> .122999808 s).
unix2timestamp(x::AbstractFloat) = reinterpret(Timestamp{Nanosecond}, 1000 * round(Int64, 1.0e6 * x))
unix2timestamp(x::Real) = Durations.unix2timestamp(Timestamp{Nanosecond}, x)

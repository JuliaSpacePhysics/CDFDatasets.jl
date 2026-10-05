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
# path; `nothing` keeps an integer variable's stored type. In-memory data is stored decoded, so
# `Array`-backed variables read `data` directly.
function CDFVariable(data, name, parentdataset, metadata; fillval = FromAttrib(), validmin = FromAttrib(), validmax = FromAttrib())
    fillval, validmin, validmax = _resolve_checks((fillval, validmin, validmax), data, metadata)
    T = eltype(data)
    checked = T <: AbstractFloat || T <: Real && !all(isnothing, (fillval, validmin, validmax))
    mask = checked ? SDM.ValidityChecks(T, fillval, validmin, validmax) : nothing
    data isa Array && !isnothing(mask) &&
        return CDFVariable(SDM.mask_invalid!(similar(data, _decoded(mask)), data, mask, 1), name, parentdataset, metadata, nothing)
    return CDFVariable(data, name, parentdataset, metadata, mask)
end

# Fields are read with `getfield`: CommonDataModel's `getproperty` (for `.attrib` and `.dim`) is not
# always constant-folded, and then boxes `var` on every access.
Base.parent(var::CDFVariable) = getfield(var, :data)
# Methods on `CDFVariable{T, N, <:Array}` and on other storage types intersect at this uninhabited type,
# where `getfield` would be a JET error.
Base.parent(var::CDFVariable{T, N, Union{}}) where {T, N} = throw(MethodError(parent, (var,)))
_mask(var::CDFVariable) = getfield(var, :mask)
Base.size(var::CDFVariable) = size(parent(var))

rebuild(var::CDFVariable{T}, data, mask = _mask(var)) where {T} = CDFVariable{T}(data, CDM.name(var), getfield(var, :parentdataset), CDM.attrib(var), mask)

function Base.view(var::CDFVariable, I...)
    m = _mask(var)
    if _hascomponents(m)
        # Linear indexing mixes components; decode first.
        length(I) == 1 && ndims(var) > 1 && return view(materialize(var), I...)
        m = m[first(to_indices(var, I))]
    end
    return rebuild(var, view(parent(var), I...), m)
end

Base.reshape(var::CDFVariable, dims::Dims) =
    _hascomponents(_mask(var)) ? reshape(materialize(var), dims) : rebuild(var, reshape(parent(var), dims))

function DiskArrays.readblock!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    m = _mask(a)
    isnothing(m) ? _readraw!(parent(a), aout, inds...) : _readmasked!(parent(a), aout, m, inds)
    return aout
end

# Function barrier: DiskArrays may infer `aout` abstractly (e.g. `Array{Float32}`), which would
# compile this path generically for every variable type.
function _readmasked!(data, aout, m, inds)
    # The kernel runs on `Array`s only: on a view it would compile generic reshaped-view indexing.
    # Float data is read straight into `aout` and masked in place.
    inplace = aout isa Array && eltype(aout) === eltype(data)
    raw = _readraw!(data, inplace ? aout : Array{eltype(data)}(undef, size(aout)), inds...)
    out = aout isa Array ? aout : similar(raw, eltype(aout))
    SDM.mask_invalid!(out, raw, m[inds[1]], 1)
    out === aout || copyto!(aout, out)
    return aout
end

_readraw!(d::AbstractDiskArray, aout, inds...) = (DiskArrays.readblock!(d, aout, inds...); aout)
_readraw!(d, aout, inds...) = copyto!(aout, view(d, inds...))

DiskArrays.eachchunk(var::CDFVariable{T, N, <:AbstractDiskArray}) where {T, N} =
    DiskArrays.eachchunk(parent(var))

CDM.name(var::CDFVariable) = getfield(var, :name)
CDM.dataset(var::CDFVariable) = getfield(var, :parentdataset)
CDM.attribnames(var::CDFVariable) = keys(CDM.attrib(var))
CDM.attrib(var::CDFVariable) = getfield(var, :metadata)
CDM.attrib(var::CDFVariable, name::String) = CDM.attrib(var)[name]
CDM.variable(var::CDFVariable, name::String) = variable(dataset(var), name)

_parent1(data) = data
_parent1(data::CDFVariable) = _parent1(parent(data))
_parent1(data::DiskArrays.ConcatDiskArray) = _parent1(data.parents[1])
_parent1(data::Union{SubArray, DiskArrays.SubDiskArray}) = _parent1(parent(data))

# A materialized variable reaches its file variable through the dataset.
_source_variable(var::CDFVariable) = variable(dataset(var), CDM.name(var))

function CDM.dimnames(var::CDFVariable, i::Int)
    data = _parent1(var)
    return data isa Array ? dimnames(_source_variable(var), i) : dimnames(data, i)
end

CDM.dimnames(var::CDFVariable) = ntuple(i -> dimnames(var, i), ndims(var))

is_virtual(var) = get(var.attrib, "VIRTUAL", nothing) == "TRUE"

# Name of the variable backing dimension `i`, after the DEPEND_TIME swap (see `depend_time`).
function dimvarname(var::CDFVariable, i::Int)
    dname = dimnames(var, i)
    # Some CDAWeb masters name a DEPEND missing from the file (`po_h1_tim` `Start_epoch`).
    (isnothing(dname) || !haskey(dataset(var), dname)) && return nothing
    swap = i == ndims(var) && "DEPEND_TIME" in attribnames(var) && is_virtual(dataset(var)[dname])
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

const _SubView = Union{SubArray, DiskArrays.SubDiskArray}

function depend(var::CDFVariable{T, N, <:_SubView}, i::Int) where {T, N}
    dvar = depend(rebuild(var, parent(parent(var))), i)
    isnothing(dvar) && return nothing
    if eltype(dvar) <: AbstractDateTime || is_record_varying(dvar)
        indices = parentindices(parent(var))[ndims(var)]
        return selectdim(dvar, ndims(dvar), indices)
    end
    return dvar
end

CDM.dim(var::CDFVariable, i::Int) = @something depend(var, i) axes(parent(var), i)

cdf_type(var::CDFVariable) = cdf_type(_parent1(var))
function CDF.is_record_varying(var::CDFVariable)
    data = _parent1(var)
    return data isa Array ? is_record_varying(_source_variable(var)) : is_record_varying(data)
end

# https://github.com/JuliaSpacePhysics/CDFDatasets.jl/issues/23
function depend_time(var)
    @debug "Non compliant CDF file, swapping DEPEND_0 with DEPEND_TIME"
    dimvar = dataset(var)[attrib(var, "DEPEND_TIME")]
    return CDFVariable(unix2timestamp.(Array(parent(dimvar))), CDM.name(dimvar), dataset(dimvar), CDM.attrib(dimvar))
end

# Float64 Unix seconds resolve only ~0.2 µs today; rounding to µs recovers decimal values
# that truncation to ns usually puts just below (e.g. .123 s -> .122999808 s).
unix2timestamp(x::AbstractFloat) = reinterpret(Timestamp{Nanosecond}, 1000 * round(Int64, 1.0e6 * x))
unix2timestamp(x::Real) = Durations.unix2timestamp(Timestamp{Nanosecond}, x)

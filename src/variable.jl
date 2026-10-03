# Fill value and valid range replaced by `NaN` on read; see `variable`.
struct Mask{F, L, H}
    fillval::F
    validmin::L
    validmax::H
end

function Mask(::Type{T}, md; fillval = get(md, "FILLVAL", nothing), validmin = get(md, "VALIDMIN", nothing), validmax = get(md, "VALIDMAX", nothing)) where {T}
    T <: Real || return nothing
    all(isnothing, (fillval, validmin, validmax)) && return nothing
    return Mask(fillval, validmin, validmax)
end

"""
    CDFVariable(data, name, parentdataset, metadata; fillval, validmin, validmax)

Variable whose reads replace fill and out-of-range values by `NaN` (see [`variable`](@ref));
`parent(var)` is the stored data.
"""
struct CDFVariable{T, N, A <: AbstractArray{<:Any, N}, S, P, MD, M} <: AbstractCDFVariable{T, N}
    data::A
    name::S
    parentdataset::P
    metadata::MD
    mask::M
    # In-memory data is stored decoded, so `Array`-backed variables read `data` directly.
    function CDFVariable(data::AbstractArray{R, N}, name, parentdataset, metadata, mask) where {R, N}
        data isa Array && !isnothing(mask) && return CDFVariable(_decode(data, mask), name, parentdataset, metadata, nothing)
        T = _eltype(R, mask)
        return new{T, N, typeof(data), typeof(name), typeof(parentdataset), typeof(metadata), typeof(mask)}(data, name, parentdataset, metadata, mask)
    end
end

CDFVariable(data, name, parentdataset, metadata; kw...) =
    CDFVariable(data, name, parentdataset, metadata, Mask(eltype(data), metadata; kw...))

_eltype(::Type{R}, ::Nothing) where {R} = R
_eltype(::Type{R}, ::Mask) where {R} = SDM._float(R)

# ISTP gives one VALIDMIN/VALIDMAX per component along dimension 1.
_decode(A, m::Mask) = SDM.mask_invalid(A; m.fillval, m.validmin, m.validmax, dims = 1)

Base.parent(var::CDFVariable) = var.data
Base.size(var::CDFVariable) = size(var.data)


rebuild(var, data, mask = var.mask) = CDFVariable(data, var.name, var.parentdataset, var.metadata, mask)

Base.view(var::CDFVariable, I...) = rebuild(var, view(var.data, I...))
Base.reshape(var::CDFVariable, dims::Dims) = rebuild(var, reshape(var.data, dims))

function DiskArrays.readblock!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    m = a.mask
    isnothing(m) && return _readraw!(a.data, aout, inds...)
    raw = _readraw!(a.data, similar(aout, eltype(a.data)), inds...)
    return SDM.mask_invalid!(aout, raw; m.fillval, validmin = _block(m.validmin, inds), validmax = _block(m.validmax, inds), dims = 1)
end

_readraw!(d::AbstractDiskArray, aout, inds...) = (DiskArrays.readblock!(d, aout, inds...); aout)
_readraw!(d, aout, inds...) = copyto!(aout, view(d, inds...))

# Per-component bounds restricted to the block's components
_block(v::AbstractVector, inds) = length(v) == 1 ? v : v[inds[1]]
_block(x, _) = x

DiskArrays.eachchunk(var::CDFVariable{T, N, <:AbstractDiskArray}) where {T, N} =
    DiskArrays.eachchunk(var.data)

CDM.name(var::CDFVariable) = var.name
CDM.dataset(var::CDFVariable) = var.parentdataset
CDM.attribnames(var::CDFVariable) = keys(var.metadata)
CDM.attrib(var::CDFVariable) = var.metadata
CDM.attrib(var::CDFVariable, name::String) = var.metadata[name]
CDM.variable(var::CDFVariable, name::String) = variable(dataset(var), name)

_parent1(data) = data
_parent1(data::CDFVariable) = _parent1(data.data)
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
    isnothing(dname) && return nothing
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
    dvar = depend(rebuild(var, parent(var.data)), i)
    isnothing(dvar) && return nothing
    if eltype(dvar) <: AbstractDateTime || is_record_varying(dvar)
        indices = parentindices(var.data)[ndims(var)]
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
    return rebuild(dimvar, unix2timestamp.(Array(parent(dimvar))), nothing)
end

# Float64 Unix seconds resolve only ~0.2 µs today; rounding to µs recovers decimal values
# that truncation to ns usually puts just below (e.g. .123 s -> .122999808 s).
unix2timestamp(x::AbstractFloat) = reinterpret(Timestamp{Nanosecond}, 1000 * round(Int64, 1.0e6 * x))
unix2timestamp(x::Real) = Durations.unix2timestamp(Timestamp{Nanosecond}, x)

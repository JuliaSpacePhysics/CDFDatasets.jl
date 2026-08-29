struct LockedDict{K, V} <: AbstractDict{K, V}
    d::Dict{K, V}
    lock::ReentrantLock
end
LockedDict{K, V}() where {K, V} = LockedDict(Dict{K, V}(), ReentrantLock())
Base.get!(f::Base.Callable, ld::LockedDict, k) = @lock ld.lock get!(f, ld.d, k)
Base.keys(ld::LockedDict) = @lock ld.lock keys(ld.d)
Base.length(ld::LockedDict) = @lock ld.lock length(ld.d)

struct CDFDataset{A, I, D} <: AbstractCDFDataset
    source::A
    interval::I
    indices::D
end

CDFDataset(source, interval = nothing) = CDFDataset(source, interval, isnothing(interval) ? nothing : LockedDict{String, UnitRange{Int}}())

# https://github.com/SciQLop/CDFpp/blob/main/pycdfpp/__init__.py

"""
    CDFDataset(file; backend = :julia)

Load the CDF dataset at the `file` path. The dataset supports the API of the
[JuliaGeo/CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl).

`backend` controls the backend used to load the CDF dataset. Two options are
available: `:julia` and `:PyCDFpp`. The default is `:julia`.

For `PyCDFpp` backend, we use `lazy_load = true` by default. 
If `lazy_load = false`, all variable values are immediately loaded.
"""
function CDFDataset(file::AbstractString; backend = :julia, kw...)
    backend = Symbol(backend)
    @assert backend in (:julia, :PyCDFpp, :CommonDataFormat)
    return if backend == :PyCDFpp
        CDFDataset(PyCDFppDataset(file; lazy_load = false, kw...))
    else
        CDFDataset(CDF.CDFDataset(file))
    end
end

function PyCDFppDataset(file; kwargs...)
    error("PyCDFppDataset requires the PyCDFpp extension. Please load PyCDFpp first.")
end

# Base interface
Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::AbstractCDFDataset, name::String) = CDM.variable(ds, name)

Base.view(ds::AbstractCDFDataset, interval::Interval) =
    CDFDataset(ds.source, _has_interval(ds) ? intersect(ds.interval, interval) : interval)

# CommonDataModel.jl interface methods
const SymbolString = Union{String, Symbol}

_is_multi_source(ds::CDFDataset) = ds.source isa AbstractVector
_parent1(ds::CDFDataset) = _is_multi_source(ds) ? first(ds.source) : ds.source
_has_interval(ds::CDFDataset) = !isnothing(ds.interval)
_unclipped(ds::CDFDataset) = CDFDataset(ds.source)

function CDM.variable(ds::CDFDataset, name::SymbolString; metadata = nothing)
    _has_interval(ds) || return _variable_unclipped(ds, name; metadata)
    var = _variable_unclipped(_unclipped(ds), name; metadata)
    is_record_varying(var) || return var
    N = ndims(var)
    is_epoch = eltype(var) <: AbstractDateTime
    key = is_epoch ? String(name) : dimvarname(var, N)
    indices = get!(ds.indices, key) do
        tdim = is_epoch ? var : dim(var, N)
        find_indices(convert(Vector, tdim), ds.interval)
    end
    return selectdim(var, N, indices)
end

CDM.varnames(ds::AbstractCDFDataset) = CDM.varnames(_parent1(ds))
CDM.attribnames(ds::AbstractCDFDataset) = CDM.attribnames(_parent1(ds))
CDM.attrib(ds::AbstractCDFDataset, name::SymbolString) = CDM.attrib(_parent1(ds), name)

CDM.path(ds::CDFDataset) = _is_multi_source(ds) ? CDM.path.(parent(ds)) : CDM.path(parent(ds))
function CDM.name(ds::AbstractCDFDataset)
    return only(get(ds.attrib, "Logical_source", "/"))
end

function CDFDataset(sources::AbstractVector{<:AbstractString}; backend = :julia)
    backend = Symbol(backend)
    @assert backend in (:julia, :CommonDataFormat)
    return CDFDataset(CDF.CDFDataset.(sources))
end

function _variable_unclipped(ds::CDFDataset, name::SymbolString; metadata = nothing)
    ds1 = _parent1(ds)
    var1 = ds1[name]
    md = @something metadata CDM.attrib(var1)
    return if _is_multi_source(ds) && is_record_varying(var1)
        _concat_variables(map(source -> source[name], ds.source); name, metadata = md, parentdataset = ds)
    else
        CDFVariable(var1, name, ds, md)
    end
end

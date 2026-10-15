struct LockedDict{K, V} <: AbstractDict{K, V}
    d::Dict{K, V}
    lock::ReentrantLock
end
LockedDict{K, V}() where {K, V} = LockedDict(Dict{K, V}(), ReentrantLock())
Base.get!(f::Base.Callable, ld::LockedDict, k) = @lock ld.lock get!(f, ld.d, k)
Base.keys(ld::LockedDict) = @lock ld.lock keys(ld.d)
Base.length(ld::LockedDict) = @lock ld.lock length(ld.d)

struct CDFDataset{A, I, D, C <: NamedTuple} <: AbstractCDFDataset
    source::A
    interval::I
    indices::D
    checks::C
end

function CDFDataset(source, interval = nothing; checks = (;))
    indices = isnothing(interval) ? nothing : LockedDict{String, Union{UnitRange{Int}, Vector{Int}}}()
    return CDFDataset(source, interval, indices, _checks(checks))
end

function _checks(checks::NamedTuple)
    for k in keys(checks)
        k in (:fillval, :validmin, :validmax) ||
            throw(ArgumentError("unknown check `$k`; expected `fillval`, `validmin` or `validmax`"))
    end
    return checks
end

"""
    CDFDataset(file; checks = (;))

Load the CDF dataset at the `file` path. The dataset supports the API of the
[JuliaGeo/CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl).

Global attributes are entry vectors.
"""
CDFDataset(file::AbstractString; checks = (;)) = CDFDataset(CDF.CDFDataset(file); checks)

# Base interface
Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::AbstractCDFDataset, name::String) = CDM.variable(ds, name)

Base.view(ds::AbstractCDFDataset, interval::Interval) =
    CDFDataset(ds.source, _has_interval(ds) ? intersect(ds.interval, interval) : interval; ds.checks)

# CommonDataModel.jl interface methods
const SymbolString = Union{String, Symbol}

_is_multi_source(ds::CDFDataset) = ds.source isa AbstractVector
_source1(ds::CDFDataset) = _is_multi_source(ds) ? first(ds.source) : ds.source
_has_interval(ds::CDFDataset) = !isnothing(ds.interval)
_unclipped(ds::CDFDataset) = CDFDataset(ds.source; ds.checks)

"""
    variable(ds, name; metadata, fillval, validmin, validmax) :: CDFVariable

Variable `name` of `ds`, also `ds[name]`. The keywords override the dataset's `checks` and the
attributes (README: Missing values). A materialized variable stores decoded data.
"""
function CDM.variable(ds::CDFDataset, name::SymbolString; metadata = nothing, kw...)
    _has_interval(ds) || return _variable_unclipped(ds, name; metadata, kw...)
    var = _variable_unclipped(_unclipped(ds), name; metadata, kw...)
    is_record_varying(var) || return var
    N = ndims(var)
    is_epoch = eltype(var) <: AbstractDateTime
    key = is_epoch ? String(name) : dimvarname(var, N)
    indices = get!(ds.indices, key) do
        tdim = is_epoch ? var : depend(var, N)
        find_indices(convert(Vector, tdim), ds.interval)
    end
    return selectdim(var, N, indices)
end

CDM.varnames(ds::AbstractCDFDataset) = CDM.varnames(_source1(ds))
# CommonDataModel's fallback allocates every variable name.
Base.haskey(ds::AbstractCDFDataset, name::SymbolString) = haskey(_source1(ds), String(name))
CDM.attribnames(ds::AbstractCDFDataset) = CDM.attribnames(_source1(ds))
CDM.attrib(ds::AbstractCDFDataset, name::SymbolString) = CDM.attrib(_source1(ds), name)

CDM.path(ds::CDFDataset) = _is_multi_source(ds) ? CDM.path.(parent(ds)) : CDM.path(parent(ds))
CDM.name(ds::AbstractCDFDataset) = join(get(ds.attrib, "Logical_source", '/'), '/')

CDFDataset(sources::AbstractVector{<:AbstractString}; checks = (;)) = CDFDataset(CDF.CDFDataset.(sources); checks)

function _variable_unclipped(ds::CDFDataset, name::SymbolString; metadata = nothing, kw...)
    ds1 = _source1(ds)
    var1 = ds1[name]
    md = @something metadata CDM.attrib(var1)
    data = _is_multi_source(ds) && is_record_varying(var1) ? _concat(map(source -> source[name], ds.source), ndims(var1)) : var1
    return _variable(data, name, ds, md, merge(ds.checks, values(kw)))
end

# `data` is not inferred; a call boundary compiles construction for its concrete type.
@noinline _variable(data, name, ds, metadata, kw) = CDFVariable(data, name, ds, metadata; kw...)

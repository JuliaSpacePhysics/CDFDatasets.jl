struct LockedDict{K, V} <: AbstractDict{K, V}
    d::Dict{K, V}
    lock::ReentrantLock
end
LockedDict{K, V}() where {K, V} = LockedDict(Dict{K, V}(), ReentrantLock())
Base.get!(f::Base.Callable, ld::LockedDict, k) = @lock ld.lock get!(f, ld.d, k)
Base.keys(ld::LockedDict) = @lock ld.lock keys(ld.d)
Base.length(ld::LockedDict) = @lock ld.lock length(ld.d)

struct CDFDataset{A, I, D, C <: NamedTuple, M} <: AbstractCDFDataset
    source::A
    interval::I
    indices::D
    checks::C
    master::M
end

function CDFDataset(source, interval = nothing; checks = (;), master = nothing)
    indices = isnothing(interval) ? nothing : LockedDict{String, Union{UnitRange{Int}, Vector{Int}}}()
    return CDFDataset(source, interval, indices, _checks(checks), _master(master))
end

_master(master::AbstractString) = CDF.CDFDataset(master)
_master(master::CDFDataset) = _source1(master)
_master(master) = master

function _checks(checks::NamedTuple)
    for k in keys(checks)
        k in (:fillval, :validmin, :validmax) ||
            throw(ArgumentError("unknown check `$k`; expected `fillval`, `validmin` or `validmax`"))
    end
    return checks
end

"""
    CDFDataset(file; checks = (;), master = nothing)

Load the CDF dataset at the `file` path. The dataset supports the API of the
[JuliaGeo/CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl).

Global attributes are entry vectors.
"""
CDFDataset(file::AbstractString; kw...) = CDFDataset(CDF.CDFDataset(file); kw...)

# Base interface
Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::AbstractCDFDataset, name::String) = CDM.variable(ds, name)

Base.view(ds::AbstractCDFDataset, interval::Interval) =
    CDFDataset(ds.source, _has_interval(ds) ? intersect(ds.interval, interval) : interval; ds.checks, ds.master)

# CommonDataModel.jl interface methods
const SymbolString = Union{String, Symbol}

_is_multi_source(ds::CDFDataset) = ds.source isa AbstractVector
_source1(ds::CDFDataset) = _is_multi_source(ds) ? first(ds.source) : ds.source
_has_interval(ds::CDFDataset) = !isnothing(ds.interval)

# The source holding variable `name`: the master for a non-record-varying one it holds values of, as
# CDAWeb reads (STA_L1_HET `Proton_Flux_Energies`; `Proton_Flux_Energy_vals` only the master holds), else the files.
function _source(ds::CDFDataset, name::String)
    m = ds.master
    !isnothing(m) && haskey(m, name) && _holds_values(m[name]) && return m
    ds1 = _source1(ds)
    return haskey(ds1, name) ? ds1 : nothing
end

_holds_values(var) = !is_record_varying(var) && !isempty(var)

_unclipped(ds::CDFDataset) = CDFDataset(ds.source; ds.checks, ds.master)

"""
    variable(ds, name; metadata, fillval, validmin, validmax) :: CDFVariable

Variable `name` of `ds`, also `ds[name]`. The keywords override the dataset's `checks` and the
attributes (README: Missing values).
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

function CDM.varnames(ds::CDFDataset)
    names, m = CDM.varnames(_source1(ds)), ds.master
    isnothing(m) && return names
    return vcat(names, filter(n -> n ∉ names && _holds_values(m[n]), CDM.varnames(m)))
end
# CommonDataModel's fallback allocates every variable name.
Base.haskey(ds::AbstractCDFDataset, name::SymbolString) = !isnothing(_source(ds, String(name)))

function CDM.attribnames(ds::CDFDataset)
    names, m = CDM.attribnames(_source1(ds)), ds.master
    return isnothing(m) ? names : union(names, CDM.attribnames(m))
end

function CDM.attrib(ds::CDFDataset, name::SymbolString)
    src, m = _source1(ds), ds.master
    return isnothing(m) || String(name) in CDM.attribnames(src) ? CDM.attrib(src, name) : CDM.attrib(m, name)
end

CDM.path(ds::CDFDataset) = _is_multi_source(ds) ? CDM.path.(parent(ds)) : CDM.path(parent(ds))
CDM.name(ds::AbstractCDFDataset) = join(get(ds.attrib, "Logical_source", '/'), '/')

CDFDataset(sources::AbstractVector{<:AbstractString}; kw...) = CDFDataset(CDF.CDFDataset.(sources); kw...)

function _variable_unclipped(ds::CDFDataset, name::SymbolString; metadata = nothing, kw...)
    var1 = (@something _source(ds, String(name)) _source1(ds))[name]
    md = @something metadata _attrib(ds.master, name, var1)
    data = _is_multi_source(ds) && is_record_varying(var1) ? _concat(map(source -> source[name], ds.source), ndims(var1)) : var1
    return _variable(data, name, ds, md, merge(ds.checks, values(kw)))
end

_attrib(master, name, var) = isnothing(master) || !haskey(master, name) ? CDM.attrib(var) :
    SDM.OverlayDict(CDM.attrib(var), CDF.attrib(master[name]))

# `data` is not inferred; a call boundary compiles construction for its concrete type.
@noinline _variable(data, name, ds, metadata, kw) = CDFVariable(data, name, ds, metadata; kw...)

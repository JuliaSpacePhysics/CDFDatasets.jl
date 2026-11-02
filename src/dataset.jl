const SymbolString = Union{String, Symbol}

struct LockedDict{K, V}
    d::Dict{K, V}
    lock::ReentrantLock
end
LockedDict{K, V}() where {K, V} = LockedDict(Dict{K, V}(), ReentrantLock())
Base.get!(f::Base.Callable, ld::LockedDict, k) = @lock ld.lock get!(f, ld.d, k)

struct CDFDataset{A, I, D, C <: NamedTuple, M}
    source::A
    interval::I
    indices::D
    checks::C
    master::M
end

function CDFDataset(source, interval = nothing; checks = (;), master = nothing)
    indices = isnothing(interval) ? nothing : LockedDict{String, Union{UnitRange{Int}, Vector{Int}, Nothing}}()
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

Load the CDF dataset at the `file` path. Global attributes are entry vectors.
"""
CDFDataset(file::AbstractString; kw...) = CDFDataset(CDF.CDFDataset(file); kw...)

Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::CDFDataset, name::SymbolString) = variable(ds, name)
Base.getproperty(ds::CDFDataset, s::Symbol) = s === :attrib ? _attrib(ds) : getfield(ds, s)
Base.propertynames(ds::CDFDataset, private::Bool = false) = (fieldnames(typeof(ds))..., :attrib)

Base.view(ds::CDFDataset, interval::Interval) =
    CDFDataset(ds.source, _has_interval(ds) ? intersect(ds.interval, interval) : interval; ds.checks, ds.master)

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
variable(ds::CDFDataset, name::Symbol; kw...) = variable(ds, String(name); kw...)
function variable(ds::CDFDataset, name::String; metadata = nothing, kw...)
    _has_interval(ds) || return _variable_unclipped(ds, name; metadata, kw...)
    return _clip(ds, _variable_unclipped(_unclipped(ds), name; metadata, kw...), name)
end

function _clip(ds::CDFDataset, var, name)
    N = ndims(var)
    # nothing to clip without records, and empty indices must not be cached for the coordinate
    is_record_varying(var) && size(var, N) > 0 || return var
    key = eltype(var) <: AbstractDateTime ? name : dimvarname(var, N)
    isnothing(key) && return var
    indices = get!(ds.indices, key) do
        tdim = _timecoord(var)
        isnothing(tdim) ? nothing : find_indices(tdim, ds.interval)
    end
    isnothing(indices) && return var
    return selectdim(var, N, indices)
end

function Base.keys(ds::CDFDataset)
    names, m = keys(_source1(ds)), ds.master
    isnothing(m) && return names
    return vcat(names, filter(n -> n ∉ names && _holds_values(m[n]), keys(m)))
end
Base.haskey(ds::CDFDataset, name::SymbolString) = !isnothing(_source(ds, String(name)))

# The master's global attributes fill the file's gaps, whereas a variable's overlay the file's.
_attrib(ds::CDFDataset) = (a = _source1(ds).attrib; isnothing(ds.master) ? a : SDM.OverlayDict(ds.master.attrib, a))

path(ds::CDFDataset) = _is_multi_source(ds) ? path.(parent(ds)) : path(parent(ds))
path(ds::CDF.CDFDataset) = CDF.filename(ds)
SDM.name(ds::CDFDataset) = join(get(ds.attrib, "Logical_source", '/'), '/')

CDFDataset(sources::AbstractVector{<:AbstractString}; kw...) = CDFDataset(CDF.CDFDataset.(sources); kw...)

function _variable_unclipped(ds::CDFDataset, name::String; metadata = nothing, kw...)
    var1 = (@something _source(ds, name) _source1(ds))[name]
    md = @something metadata _varattrib(ds.master, name, var1)
    data = _is_multi_source(ds) && is_record_varying(var1) ? _concat(map(source -> _lazy(source[name]), ds.source), ndims(var1)) : _lazy(var1)
    return _variable(data, name, ds, md, merge(ds.checks, values(kw)))
end

_varattrib(master, name, var) = isnothing(master) || !haskey(master, name) ? var.attrib :
    SDM.OverlayDict(var.attrib, master[name].attrib)

# Variables are not inferred; call boundaries compile construction for their concrete types
@noinline _lazy(var::CDF.CDFVariable) = FileArray(var)
_lazy(var) = var

@noinline _variable(data, name, ds, metadata, kw) = CDFVariable(data, name, ds, metadata; kw...)

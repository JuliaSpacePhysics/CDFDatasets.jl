struct CDFDataset{A, I} <: AbstractCDFDataset
    source::A
    interval::I
end

CDFDataset(source) = CDFDataset(source, nothing)

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
    return if backend == :julia || backend == :CommonDataFormat
        CDFDataset(CDF.CDFDataset(file))
    elseif backend == :PyCDFpp
        CDFDataset(PyCDFppDataset(file; lazy_load = false, kw...))
    end
end

function PyCDFppDataset(file; kwargs...)
    error("PyCDFppDataset requires the PyCDFpp extension. Please load PyCDFpp first.")
end

# Base interface
Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::AbstractCDFDataset, name::String) = CDM.variable(ds, name)

Base.view(ds::AbstractCDFDataset, interval::Interval) =
    CDFDataset(ds.source, interval)

# CommonDataModel.jl interface methods
const SymbolString = Union{String, Symbol}

_is_multi_source(ds::CDFDataset) = ds.source isa AbstractVector
_parent1(ds::CDFDataset) = _is_multi_source(ds) ? first(ds.source) : ds.source
_has_interval(ds::CDFDataset) = !isnothing(ds.interval)
_unclipped(ds::CDFDataset) = CDFDataset(ds.source)

function CDM.variable(ds::CDFDataset, name::SymbolString; metadata = nothing)
    if _has_interval(ds)
        var = _variable_unclipped(_unclipped(ds), name; metadata)
        return is_record_varying(var) ? var[ds.interval] : var
    end

    return _variable_unclipped(ds, name; metadata)
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

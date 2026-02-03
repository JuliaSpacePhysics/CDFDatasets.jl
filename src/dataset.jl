struct CDFDataset{A} <: AbstractCDFDataset
    source::A
end

struct ConcatCDFDataset{A} <: AbstractCDFDataset
    sources::A
end

struct ClippedCDFDataset{D, I} <: AbstractCDFDataset
    parent::D
    interval::I
end

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

Base.parent(ds::ClippedCDFDataset) = ds.parent
Base.view(ds::AbstractCDFDataset, interval::Interval) =
    ClippedCDFDataset(ds, interval)

# CommonDataModel.jl interface methods
const SymbolString = Union{String, Symbol}

function CDM.variable(ds::CDFDataset, name::SymbolString; metadata = nothing)
    data = CDM.variable(ds.source, name)
    return CDFVariable(name, data, ds, metadata)
end

function CDM.variable(ds::ClippedCDFDataset, name::SymbolString)
    var = CDM.variable(parent(ds), name)
    return is_record_varying(var) ? var[ds.interval] : var
end

_parent1(ds::AbstractCDFDataset) = parent(ds)
CDM.varnames(ds::AbstractCDFDataset) = CDM.varnames(_parent1(ds))
CDM.attribnames(ds::AbstractCDFDataset) = CDM.attribnames(_parent1(ds))
CDM.attrib(ds::AbstractCDFDataset, name::SymbolString) = CDM.attrib(_parent1(ds), name)

CDM.path(ds::AbstractCDFDataset) = CDM.path(parent(ds))
function CDM.name(ds::AbstractCDFDataset)
    return only(get(ds.attrib, "Logical_source", "/"))
end

function ConcatCDFDataset(sources::AbstractVector{<:AbstractString}; backend = :julia)
    backend = Symbol(backend)
    @assert backend in (:julia, :CommonDataFormat)
    return ConcatCDFDataset(CDF.CDFDataset.(sources))
end

_parent1(ds::ConcatCDFDataset) = ds.sources[1]
CDM.path(ds::ConcatCDFDataset) = CDM.path.(ds.sources)

function CDM.variable(ds::ConcatCDFDataset, name::SymbolString; metadata = nothing)
    ds1 = _parent1(ds)
    var1 = ds1[name]
    return if is_record_varying(var1)
        ConcatCDFVariable(map(x -> x[name], ds.sources); metadata, parentdataset = ds)
    else
        CDFVariable(name, var1, ds1, metadata)
    end
end

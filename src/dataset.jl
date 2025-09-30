struct CDFDataset{A} <: AbstractCDFDataset
    source::A
end

# https://github.com/SciQLop/CDFpp/blob/main/pycdfpp/__init__.py

"""
    CDFDataset(file; lazy = true)

Load the CDF dataset at the `file` path. The dataset supports the API of the
[JuliaGeo/CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl).

`lazy` controls whether variable values are loaded immediately or only when accessed by the user.
If True, variables' values are loaded on demand. If False, all variable values are loaded during parsing.
"""
function CDFDataset(file::AbstractString; backend = :julia, lazy = true)
    backend = Symbol(backend)
    @assert backend in (:julia, :PyCDFpp, :CommonDataFormat)
    return if backend == :julia || backend == :CommonDataFormat
        CDFDataset(CDF.CDFDataset(file))
    elseif backend == :PyCDFpp
        CDFDataset(PyCDFppDataset(file; lazy_load = lazy))
    end
end

function PyCDFppDataset end

# Base interface
Base.keys(ds::CDFDataset) = keys(ds.source)
Base.parent(ds::CDFDataset) = ds.source
Base.getindex(ds::CDFDataset, name::String) = CDM.variable(ds, name)

function Base.show(io::IO, ::MIME"text/plain", ds::AbstractCDFDataset)
    invoke(show, Tuple{IO, AbstractDataset}, io, ds)
end

function Base.show(io::IO, ds::AbstractCDFDataset)
    varnames_list = CDM.varnames(ds)
    dataset_name = CDM.name(ds)
    max_show = 12
    print(io, dataset_name, " (", length(varnames_list), " variable")
    length(varnames_list) != 1 && print(io, "s")
    print(io, ": ")

    if !isempty(varnames_list)
        n_show = min(max_show, length(varnames_list))
        print(io, join(varnames_list[1:n_show], ", "))
        length(varnames_list) > max_show && print(io, ", \u2026")
    end
    print(io, ")")
end

# CommonDataModel.jl interface methods

function CDM.variable(ds::CDFDataset, name::Union{String, Symbol})
    data = CDM.variable(ds.source, name)
    return CDFVariable(_string(name), data, ds)
end

CDM.varnames(ds::CDFDataset) = CDM.varnames(ds.source)
CDM.attribnames(ds::CDFDataset) = CDM.attribnames(ds.source)
CDM.attrib(ds::CDFDataset, name::String) = CDM.attrib(ds.source, name)

function CDM.name(ds::AbstractCDFDataset)
    only(get(ds.attrib, "Logical_source", "/"))
end

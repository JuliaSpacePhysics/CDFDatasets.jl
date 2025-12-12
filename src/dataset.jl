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

function Base.show(io::IO, ::MIME"text/plain", ds::AbstractCDFDataset)
    # return invoke(show, Tuple{IO, AbstractDataset}, io, ds)
    return _show(io, ds)
end

function _show(io::IO, ds::AbstractCDFDataset)
    level = get(io, :level, 0)
    indent = " "^level

    if !isopen(ds)
        print(io, "closed Dataset")
        return
    end

    printstyled(io, indent, "Dataset: ", CDM.path(ds), "\n", color = CDM.section_color[])

    print(io, indent, "Group: ", CDM.name(ds), "\n")
    print(io, "\n")

    # show dimensions
    if length(dimnames(ds)) > 0
        show_dim(io, dims(ds))
        print(io, "\n")
    end

    varnames = keys(ds)

    if length(varnames) > 0
        printstyled(io, indent, "Data variables\n", color = CDM.section_color[])

        vars = [ds[name] for name in varnames]
        for var in filter(var -> var_type(var) == "data", vars)
            show(IOContext(io, :level => level + 2), var)
            print(io, "\n")
        end

        support_var_names = filter(var -> var_type(ds[var]) == "support_data", varnames)
        if length(support_var_names) > 0
            printstyled(io, indent, "Support variables: "; color = CDM.section_color[])
            printstyled(io, join(support_var_names, ", "), "\n"; bold = true)
        end

        meta_var_names = filter(var -> var_type(ds[var]) == "metadata", varnames)
        if length(meta_var_names) > 0
            printstyled(io, indent, "Metadata variables: "; color = CDM.section_color[])
            printstyled(io, join(meta_var_names, ", "), "\n"; bold = true)
        end
    end

    # global attribues
    if length(CDM.attribnames(ds)) > 0
        printstyled(io, indent, "Global attributes\n", color = CDM.section_color[])
        CDM.show_attrib(IOContext(io, :level => level + 2), CDM.attribs(ds))
    end
    return
end

function _show(io::IO, ds::ClippedCDFDataset)
    level = get(io, :level, 0)
    indent = " "^level
    print(io, indent, "View: ", ds.interval, "\n")
    return _show(io, parent(ds))
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
    return
end

# CommonDataModel.jl interface methods

function CDM.variable(ds::CDFDataset, name::Union{String, Symbol})
    data = CDM.variable(ds.source, name)
    return CDFVariable(name, data, ds)
end

function CDM.variable(ds::ClippedCDFDataset, name::Union{String, Symbol})
    var = CDM.variable(parent(ds), name)
    return is_record_varying(var) ? var[ds.interval] : var
end

_parent1(ds::AbstractCDFDataset) = parent(ds)
CDM.varnames(ds::AbstractCDFDataset) = CDM.varnames(_parent1(ds))
CDM.attribnames(ds::AbstractCDFDataset) = CDM.attribnames(_parent1(ds))
CDM.attrib(ds::AbstractCDFDataset, name::String) = CDM.attrib(_parent1(ds), name)
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

function CDM.variable(ds::ConcatCDFDataset, name::Union{String, Symbol})
    var1 = _parent1(ds)[name]
    return if is_record_varying(var1)
        ConcatCDFVariable(map(x -> x[name], ds.sources))
    else
        CDFVariable(name, var1, ds)
    end
end

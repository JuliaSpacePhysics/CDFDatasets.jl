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

function show_var_names(io::IO, indent, label, names)
    isempty(names) && return
    printstyled(io, indent, label; color = CDM.section_color[])
    printstyled(io, join(names, ", "), "\n"; bold = true)
    return
end

function Base.show(io::IO, ::MIME"text/plain", ds::AbstractCDFDataset)
    return _show(io, ds)
end

function Base.show(io::IO, var::AbstractCDFVariable)
    get(io, :limit, false) && return _show_limited(io, var)
    return invoke(show, Tuple{IO, CDM.AbstractVariable}, io, var)
end

function _show_limited(io::IO, var::AbstractCDFVariable)
    level = get(io, :level, 0)
    indent = " "^level
    delim = " × "
    attrs = CDM.attrib(var)
    units = get(attrs, "UNITS", "")
    field = get(attrs, "FIELDNAM", get(attrs, "CATDESC", ""))

    printstyled(io, indent, CDM.name(var), color = CDM.variable_color[])
    print(io, " (", join(size(var), delim), ")")
    print(io, " dims=", join(CDM.dimnames(var), delim))
    if !isempty(field) || !isempty(units)
        print(io, " [")
        isempty(field) || print(io, field)
        if !isempty(units)
            isempty(field) || print(io, "; ")
            print(io, units)
        end
        print(io, "]")
    end
    return
end

function show_attrib_summary(io::IO, attrs)
    level = get(io, :level, 0)
    indent = " "^level
    names = collect(keys(attrs))

    print(io, indent, length(names), " attributes")
    if !isempty(names)
        n_show = min(length(names), 8)
        print(io, ": ", join(names[1:n_show], ", "))
        length(names) > n_show && print(io, ", ...")
    end
    print(io, "\n")
    return
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
            show(IOContext(io, :level => level + 2, :limit => get(io, :limit, false)), var)
            print(io, "\n")
        end

        show_var_names(io, indent, "Support variables: ", filter(var -> var_type(ds[var]) == "support_data", varnames))
        show_var_names(io, indent, "Metadata variables: ", filter(var -> var_type(ds[var]) == "metadata", varnames))
        show_var_names(io, indent, "Other variables: ", filter(var -> var_type(ds[var]) ∉ ("data", "support_data", "metadata"), varnames))
    end

    # global attribues
    if length(CDM.attribnames(ds)) > 0
        printstyled(io, indent, "Global attributes\n", color = CDM.section_color[])
        attr_io = IOContext(io, :level => level + 2)
        if get(io, :limit, false)
            show_attrib_summary(attr_io, CDM.attribs(ds))
        else
            CDM.show_attrib(attr_io, CDM.attribs(ds))
        end
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

function show_var_names(io::IO, label, names)
    isempty(names) && return
    printstyled(io, label; color = :red)
    printstyled(io, join(names, ", "), "\n"; bold = true)
    return
end

function Base.show(io::IO, ::MIME"text/plain", ds::CDFDataset)
    _has_interval(ds) && print(io, "View: ", ds.interval, "\n")
    isempty(ds.checks) || print(io, "Checks: ", ds.checks, "\n")
    isnothing(ds.master) || print(io, "Master: ", path(ds.master), "\n")

    printstyled(io, "Dataset: ", path(ds), "\n", color = :red)
    print(io, "Group: ", SDM.name(ds), "\n\n")

    varnames = keys(ds)
    if length(varnames) > 0
        printstyled(io, "Data variables\n", color = :red)

        vars = [ds[name] for name in varnames]
        types = map(var_type, vars)
        for (var, type) in zip(vars, types)
            type == "data" || continue
            show(IOContext(io, :level => 2), var)
            print(io, "\n")
        end

        show_var_names(io, "Support variables: ", varnames[types .== "support_data"])
        show_var_names(io, "Metadata variables: ", varnames[types .== "metadata"])
        show_var_names(io, "Other variables: ", varnames[types .∉ Ref(("data", "support_data", "metadata"))])
    end

    attrs = ds.attrib
    if !isempty(attrs)
        printstyled(io, "Global attributes\n", color = :red)
        attr_io = IOContext(io, :level => 2)
        if get(io, :limit, false)
            show_attrib_summary(attr_io, attrs)
        else
            show_attrib(attr_io, attrs)
        end
    end
    return
end

function Base.show(io::IO, var::AbstractCDFVariable)
    get(io, :limit, false) && return _show_limited(io, var)
    level = get(io, :level, 0)
    indent = " "^level
    delim = " × "
    printstyled(io, indent, SDM.name(var); color = :green)
    print(io, " (", join(size(var), delim), ")\n")
    print(io, indent, "  Datatype:    ")
    printstyled(io, eltype(var); bold = true)
    print(io, "\n", indent, "  Dimensions:  ", join(something.(dimnames(var), "?"), delim), "\n")
    attrs = var.attrib
    if !isempty(attrs)
        print(io, indent, "  Attributes:\n")
        show_attrib(IOContext(io, :level => level + 3), attrs)
    end
    return
end
Base.show(io::IO, ::MIME"text/plain", var::AbstractCDFVariable) = show(io, var)

function _show_limited(io::IO, var::AbstractCDFVariable)
    level = get(io, :level, 0)
    indent = " "^level
    delim = " × "
    attrs = var.attrib
    units = strip(get(attrs, "UNITS", ""))
    field = get(attrs, "CATDESC", get(attrs, "FIELDNAM", ""))

    printstyled(io, indent, SDM.name(var), color = :green)
    print(io, " (", join(size(var), delim), ")")
    print(io, " dims=", join(something.(dimnames(var), "?"), delim))
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

function show_attrib(io::IO, attrs)
    indent = " "^get(io, :level, 0)
    for (k, v) in attrs
        print(io, indent, rpad(k, 20), " = ")
        printstyled(io, v; color = :cyan)
        print(io, "\n")
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

function Base.show(io::IO, ds::CDFDataset)
    varnames_list = keys(ds)
    dataset_name = SDM.name(ds)
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

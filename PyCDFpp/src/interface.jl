# DiskArrays interface

function DiskArrays.readblock!(var::PyCDFVariable, aout, inds::AbstractUnitRange...)
    aout .= var.data[inds...]
end

# CommonDataModel interface

function CDM.attribnames(var::Union{PyCDF, PyCDFVariable})
    py = var.py
    return py2jlkeys(@py py.attributes)
end

function CDM.attrib(var::PyCDF, name::String)
    py = var.py
    attr = @py py.attributes[name]
    return pyconvert(Vector{String}, pylist(attr))
end


function CDM.variable(ds::PyCDF, name::Union{String, Symbol, Py})
    ds_py = ds.py
    var_py = @py ds_py[name]
    data = py2jlvalues(var_py; copy = false)
    return PyCDFVariable(data, var_py)
end

CDM.attrib(var::PyCDFVariable, name::String) = py2jlattrib(var.py, name)


function CDM.dimnames(var::PyCDFVariable, i::Int)
    key = if i == 1
        @pyconst pystr("DEPEND_0")
    elseif i == 2
        @pyconst pystr("DEPEND_1")
    elseif i == 3
        @pyconst pystr("DEPEND_2")
    end
    py = var.py
    atts = @py py.attributes
    if pyin(key, atts)
        att = @py atts[key]
        return pyconvert(String, @py att.value)
    else
        return nothing
    end
end
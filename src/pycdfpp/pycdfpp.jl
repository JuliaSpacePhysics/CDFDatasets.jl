module PyCDFpp
using PythonCall
import CommonDataModel as CDM
import CommonDataModel: dimnames, variable, attribnames, attrib
import ..CDFDatasets: CDFType, cdf_type, CDF_TIME_TT2000, tt2000_to_datetime
import ..CDFDatasets as CDF

include("python.jl")

function load(path::AbstractString; lazy_load = true)
    pyload = @py pyimport("pycdfpp").load
    py = pyload(path; lazy_load)
    return PyCDF(py)
end

struct PyCDF
    py::Py
end

struct PyCDFVariable{T, N, A <: AbstractArray{T, N}} <: AbstractArray{T, N}
    data::A
    py::Py
end

Base.keys(py::PyCDF) = py2jlkeys(py.py)

function CDM.attribnames(var::Union{PyCDF, PyCDFVariable})
    py = var.py
    return py2jlkeys(@py py.attributes)
end

function CDM.attrib(var::PyCDF, name::String)
    py = var.py
    return pyconvert(String, @py py.attributes[name][0])
end

Base.parent(var::PyCDFVariable) = var.data
Base.iterate(A::PyCDFVariable, args...) = iterate(parent(A), args...)
for f in (:size, :Array)
    @eval Base.$f(var::PyCDFVariable) = $f(parent(var))
end

for f in (:getindex,)
    @eval Base.@propagate_inbounds Base.$f(var::PyCDFVariable, I::Vararg{Int}) = $f(parent(var), I...)
end

Base.keys(var::PyCDFVariable) = CDM.attribnames(var)

CDF.cdf_type(var::PyCDFVariable) = CDF.cdf_type(var.py)
CDF.cdf_type(py::Py) = CDFType(pyconvert(Int, @py py.type.value))

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
end

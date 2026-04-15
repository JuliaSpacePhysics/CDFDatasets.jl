module PyCDFpp
using PythonCall
import CommonDataModel as CDM
import CommonDataModel: dimnames, variable, attribnames, attrib
using UnixTimes: UnixTime
using Dates: DateTime, Millisecond
using CommonDataFormat: CDF_TIME_TT2000, CDF_EPOCH, TT2000

export PyCDF, PyCDFVariable

include("types.jl")
include("python.jl")
include("interface.jl")
include("epochs.jl")

function load(path::AbstractString; lazy_load = true)
    pyload = @py pyimport("pycdfpp").load
    py = pyload(path; lazy_load)
    return PyCDF(py)
end

PyCDF(path::AbstractString; kw...) = load(path; kw...)
end

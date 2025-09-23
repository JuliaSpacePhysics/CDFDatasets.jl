module PyCDFpp
using PythonCall
import CommonDataModel as CDM
import CommonDataModel: dimnames, variable, attribnames, attrib
using CDFDatasets: CDFType, cdf_type
import CDFDatasets as CDF
using UnixTimes: UnixTime
using CDFDatasets.DiskArrays

export PyCDFVariable

include("types.jl")
include("python.jl")
include("interface.jl")

function load(path::AbstractString; lazy_load = true)
    pyload = @py pyimport("pycdfpp").load
    py = pyload(path; lazy_load)
    return PyCDF(py)
end
end

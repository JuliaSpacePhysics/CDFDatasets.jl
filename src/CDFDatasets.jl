module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim
import CommonDataModel as CDM
using UnixTimes: UNIX_EPOCH, UnixTime, Nanosecond

export CDFDataset, CDFVariable
export tt2000_to_datetime

abstract type AbstractCDFDataset <: AbstractDataset end
abstract type AbstractCDFVariable{T, N} <: AbstractVariable{T, N} end

export CDFType, cdf_type

include("utils.jl")
include("dataset.jl")
include("CDFType.jl")
include("variable.jl")
include("istp.jl")
include("tt2000.jl")
include("pycdfpp/pycdfpp.jl")
include("DimensionalData.jl")


end

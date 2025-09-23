module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim
import CommonDataModel as CDM
using UnixTimes: UNIX_EPOCH, UnixTime
using Dates
using CommonDataFormat
import CommonDataFormat as CDF
using DiskArrays: @implement_cat, cat_disk

const CDFType = CDF.DataType

export CDFDataset, CDFVariable, ConcatCDFVariable
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
include("CommonDataFormat.jl")
include("pycdfpp/pycdfpp.jl")
include("concat.jl")
end

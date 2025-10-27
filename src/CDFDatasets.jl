module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim
import CommonDataModel as CDM
using Dates
using CommonDataFormat
using CommonDataFormat: TT2000, vattrib, fillvalue
import CommonDataFormat as CDF
import CommonDataFormat: is_record_varying
import DiskArrays
using DiskArrays: cat_disk

const CDFType = CDF.DataType

export CDFDataset, CDFVariable, ConcatCDFVariable, ConcatCDFDataset
export TT2000
export CDFType, cdf_type
export vattrib
export dim
export is_record_varying
export sanitize

abstract type AbstractCDFDataset <: AbstractDataset end
abstract type AbstractCDFVariable{T, N} <: AbstractVariable{T, N} end
const SubCDFVariable = CDM.SubVariable{T, N, A} where {T, N, A <: AbstractCDFVariable}

include("utils.jl")
include("dataset.jl")
include("variable.jl")
include("istp.jl")
include("CommonDataFormat.jl")
include("concat.jl")
include("subvariable.jl")
include("methods.jl")
end

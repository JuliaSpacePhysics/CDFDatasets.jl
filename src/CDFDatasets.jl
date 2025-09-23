module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim
import CommonDataModel as CDM
using Dates
using CommonDataFormat
import CommonDataFormat: vattrib, fillvalue
import CommonDataFormat as CDF
import DiskArrays
using DiskArrays: @implement_cat, cat_disk

const CDFType = CDF.DataType

export CDFDataset, CDFVariable, ConcatCDFVariable
export tt2000_to_datetime
export CDFType, cdf_type
export vattrib
export is_record_varying

abstract type AbstractCDFDataset <: AbstractDataset end
abstract type AbstractCDFVariable{T, N} <: AbstractVariable{T, N} end
const SubCDFVariable = CDM.SubVariable{T, N, A} where {T, N, A <: AbstractCDFVariable}

include("utils.jl")
include("dataset.jl")
include("variable.jl")
include("istp.jl")
include("tt2000.jl")
include("CommonDataFormat.jl")
include("concat.jl")
include("subvariable.jl")
include("methods.jl")
end

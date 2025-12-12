module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim, dataset
import CommonDataModel as CDM
using CommonDataFormat
using CommonDataFormat: TT2000, Epoch, Epoch16, vattrib, fillvalue
using Dates: unix2datetime, AbstractDateTime
import CommonDataFormat as CDF
import CommonDataFormat: is_record_varying
import DiskArrays
using DiskArrays: cat_disk, getindex_disk
using IntervalSets: endpoints, Interval, (..)

const CDFType = CDF.DataType

export CDFDataset, CDFVariable, ConcatCDFVariable, ConcatCDFDataset
export cdfopen
export TT2000, Epoch, Epoch16
export CDFType, cdf_type
export vattrib
export dim
export is_record_varying
export sanitize, fillvalue
export ..
export variable

abstract type AbstractCDFDataset <: AbstractDataset end
abstract type AbstractCDFVariable{T, N} <: AbstractVariable{T, N} end
const SubCDFVariable = CDM.SubVariable{T, N, A} where {T, N, A <: AbstractCDFVariable}

include("dataset.jl")
include("show.jl")
include("variable.jl")
include("istp.jl")
include("CommonDataFormat.jl")
include("concat.jl")
include("subvariable.jl")
include("methods.jl")

"""
    cdfopen(file; kw...) :: CDFDataset
    cdfopen(files; kw...) :: ConcatCDFDataset

Opens CDF file(s) as a `AbstractCDFDataset`.
"""
cdfopen(file::AbstractString; kw...) = CDFDataset(file; kw...)
cdfopen(files; kw...) = ConcatCDFDataset(files; kw...)
end

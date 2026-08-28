module CDFDatasets

using CommonDataModel
using CommonDataModel: AbstractDataset, AbstractVariable
import CommonDataModel: dimnames, varnames, variable, attribnames, attrib, dim, dataset
import CommonDataModel as CDM
using CommonDataFormat
using CommonDataFormat: TT2000, Epoch, Epoch16, fillvalue
using Dates: unix2datetime, AbstractDateTime
import CommonDataFormat as CDF
import CommonDataFormat: is_record_varying
import DiskArrays
using DiskArrays: AbstractDiskArray
using IntervalSets: endpoints, isleftclosed, isrightclosed, Interval, (..)

const CDFType = CDF.CDFDataType

export CDFDataset, CDFVariable
export cdfopen
export TT2000, Epoch, Epoch16
export CDFType, cdf_type
export dim
export is_record_varying
export sanitize, fillvalue, materialize
export ..
export variable

abstract type AbstractCDFDataset <: AbstractDataset end
abstract type AbstractCDFVariable{T, N} <: AbstractVariable{T, N} end

include("dataset.jl")
include("variable.jl")
include("materialize.jl")
include("istp.jl")
include("CommonDataFormat.jl")
include("concat.jl")
include("subvariable.jl")
include("methods.jl")
include("show.jl")

"""
    cdfopen(file; kw...) :: CDFDataset
    cdfopen(files, [t0, t1]; kw...) :: CDFDataset

Opens CDF file(s) as a `AbstractCDFDataset`, and restricts record-varying variables to `[t0, t1)` when provided.
"""
cdfopen(file::AbstractString; kw...) = CDFDataset(file; kw...)
function cdfopen(files; backend = :julia, kw...)
    backend = Symbol(backend)
    @assert backend in (:julia, :CommonDataFormat)
    return CDFDataset(CDF.CDFDataset.(files))
end

cdfopen(files, t0, t1; kw...) = view(cdfopen(files; kw...), Interval{:closed,:open}(t0, t1))

CDM.Dimensions(var::AbstractCDFVariable) = ntuple(i -> dim(var, i), ndims(var))

end

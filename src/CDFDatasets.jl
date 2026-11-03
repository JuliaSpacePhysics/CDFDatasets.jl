module CDFDatasets

using CommonDataFormat
using CommonDataFormat: TT2000, Epoch, Epoch16, _isdense
using Dates: AbstractDateTime, DateTime, Nanosecond
using Durations: Durations, Timestamp
import CommonDataFormat as CDF
import CommonDataFormat: is_record_varying
using PrecompileTools
using IntervalSets: endpoints, isleftclosed, isrightclosed, Interval, var".."
import SpaceDataModel as SDM

const CDFType = CDF.CDFDataType

export CDFDataset, CDFVariable
export cdfopen
export TT2000, Epoch, Epoch16
export CDFType, cdf_type
export depend
export is_record_varying
export ..
export variable

include("lazy.jl")

abstract type AbstractCDFVariable{T, N} <: AbstractLazyArray{T, N} end

include("dataset.jl")
include("variable.jl")
include("istp.jl")
include("concat.jl")
include("timeseries.jl")
include("show.jl")

"""
    cdfopen(file; kw...) :: CDFDataset
    cdfopen(files, [t0, t1]; kw...) :: CDFDataset

Opens CDF file(s) as a `CDFDataset`, and restricts variables with a time coordinate to `[t0, t1)` when provided.
"""
cdfopen(file::AbstractString; kw...) = CDFDataset(file; kw...)
cdfopen(files; kw...) = CDFDataset(collect(String, files); kw...)

cdfopen(files, t0, t1; kw...) = view(cdfopen(files; kw...), Interval{:closed,:open}(t0, t1))

include("precompile.jl")

end

module CDFDatasetsDimensionalDataExt

using CDFDatasets
using CDFDatasets: AbstractCDFVariable, SDM
import CommonDataModel as CDM
using DimensionalData
using DimensionalData.Lookups: NoLookup
import DimensionalData: DimArray

dimtype(::Val{1}) = X
dimtype(::Val{2}) = Y
dimtype(::Val{3}) = Z

# A lookup is a vector: multi-dimensional coordinates are dropped. Labels are the lookup of a
# dimension without a `DEPEND`, and dropped from one with it.
function format_dim(data, i)
    DT = i == ndims(data) ? Ti : dimtype(Val(i))
    c = SDM.dims(data, i)
    isnothing(c) && return DT(@something _labelkeys(data, i) NoLookup(axes(data, i)))
    ndims(c) == 1 || return DT(NoLookup(axes(data, i)))
    return DT(vec(Array(c)); metadata = CDM.attrib(c))
end
_labelkeys(data, i) = (l = CDFDatasets._labels(data, i); isnothing(l) ? nothing : parent(l))

DimensionalData.dims(v::AbstractCDFVariable) = ntuple(i -> format_dim(v, i), ndims(v))

DimensionalData.DimArray(v::AbstractCDFVariable; metadata = v.attrib) =
    DimArray(Array(v), dims(v); name = CDM.name(v), metadata)

end

module CDFDatasetsDimensionalDataExt

using CDFDatasets
using CDFDatasets: CDFVariable, AbstractCDFVariable, materialize
import CommonDataModel as CDM
using DimensionalData
import DimensionalData: DimArray

dimtype(::Val{1}) = X
dimtype(::Val{2}) = Y
dimtype(::Val{3}) = Z

# multi-dimensional DEPENDs cannot label a single axis; fall back to positional
function format_dim(data, i)
    DT = i == ndims(data) ? Ti : dimtype(Val(i))
    dimvar = depend(data, i)
    if !isnothing(dimvar) && length(dimvar) == size(data, i)
        mat = materialize(dimvar)
        return DT(vec(mat.data); metadata = mat.metadata)
    end
    return DT(axes(data, i))
end

DimensionalData.dims(v::AbstractCDFVariable) = ntuple(i -> format_dim(v, i), ndims(v))

function DimensionalData.DimArray(v::AbstractCDFVariable; metadata = v.attrib, replace_fillval = true, replace_invalid = true)
    values = sanitize(v; replace_fillval, replace_invalid)
    name = CDM.name(v)
    return DimArray(values, dims(v); name, metadata)
end

end

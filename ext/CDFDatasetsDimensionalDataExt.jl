module CDFDatasetsDimensionalDataExt

using CDFDatasets
using CDFDatasets: CDFVariable, ConcatCDFVariable, AbstractCDFVariable, SubCDFVariable, unwrap
import CommonDataModel as CDM
using DimensionalData
import DimensionalData: DimArray

dimtype(::Val{1}) = X
dimtype(::Val{2}) = Y
dimtype(::Val{3}) = Z

# handle multi-dimensional DEPENDs
function format_dim(data, dimvar, i)
    DT = i == ndims(data) ? Ti : dimtype(Val(i))
    values = if length(dimvar) == size(data, i)
        vec(CDFDatasets.unwrap(dimvar))
    else
        axes(data, i)
    end
    return DT(values)
end

function DimensionalData.dims(v::Union{AbstractCDFVariable, SubCDFVariable})
    return ntuple(ndims(v)) do i
        depend = CDM.dim(v, i)
        format_dim(v, depend, i)
    end
end

function DimensionalData.DimArray(v::Union{AbstractCDFVariable, SubCDFVariable}; metadata = v.attrib, replace_fillval = true, replace_invalid = false)
    values = sanitize(v; replace_fillval, replace_invalid)
    name = CDM.name(v)
    return DimArray(values, dims(v); name, metadata)
end

end

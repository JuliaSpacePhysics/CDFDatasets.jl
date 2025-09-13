using DimensionalData
import DimensionalData as DD
import DimensionalData: DimArray

dimtype(::Val{1}) = Ti
dimtype(::Val{2}) = Y
dimtype(::Val{3}) = Z

# handle multi-dimensional DEPENDs
function format_dim(data, dimvar, i)
    DT = dimtype(Val(i))
    values = if length(dimvar) == size(data, i)
        vec(unwrap(dimvar))
    else
        axes(data, i)
    end
    return DT(values)
end

function DimensionalData.dims(v::CDFVariable)
    return ntuple(ndims(v)) do i
        depend = CDM.dim(v, i)
        format_dim(v, depend, i)
    end
end

function DimArray(v::CDFVariable)
    values = parent(v)
    name = v.name
    metadata = v.attrib
    return DimArray(values, dims(v); name, metadata)
end

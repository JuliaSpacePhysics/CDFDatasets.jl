
@implement_cat(CDFVariable)

struct ConcatCDFVariable{T, N, A <: AbstractArray{T, N}} <: AbstractCDFVariable{T, N}
    data::A
end

CDM.name(var::ConcatCDFVariable) = CDM.name(var.data.parents[1])
CDM.attribnames(var::ConcatCDFVariable) = CDM.attribnames(var.data.parents[1])
CDM.attrib(var::ConcatCDFVariable, name::String) = CDM.attrib(var.data.parents[1], name)

function Base.cat(A1::CDFVariable, A2::CDFVariable, As::CDFVariable...; dims)
    return ConcatCDFVariable(cat_disk(dims, A1, A2, As...))
end

unwrap(var::ConcatCDFVariable) = var.data.parents

function CDM.dimnames(var::ConcatCDFVariable, i::Int)
    parents = unwrap(var)
    var = parents[1]
    return dimnames(var, i)
end

function CDM.dim(var::ConcatCDFVariable, i::Int)
    parents = unwrap(var)
    var = parents[1]
    dname = dimnames(var, i)
    return if !isnothing(dname)
        mapreduce(x -> x.parentdataset[dname].data, vcat, parents)
    else
        axes(var.data, i)
    end
end

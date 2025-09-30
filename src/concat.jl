struct ConcatCDFVariable{T, N, A <: AbstractArray{T, N}, MD} <: AbstractCDFVariable{T, N}
    data::A
    metadata::MD
end

function ConcatCDFVariable(arrays; metadata = nothing, dim = nothing)
    dim = @something dim ndims(first(arrays))
    sz = map(ntuple(identity, dim)) do i
        i == dim ? length(arrays) : 1
    end
    cdas = reshape(arrays, sz)
    data = DiskArrays.ConcatDiskArray(cdas)
    # data = cat_disk(dim, arrays...)
    return ConcatCDFVariable(data, metadata)
end

# https://github.com/JuliaIO/DiskArrays.jl/blob/main/src/cat.jl#L10
function DiskArrays.readblock!(a::ConcatCDFVariable, aout, inds::AbstractUnitRange...)
    DiskArrays._concat_diskarray_block_io(a.data, inds...) do outer_range, array_range, I
        aout_ = outer_range == inds ? aout : view(aout, outer_range...)
        DiskArrays.readblock!(a.data.parents[I], aout_, array_range...)
    end
    return aout
end

CDM.name(var::ConcatCDFVariable) = CDM.name(_parent1(var))
CDM.dimnames(var::ConcatCDFVariable, i::Int) = dimnames(_parent1(var), i)
function CDM.attribnames(var::ConcatCDFVariable)
    if isnothing(var.metadata)
        return CDM.attribnames(_parent1(var))
    else
        return keys(var.metadata)
    end
end

function CDM.attrib(var::ConcatCDFVariable, name::String)
    if isnothing(var.metadata)
        return CDM.attrib(_parent1(var), name)
    else
        return var.metadata[name]
    end
end

function Base.cat(A1::CDFVariable, As::CDFVariable...; dims)
    return ConcatCDFVariable(cat_disk(dims, A1, As...), nothing)
end

function Base.cat(A1::ConcatCDFVariable, As::CDFVariable...; dims)
    return ConcatCDFVariable(cat_disk(dims, A1, As...), nothing)
end

unwrap(var::ConcatCDFVariable) = var.data
_parents(var) = var.data.parents
_parent1(var) = var.data.parents[1]

function CDM.dim(var::ConcatCDFVariable, i::Int; lazy = false)
    parents = _parents(var)
    var0 = parents[1]
    dname = dimnames(var0, i)
    isnothing(dname) && return axes(var.data, i)
    dim_var1 = var0.parentdataset.source[dname]
    return if !is_record_varying(dim_var1)
        lazy ? dim_var1 : Array(dim_var1)
    else
        # TODO: handle multiple dimensions
        concat_dim_var = ConcatCDFVariable(map(x -> x.parentdataset.source[dname], parents))
        lazy ? concat_dim_var : Array(concat_dim_var)
        # out = similar(dim_var1, size(var.data, i))
        # s1 = length(dim_var1)
        # DiskArrays.readblock!(dim_var1, view(out, 1:s1), axes(dim_var1)...)
        # s0 = 1 + s1
        # @inbounds for i in 2:length(parents)
        #     dim_var = parents[i].parentdataset.source[dname]
        #     sd = length(dim_var)
        #     out_view = view(out, s0:(s0 + sd - 1))
        #     DiskArrays.readblock!(dim_var, out_view, axes(dim_var)...)
        #     s0 += sd
        # end
        # return out
        # Method 1
        # mapreduce(x -> x.parentdataset.source[dname][:], vcat, parents)

        # Method 2
        # return Array(DiskArrays.ConcatDiskArray(dim_vars))
    end
end
# 
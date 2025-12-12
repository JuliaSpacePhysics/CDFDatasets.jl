struct ConcatCDFVariable{T, N, A <: AbstractArray{T, N}, MD} <: AbstractCDFVariable{T, N}
    data::A
    metadata::MD
end

"""
    ConcatCDFVariable(arrays; metadata = nothing, dim = nothing)

Concatenate multiple CDF variables along the `dim` dimension (by default the record dimension (last dimension)).
"""
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
# Like _concat_diskarray_block_io but faster
@inline function fast_concat_diskarray_block_io(f, a, inds...)
    # Find affected blocks and indices in blocks
    blockinds = map(inds, a.startinds, size(a.parents)) do i, si, s
        bi1 = max(searchsortedlast(si, first(i)), 1)
        bi2 = min(searchsortedfirst(si, last(i) + 1) - 1, s)
        bi1:bi2
    end
    for cI in CartesianIndices(blockinds)
        myar = a.parents[cI]
        mysize = size(myar)
        array_range = map(cI.I, a.startinds, mysize, inds) do ii, si, ms, indstoread
            max(first(indstoread) - si[ii] + 1, 1):min(last(indstoread) - si[ii] + 1, ms)
        end
        outer_range = map(cI.I, a.startinds, array_range, inds) do ii, si, ar, indstoread
            (first(ar) + si[ii] - first(indstoread)):(last(ar) + si[ii] - first(indstoread))
        end
        f(outer_range, array_range, cI)
    end
    return
end

function DiskArrays.readblock!(a::ConcatCDFVariable, aout, inds::AbstractUnitRange...)
    data = a.data
    fast_concat_diskarray_block_io(data, inds...) do outer_range, array_range, I
        #TODO: investigate a better way to do this
        # Method 1 (faster but allocates more)
        aout[outer_range...] = data.parents[I][array_range...]
        # Method 2 (slower but allocates less)
        # if outer_range == inds
        # Direct write to output when ranges align
        # DiskArrays.readblock!(data.parents[I], aout, array_range...)
        # else
        # Only use view when ranges don't align
        # DiskArrays.readblock!(data.parents[I], view(aout, outer_range...), array_range...)
        # end
    end
    return aout
end

_cat(A...) = cat(A...; dims = Val(ndims(A[1])))

# This provides a performance boost
function Base.Array(var::ConcatCDFVariable)
    vars = var.data.parents
    dims = ndims(var)
    f = dims == 1 ? vcat : (dims == 2 ? hcat : _cat)
    return reduce(f, Array.(vars))
end

CDM.name(var::ConcatCDFVariable) = CDM.name(_parent1(var))
function CDM.attribnames(var::ConcatCDFVariable)
    names = CDM.attribnames(_parent1(var))
    return isnothing(var.metadata) ? names : union(names, keys(var.metadata))
end

function CDM.attrib(var::ConcatCDFVariable, name::String)
    return if isnothing(var.metadata)
        CDM.attrib(_parent1(var), name)
    else
        var.metadata[name]
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

function CDM.variable(var::ConcatCDFVariable, name::String)
    vars = map(_parents(var)) do pv
        pv.parentdataset[name]
    end
    return ConcatCDFVariable(vars)
end

CDM.dataset(var::ConcatCDFVariable) = ConcatCDFDataset(dataset.(var.data.parents))

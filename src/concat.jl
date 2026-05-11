function _concat_cdf_variable(arrays; name = CDM.name(first(arrays)), metadata = CDM.attrib(first(arrays)), dim = nothing, parentdataset = nothing)
    d = @something dim ndims(first(arrays))
    sz = map(ntuple(identity, d)) do i
        i == d ? length(arrays) : 1
    end
    cdas = reshape(_as_array(arrays), sz)
    data = DiskArrays.ConcatDiskArray(_storage_parent.(cdas))
    return CDFVariable(data, name, parentdataset, metadata)
end

_as_array(arrays::AbstractArray) = arrays
_as_array(arrays) = collect(arrays)

_storage_parent(var::CDFVariable) = parent(var)
_storage_parent(data) = data

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

function DiskArrays.readblock!(a::CDFVariable{T, N, <:DiskArrays.ConcatDiskArray}, aout, inds::AbstractUnitRange...) where {T, N}
    data = a.data
    fast_concat_diskarray_block_io(data, inds...) do outer_range, array_range, I
        aout[outer_range...] = data.parents[I][array_range...]
    end
    return aout
end

_cat(A...) = cat(A...; dims = Val(ndims(A[1])))

# Performance boost over generic DiskArrays path
function Base.Array(var::CDFVariable{T, N, <:DiskArrays.ConcatDiskArray}) where {T, N}
    vars = var.data.parents
    d = ndims(var)
    f = d == 1 ? vcat : (d == 2 ? hcat : _cat)
    return reduce(f, Array.(vars))
end

function Base.cat(A1::CDFVariable, As::CDFVariable...; dims)
    return _concat_cdf_variable((A1, As...); dim = dims)
end

@inline function CDM.dataset(var::CDFVariable{T, N, <:DiskArrays.ConcatDiskArray}) where {T, N}
    ds = var.parentdataset
    return isnothing(ds) ? _concat_dataset(var.data.parents) : ds
end

_concat_dataset(vars) = ConcatCDFDataset(map(CDM.dataset, vars))

function _concat_dataset(vars...)
    sources = map(CDM.dataset, vars)
    return ConcatCDFDataset(sources)
end

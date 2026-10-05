# Lazy concatenation of `parts` along dimension `dim`
function _concat(parts, dim)
    sz = ntuple(i -> i == dim ? length(parts) : 1, dim)
    return _irregular_chunks(DiskArrays.ConcatDiskArray(reshape(_as_array(parts), sz)))
end

# ConcatDiskArray picks RegularChunks or IrregularChunks depending on whether the parts have
# equal lengths, so the same variable would get a different type (and separately compiled and
# precompiled code) per file set. Always using IrregularChunks keeps one type.
function _irregular_chunks(a::DiskArrays.ConcatDiskArray{T, N, P, C, HC, ID}) where {T, N, P, C, HC, ID}
    chunks = DiskArrays.GridChunks(map(_as_irregular, a.chunks.chunks))
    return DiskArrays.ConcatDiskArray{T, N, P, typeof(chunks), HC, ID}(a.parents, a.startinds, a.size, chunks, a.haschunks, a.innerdims)
end

_as_irregular(c::DiskArrays.IrregularChunks) = c
_as_irregular(c) = DiskArrays.IrregularChunks(; chunksizes = filter!(!iszero, length.(c)))

_as_array(arrays::AbstractArray) = arrays
_as_array(arrays) = collect(arrays)

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

function _readraw!(data::DiskArrays.ConcatDiskArray, aout, inds...)
    fast_concat_diskarray_block_io(data, inds...) do outer_range, array_range, I
        aout[outer_range...] = data.parents[I][array_range...]
    end
    return aout
end

_cat(A...) = cat(A...; dims = Val(ndims(A[1])))

# Performance boost over generic DiskArrays path
function Base.Array(var::CDFVariable{T, N, <:DiskArrays.ConcatDiskArray}) where {T, N}
    vars = parent(var).parents
    size(vars, N) == length(vars) || return var[ntuple(_ -> Colon(), N)...]  # not along the last dimension
    f = N == 1 ? vcat : (N == 2 ? hcat : _cat)
    A = reduce(f, Array.(vars))
    m = _mask(var)
    isnothing(m) && return A
    return SDM.mask_invalid!(eltype(A) === T ? A : similar(A, T), A, m, 1)
end

# Each part decodes itself, so parts may differ in checks and stored type.
Base.cat(A1::CDFVariable, As::CDFVariable...; dims) =
    CDFVariable(_concat((A1, As...), dims), CDM.name(A1), nothing, CDM.attrib(A1), nothing)

@inline function CDM.dataset(var::CDFVariable{T, N, <:DiskArrays.ConcatDiskArray}) where {T, N}
    ds = getfield(var, :parentdataset)
    return isnothing(ds) ? CDFDataset(CDM.dataset.(parent(var).parents)) : ds
end

# Lazy concatenation of `parts` along dimension `dim`
function _concat(parts, dim)
    sz = ntuple(i -> i == dim ? length(parts) : 1, dim)
    return _normalize(DiskArrays.ConcatDiskArray(reshape(_as_array(parts), sz)), dim)
end

# ConcatDiskArray picks RegularChunks or IrregularChunks depending on whether the parts have
# equal lengths, so the same variable would get a different type (and separately compiled and
# precompiled code) per file set. Always using IrregularChunks keeps one type.
# Its sizes also count a zero-length part as length 1 (`arraysize_and_startinds` marks unset
# sizes with 0), so they are recomputed from the parts.
function _normalize(a::DiskArrays.ConcatDiskArray{T, N, P, C, HC, ID}, dim) where {T, N, P, C, HC, ID}
    chunks = DiskArrays.GridChunks(map(_as_irregular, a.chunks.chunks))
    lens = Int[size(p, dim) for p in a.parents]
    p1 = first(a.parents)
    startinds = ntuple(d -> d == dim ? cumsum([1; lens[1:(end - 1)]]) : [1], N)
    sz = ntuple(d -> d == dim ? sum(lens) : size(p1, d), N)
    return DiskArrays.ConcatDiskArray{T, N, P, typeof(chunks), HC, ID}(a.parents, startinds, sz, chunks, a.haschunks, a.innerdims)
end

_as_irregular(c::DiskArrays.IrregularChunks) = c
_as_irregular(c) = DiskArrays.IrregularChunks(; chunksizes = filter!(!iszero, Int[length(r) for r in c]))

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

# Each part decodes itself, so parts may differ in checks and stored type.
function Base.cat(A1::CDFVariable, As::CDFVariable...; dims)
    parts = (A1, As...)
    return CDFVariable(_concat(parts, dims), CDM.name(A1), CDFDataset(collect(map(dataset, parts))), CDM.attrib(A1), nothing)
end

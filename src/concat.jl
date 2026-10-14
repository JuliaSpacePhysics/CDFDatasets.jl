# Lazy concatenation of `parts` along dimension `dim`, built directly because
# `DiskArrays.ConcatDiskArray(parts)` compiles slowly per part type, and it
# - picks RegularChunks or IrregularChunks by whether part lengths are equal, giving the same
#   variable a different type per file set; IrregularChunks throughout keeps one type.
# - counts a zero-length part as length 1 (`arraysize_and_startinds` marks unset sizes with 0).
# Only sizes and chunks of `parts` are read, so one unspecialized method serves every part type.
_concat(@nospecialize(parts), dim) = _concat(parts, dim, Val(max(ndims(first(parts)), dim)))

function _concat(@nospecialize(parts), dim, ::Val{N}) where {N}
    p1 = first(parts)
    for p in parts, d in 1:N
        d == dim || size(p, d) == size(p1, d) || throw(DimensionMismatch("parts differ in size along dimension $d"))
    end
    lens = Int[size(p, dim) for p in parts]
    startinds = ntuple(d -> d == dim ? cumsum([1; lens[1:(end - 1)]]) : [1], Val(N))
    sz = ntuple(d -> d == dim ? sum(lens) : size(p1, d), Val(N))
    chunks = DiskArrays.GridChunks(ntuple(Val(N)) do d
        sizes = d == dim ? Int[n for p in parts for n in _chunksizes(p, d)] : _chunksizes(p1, d)
        DiskArrays.IrregularChunks(; chunksizes = filter!(!iszero, sizes))
    end)
    hc = DiskArrays.Chunked(DiskArrays.batchstrategy(chunks))
    T = mapreduce(eltype, promote_type, parts)
    parents = reshape(collect(parts), ntuple(d -> d == dim ? length(parts) : 1, Val(N)))
    return DiskArrays.ConcatDiskArray{T, N, typeof(parents), typeof(chunks), typeof(hc), ndims(p1)}(
        parents, startinds, sz, chunks, hc, Val(ndims(p1))
    )
end

_chunksizes(a, d) = d <= ndims(a) ? Int[length(r) for r in DiskArrays.eachchunk(a).chunks[d]] : [1]

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

# Lazy concatenation  along dimension `dim`, which starts part `k` at index `starts[k]`.
struct ConcatArray{T, N, P <: AbstractVector} <: AbstractLazyArray{T, N}
    parents::P
    dim::Int
    starts::Vector{Int}
    size::NTuple{N, Int}
end

Base.size(a::ConcatArray) = a.size

_concat(parts, dim) = _concat(collect(parts), dim, Val(max(ndims(first(parts)), dim)))

function _concat(parts::AbstractVector, dim, ::Val{N}) where {N}
    p1 = first(parts)
    for p in parts, d in 1:N
        d == dim || size(p, d) == size(p1, d) || throw(DimensionMismatch("parts differ in size along dimension $d"))
    end
    starts = cumsum([1; Int[size(p, dim) for p in parts]])
    sz = ntuple(d -> d == dim ? last(starts) - 1 : size(p1, d), Val(N))
    T = mapreduce(eltype, promote_type, parts)
    return ConcatArray{T, N, typeof(parts)}(parts, dim, starts, sz)
end

function readregion!(a::ConcatArray{T, N}, dest, inds::Vararg{AbstractUnitRange, N}) where {T, N}
    r = inds[a.dim]
    for (k, p) in enumerate(a.parents)
        lo, hi = max(first(r), a.starts[k]), min(last(r), a.starts[k + 1] - 1)
        lo > hi && continue
        pinds = Base.setindex(inds, (lo - a.starts[k] + 1):(hi - a.starts[k] + 1), a.dim)
        dinds = Base.setindex(map(i -> 1:length(i), inds), (lo - first(r) + 1):(hi - first(r) + 1), a.dim)
        readregion!(p, view(dest, dinds...), ntuple(d -> pinds[d], ndims(p))...)
    end
    return dest
end

_filevar(data::ConcatArray) = _filevar(first(data.parents))

# Each part decodes itself, so parts may differ in checks and stored type.
function Base.cat(A1::CDFVariable, As::CDFVariable...; dims)
    parts = (A1, As...)
    return CDFVariable(_concat(parts, dims), SDM.name(A1), CDFDataset(collect(map(dataset, parts))), A1.attrib, nothing)
end

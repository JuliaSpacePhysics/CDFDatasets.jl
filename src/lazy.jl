# Arrays read on access through one method, `readregion!(a, dest, ranges::AbstractUnitRange...)
abstract type AbstractLazyArray{T,N} <: AbstractArray{T,N} end

const LazySubArray{T,N} = SubArray{T,N,<:AbstractLazyArray}
const LazyReshapedArray{T,N} = Base.ReshapedArray{T,N,<:AbstractLazyArray}
const LazyLike{T,N} = Union{AbstractLazyArray{T,N},LazySubArray{T,N},LazyReshapedArray{T,N}}

readregion!(a::AbstractArray, dest, ranges::AbstractUnitRange...) = copyto!(dest, view(a, ranges...))

function readregion!(a::AbstractLazyArray, dest, ranges::AbstractUnitRange...)
    eltype(dest) === eltype(a) && throw(MethodError(readregion!, (a, dest, ranges...)))
    block = Array{eltype(a)}(undef, map(length, ranges))
    readregion!(a, block, ranges...)
    return copyto!(dest, block)
end

function readregion!(v::LazySubArray, dest, ranges::AbstractUnitRange...)
    pinds = Base.reindex(parentindices(v), ranges)
    if all(i -> i isa Union{Integer,AbstractUnitRange}, pinds)
        readregion!(parent(v), reshape(dest, map(length, pinds)), map(i -> i isa Integer ? (i:i) : i, pinds)...)
    else
        copyto!(dest, _getindex(parent(v), pinds))
    end
    return dest
end

# Reshapes (e.g. `vec`) of lazy arrays are rare and small; they read the parent whole.
readregion!(r::LazyReshapedArray, dest, ranges::AbstractUnitRange...) =
    copyto!(dest, view(reshape(Array(parent(r)), size(r)), ranges...))

Base.@propagate_inbounds Base.getindex(a::AbstractLazyArray, I...) = _getindex(a, map(_indexable, to_indices(a, I)))

# Base copies non-scalar indexing of views and reshapes element by element; read the bounding box instead.
Base._unsafe_getindex(::IndexStyle, a::Union{LazySubArray,LazyReshapedArray}, I::Vararg{Union{Real,AbstractArray},N}) where {N} =
    _getindex(a, map(_indexable, I))

# `LogicalIndex` only iterates.
_indexable(i::Base.LogicalIndex) = collect(i)
_indexable(i::AbstractArray{CartesianIndex{1}}) = map(x -> x[1], i)
_indexable(i) = i

_box(i::Integer) = i:i
_box(r::AbstractUnitRange) = r
_box(v) = isempty(v) ? (1:0) : (minimum(v):maximum(v))
_shift(i::Integer, o) = i - o
_shift(r::AbstractUnitRange, o) = (first(r) - o):(last(r) - o)
_shift(v, o) = v .- o

# Reads the bounding box of `J`, then picks `J` from it.
function _getindex(a::AbstractArray{T,N}, J::Tuple) where {T,N}
    @boundscheck checkbounds(a, J...)
    if length(J) == N && all(i -> !(eltype(i) <: CartesianIndex), J)
        box = map(_box, J)
        shape = map(length, Base.index_shape(J...))
        any(isempty, box) && return Array{T}(undef, shape)
        block = Array{T,N}(undef, map(length, box))
        readregion!(a, block, box...)
        all(i -> i isa Integer, J) && return block[1]
        # `reshape` allocates a new header even when the shape is unchanged
        all(i -> i isa AbstractUnitRange, J) && return block
        all(i -> i isa Union{Integer,AbstractUnitRange}, J) && return reshape(block, shape)
        return block[map((i, b) -> _shift(i, first(b) - 1), J, box)...]
    elseif length(J) == 1 && !(eltype(only(J)) <: CartesianIndex)  # linear indexing: the whole records it spans
        i = only(J)
        isempty(i) && return Array{T}(undef, map(length, Base.index_shape(i)))
        L = prod(Base.front(size(a)))
        r = fld1(minimum(i), L):fld1(maximum(i), L)
        block = Array{T,N}(undef, (Base.front(size(a))..., length(r)))
        readregion!(a, block, Base.front(axes(a))..., r)
        return block[_shift(i, (first(r) - 1) * L)]
    else
        return Array(a)[J...]
    end
end

function Base.copyto!(dest::Array, src::LazyLike)
    if size(dest) == size(src) && eltype(dest) === eltype(src)
        readregion!(src, dest, axes(src)...)
    else
        copyto!(dest, Array(src))
    end
    return dest
end

# Base reads through `unalias` before copying element by element (`setindex!`, `copyto!`, `cat`, ...).
Base.unalias(dest, a::LazyLike) = Array(a)

Base.permutedims(a::LazyLike, perm) = permutedims(Array(a), perm)
Base.permutedims(a::LazyLike) = permutedims(Array(a))

Base.Broadcast.broadcastable(a::LazyLike) = Array(a)

function Base.iterate(a::LazyLike)
    isempty(a) && return nothing
    A = Array(a)
    x, st = iterate(A)
    return x, (A, st)
end
function Base.iterate(::LazyLike, state)
    A, st = state
    r = iterate(A, st)
    r === nothing && return nothing
    return r[1], (A, r[2])
end

# Reductions (`sum`, `maximum`, `extrema`, `count`, ...) go through `mapreduce`
Base.mapreduce(f, op, a::LazyLike; kw...) = mapreduce(f, op, Array(a); kw...)

# A CommonDataFormat variable handle as a lazy array.
struct FileArray{T,N,V<:CDF.CDFVariable{T,N}} <: AbstractLazyArray{T,N}
    var::V
end
Base.size(a::FileArray) = size(a.var)
readregion!(a::FileArray{T,N}, dest::AbstractArray{T}, ranges::Vararg{AbstractUnitRange,N}) where {T,N} = read!(a.var, dest, ranges...)

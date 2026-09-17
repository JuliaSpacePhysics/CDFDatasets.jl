function find_indices(tdim::Vector, interval::Interval)
    if !issorted(tdim)
        idx = findall(in(interval), tdim)
        isempty(idx) && return 1:0
        return length(idx) == last(idx) - first(idx) + 1 ? (first(idx):last(idx)) : idx
    end
    t0, t1 = endpoints(interval)
    i0 = isleftclosed(interval) ? searchsortedfirst(tdim, t0) : searchsortedlast(tdim, t0) + 1
    i1 = isrightclosed(interval) ? searchsortedlast(tdim, t1) : searchsortedfirst(tdim, t1) - 1
    return i0:i1
end

function _getindex_interval(var::CDFVariable{T}, interval::Interval) where {T}
    N = ndims(var)
    tdim = T <: AbstractDateTime ? var : depend(var, N)
    isnothing(tdim) && throw(ArgumentError("Interval indexing requires a time coordinate (DEPEND_0); none found for $(var.name)"))
    return selectdim(var, N, find_indices(convert(Vector, tdim), interval))
end

Base.getindex(var::CDFVariable, interval::Interval) = _getindex_interval(var, interval)

function find_indices(tdim::Vector, interval::Interval)
    t0, t1 = endpoints(interval)
    return if issorted(tdim)
        i0 = isleftclosed(interval) ? searchsortedfirst(tdim, t0) : searchsortedlast(tdim, t0) + 1
        i1 = isrightclosed(interval) ? searchsortedlast(tdim, t1) : searchsortedfirst(tdim, t1) - 1
        i0:i1
    else
        findall(in(interval), tdim)
    end
end

function _getindex_interval(var::CDFVariable{T}, interval::Interval) where {T}
    # Handle the case where the data itself is the dimension variable
    return if T <: AbstractDateTime
        tdim = convert(Vector{T}, var)
        indices = find_indices(tdim, interval)
        rebuild(var, view(tdim, indices))
    else
        tdim = convert(Vector, dim(var, ndims(var)))
        indices = find_indices(tdim, interval)
        selectdim(var, ndims(var), indices)
    end
end

Base.getindex(var::CDFVariable, interval::Interval) = _getindex_interval(var, interval)

function find_indices(tdim::Vector, t0, t1)
    return if issorted(tdim)
        searchsortedfirst(tdim, t0):searchsortedlast(tdim, t1)
    else
        findall(t -> t >= t0 && t <= t1, tdim)
    end
end

function DiskArrays.getindex_disk(var::CDFVariable{T}, interval::Interval) where {T}
    t0, t1 = endpoints(interval)
    # Handle the case where the data itself is the dimension variable
    return if T <: AbstractDateTime
        tdim = convert(Vector{T}, var)
        indices = find_indices(tdim, t0, t1)
        @view tdim[indices]
    else
        tdim = convert(Vector, dim(var, ndims(var)))
        indices = find_indices(tdim, t0, t1)
        selectdim(var, ndims(var), indices)
    end
end

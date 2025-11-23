unwrap(var::SubCDFVariable) = var.v

function CDM.dim(var::SubCDFVariable, i::Int)
    indices = parentindices(var)[i]
    return CDM.dim(parent(var), i; lazy = true)[indices]
end

function find_indices(var, t0, t1)
    tdim = convert(Vector, dim(var, ndims(var)))
    return if issorted(tdim)
        searchsortedfirst(tdim, t0):searchsortedlast(tdim, t1)
    else
        findall(t -> t >= t0 && t <= t1, tdim)
    end
end

function DiskArrays.getindex_disk(var::AbstractCDFVariable, interval::Interval)
    t0, t1 = endpoints(interval)
    indices = find_indices(var, t0, t1)
    return selectdim(var, ndims(var), indices)
end

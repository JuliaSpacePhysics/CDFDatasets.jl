function CDM.dim(var::SubCDFVariable, i::Int)
    dvar = CDM.dim(parent(var), i)
    return if dvar isa AbstractCDFVariable && is_record_varying(dvar)
        indices = parentindices(var)[ndims(var)]
        selectdim(dvar, ndims(dvar), indices)
    else
        dvar
    end
end

function find_indices(tdim::Vector, t0, t1)
    return if issorted(tdim)
        searchsortedfirst(tdim, t0):searchsortedlast(tdim, t1)
    else
        findall(t -> t >= t0 && t <= t1, tdim)
    end
end

function DiskArrays.getindex_disk(var::AbstractCDFVariable, interval::Interval)
    t0, t1 = endpoints(interval)
    # Handle the case where the data itself is the dimension variable
    return if eltype(var) <: AbstractDateTime
        tdim = convert(Vector, var)
        indices = find_indices(tdim, t0, t1)
        @view tdim[indices]
    else
        tdim = convert(Vector, dim(var, ndims(var)))
        indices = find_indices(tdim, t0, t1)
        selectdim(var, ndims(var), indices)
    end
end

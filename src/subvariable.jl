unwrap(var::SubCDFVariable) = var.v

function CDM.dim(var::SubCDFVariable, i::Int)
    indices = parentindices(var)[i]
    return @views CDM.dim(parent(var), i)[indices]
end

# function find_indices(var, t0, t1)
#     tdim = dim(var, ndims(var))
#     return if issorted(tdim)
#         searchsortedfirst(tdim, t0):searchsortedlast(tdim, t1)
#     else
#         findall(t -> t >= t0 && t <= t1, tdim)
#     end
# end
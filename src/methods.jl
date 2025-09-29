"""Replaces fill values by NaN for `var` with float type elements."""
function replace_fillval_by_nan!(A; verbose = false)
    T = eltype(A)
    fillval = fillvalue(T)
    if T <: AbstractFloat
        nan = T(NaN)
        replace!(A, fillval => nan)
    else
        verbose && @warn "Cannot replace fill values for Array of type $T"
    end
    return A
end

function replace_invalid!(A::AbstractArray{T}, valid_mins, valid_maxs) where {T}
    isnothing(valid_mins) && return A
    isnothing(valid_maxs) && return A
    vmin = only(valid_mins)
    vmax = only(valid_maxs)
    return @. A = ifelse((A < vmin) | (A > vmax), T(NaN), A)
end

function replace_invalid!(A::AbstractMatrix{T}, valid_mins, valid_maxs) where {T}
    nan = T(NaN)
    isnothing(valid_mins) && return A
    isnothing(valid_maxs) && return A
    for (i, r) in enumerate(eachrow(A))
        vmin = get(valid_mins, i, valid_mins[1])
        vmax = get(valid_maxs, i, valid_maxs[1])
        @. r = ifelse((r < vmin) | (r > vmax), nan, r)
    end
    return A
end

function sanitize(var::AbstractCDFVariable; replace_fillval = true, replace_invalid = true)
    A = Array(var)
    replace_fillval && replace_fillval_by_nan!(A)
    replace_invalid && begin
        vmins = valid_min(var)
        vmaxs = valid_max(var)
        replace_invalid!(A, vmins, vmaxs)
    end
    return A
end
"""Replaces fill values by NaN for `var` with float type elements."""
function replace_fillval_by_nan!(A; verbose=false)
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

function replace_invalid!(A::AbstractVector{T}, valid_mins, valid_maxs) where T <: AbstractFloat
    vmin = only(valid_mins)
    vmax = only(valid_maxs)
    @. A = ifelse((A < vmin) | (A > vmax), T(NaN), A)
end

function replace_invalid!(A, valid_mins, valid_maxs)
    for r in eachrow(A)
        vmin = get(valid_mins, i, valid_mins[1])
        vmax = get(valid_maxs, i, valid_maxs[1])
        @. r = ifelse((r < vmin) | (r > vmax), T(NaN), r)
    end
    return A
end

function replace_invalid(var::AbstractCDFVariable; verbose=false)
    T = eltype(var)
    A = Array(var)
    if T <: AbstractFloat
        vmins = valid_min(var)
        vmaxs = valid_max(var)
        if !isnothing(vmins) || !isnothing(vmaxs)
            replace_invalid!(A, vmins, vmaxs)
        end
    else
        verbose && @warn "Cannot replace invalid values for Array of type $T"
    end
    return A
end
_bound(::Nothing, _) = nothing
_bound(x, _) = x
# ISTP allows one VALIDMIN/VALIDMAX per component along dim 1; shape it to broadcast that way.
_bound(v::AbstractVector, A) = length(v) == 1 ? only(v) : reshape(v, length(v), ntuple(_ -> 1, ndims(A) - 1)...)

_below(x, lo) = x < lo
_below(x, ::Nothing) = false
_above(x, hi) = x > hi
_above(x, ::Nothing) = false
# `isequal` so a NaN FILLVAL matches NaN data; `<`/`>` are false for NaN
isinvalid(x, fillval, lo, hi) = isequal(x, fillval) | _below(x, lo) | _above(x, hi)

_attribs(var) = var.attrib
_attribs(var::CDFVariable) = var.metadata

# Smallest native float that represents T exactly
_float(::Type{T}) where {T <: Union{Int8, UInt8, Int16, UInt16}} = Float32
_float(::Type{T}) where {T} = float(T)

"""
    sanitize(var; replace_fillval = true, replace_invalid = true)

Load `var` as an `Array` with fill values (`FILLVAL`) and out-of-range values
(`VALIDMIN`/`VALIDMAX`) replaced by `NaN`.

Integer variables are promoted to float. Non-`Real` element types (epochs,
strings) have no `NaN` and are returned unchanged.
"""
function sanitize(var; replace_fillval = true, replace_invalid = true)
    A = Array(var)
    T = eltype(A)
    T <: Real || return A
    md = _attribs(var)
    fillval = replace_fillval ? only(@something get(md, "FILLVAL", nothing) fillvalue(T)) : nothing
    lo = replace_invalid ? _bound(get(md, "VALIDMIN", nothing), A) : nothing
    hi = replace_invalid ? _bound(get(md, "VALIDMAX", nothing), A) : nothing
    return _sanitize(_float(T), A, fillval, lo, hi)
end

# Function barrier: attribute values arrive as `Any`.
function _sanitize(::Type{F}, A, fillval, lo, hi) where {F}
    B = eltype(A) === F ? A : Array{F}(undef, size(A))  # `A` is a fresh copy from `Array(var)`
    return @. B = ifelse(isinvalid(A, fillval, lo, hi), F(NaN), F(A))
end

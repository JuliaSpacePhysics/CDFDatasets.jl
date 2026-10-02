_attribs(var) = var.attrib
_attribs(var::CDFVariable) = var.metadata

"""
    sanitize(var; replace_fillval = true, replace_invalid = true)

Load `var` as an `Array` with fill values (`FILLVAL`, else the CDF default for its type) and
out-of-range values (`VALIDMIN`/`VALIDMAX`) replaced by `NaN`.

Integer variables are promoted to float. Non-`Real` element types (epochs,
strings) have no `NaN` and are returned unchanged.
"""
function SDM.sanitize(var::AbstractCDFVariable; replace_fillval = true, replace_invalid = true)
    A = Array(var)
    T = eltype(A)
    T <: Real || return A
    md = _attribs(var)
    fillval = replace_fillval ? @something(get(md, "FILLVAL", nothing), fillvalue(T)) : nothing
    validmin = replace_invalid ? get(md, "VALIDMIN", nothing) : nothing
    validmax = replace_invalid ? get(md, "VALIDMAX", nothing) : nothing
    # ISTP gives one VALIDMIN/VALIDMAX per component along dimension 1
    return SDM.mask_invalid!(A; fillval, validmin, validmax, dims = 1)
end

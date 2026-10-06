# Reference
# [ISTP Metadata Guidelines: Global Attributes](https://spdf.gsfc.nasa.gov/istp_guide/gattributes.html)
# [ISTP Metadata Guidelines: Variables](https://spdf.gsfc.nasa.gov/istp_guide/variables.html)

# Values are free-form strings ("1", "01", "2.0", "v3.4.0"); VersionNumber parses all and orders them correctly.
function data_version(ds)
    dv = get(CDM.attribs(ds), "Data_version", nothing)
    isnothing(dv) && return nothing
    v = dv isa AbstractVector ? only(dv) : dv
    return VersionNumber(v isa AbstractString ? strip(v) : v)
end
var_type(var) = get(var.metadata, "VAR_TYPE", "")
# Reference
# [ISTP Metadata Guidelines: Global Attributes](https://spdf.gsfc.nasa.gov/istp_guide/gattributes.html)
# [ISTP Metadata Guidelines: Variables](https://spdf.gsfc.nasa.gov/istp_guide/variables.html)

function data_version(ds)
    dv = attrib(ds, "Data_version")
    if dv isa String
        return parse(Int, dv)
    elseif dv isa AbstractVector
        return parse(Int, only(dv))
    end
end
var_type(var) = attrib(var, "VAR_TYPE")
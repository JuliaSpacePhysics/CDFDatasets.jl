# Reference
# [ISTP Metadata Guidelines: Global Attributes](https://spdf.gsfc.nasa.gov/istp_guide/gattributes.html)
# [ISTP Metadata Guidelines: Variables](https://spdf.gsfc.nasa.gov/istp_guide/variables.html)

data_version(ds::CDFDataset) = parse(Int, ds.attrib["Data_version"])
var_type(var) = var.attrib["VAR_TYPE"]
module CDFDatasetsPyCDFppExt

import CDFDatasets: cdf_type
import CDFDatasets as CDF
using CDFDatasets: PyCDFppDataset, CDFType
using PyCDFpp
using PyCDFpp.PythonCall

function CDF.PyCDFppDataset(file::AbstractString; lazy_load = true)
    return PyCDFpp.load(file; lazy_load)
end


CDF.cdf_type(var::PyCDFVariable) = CDF.cdf_type(var.py)
CDF.cdf_type(py::Py) = CDFType(PyCDFpp.py_cdf_type(py))

end

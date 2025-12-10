using Pkg
Pkg.instantiate()
@time using CDFDatasets
using Chairmarks
using DimensionalData

data_path(fname) = joinpath(pkgdir(CDFDatasets), "data", fname)

elx_file = data_path("elb_l2_epdef_20210914_v01.cdf")
ds = cdfopen(elx_file)
var = ds["elb_pef_hs_Epat_eflux"]
@info @b DimArray(var)

using Test
using PyCDFpp
using PyCDFpp: UnixTime

data_path(fname) = joinpath(pkgdir(PyCDFpp), "data", fname)

@testset "CDFDatasets.jl (cross validation with pycdfpp)" begin
    omni_file = data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
    ds_py = PyCDF(omni_file)
    @test length(keys(ds_py)) == 12
    @test PyCDFpp.tt2000_to_datetime_py(ds_py.py["Epoch"]) == UnixTime.(ds_py["Epoch"])
end

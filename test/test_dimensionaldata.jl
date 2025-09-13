using CDFDatasets
using Test
using DimensionalData

@testset "DimensionalData Extension" begin
    omni_file = joinpath(@__DIR__, "..", "data", "omni_coho1hr_merged_mag_plasma_20240901_v01.cdf")
    ds = CDFDataset(omni_file)
    var = ds["BR"]
    @test_nowarn DimArray(var)
end

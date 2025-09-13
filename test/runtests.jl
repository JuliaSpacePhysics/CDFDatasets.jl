using CDFDatasets
using CDFDatasets: var_type, cdf_type, CDFType2JuliaType
using Test
import CDFDatasets as CDF
import CDFDatasets.CommonDataModel as CDM

@testset "CDFDatasets.jl (ISTP)" begin
    omni_file = joinpath(@__DIR__, "..", "data", "omni_coho1hr_merged_mag_plasma_20240901_v01.cdf")
    ds = CDFDataset(omni_file)
    @test ds isa CDFDataset
    @test CDF.PyCDFpp.tt2000_to_datetime_py(ds.source.py["Epoch"]) == CDF.UnixTime.(ds["Epoch"])
end

@testset "CDFDatasets.jl (ELFIN)" begin
    # Test file path
    elx_file = joinpath(@__DIR__, "..", "data", "elb_l2_epdef_20210914_v01.cdf")

    @testset "Basic CDF Reading" begin
        # Create CDF reader
        ds = CDFDataset(elx_file)

        @test CDF.data_version(ds) == 1

        # Test getting variable names
        @test keys(ds) isa Vector{String}
        @test length(keys(ds)) > 0

        # Test getting attribute names
        attributes = CDM.attribnames(ds)
        @test isa(attributes, Vector{String})
        @test length(attributes) > 0
        @test length(ds.attrib) == length(attributes)

        var = ds["elb_pef_hs_time"]
        @test var isa CDFVariable
        @test cdf_type(var) == CDF.CDF_TIME_TT2000
        @test var_type(var) == "support_data"
        @test CDF.CDFType2JuliaType[cdf_type(var)] == CDF.UnixTime
        @test length(var.attrib) == length(CDM.attribnames(var))
        @test CDF.PyCDFpp.tt2000_to_datetime_py(ds.source.py["elb_pef_hs_time"]) == ds["elb_pef_hs_time"]

        @test ndims(ds["elb_pef_hs_epa_spec"]) == 2
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 1) == ds["elb_pef_hs_time"]
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 2) == ds["elb_pef_energies_mean"]

        @test ndims(ds["elb_pef_hs_Epat_eflux"]) == 3
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 1) == ds["elb_pef_hs_time"]
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 2) == ds["elb_pef_hs_epa_spec"]
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 3) == ds["elb_pef_energies_mean"]
        @test var_type(ds["elb_pef_hs_Epat_eflux"]) == "data"
    end

end


@testset "CDFDataset" begin
    test_file = joinpath(@__DIR__, "..", "data", "ge_h0_cpi_00000000_v01.cdf")
    ds = CDFDataset(test_file)
    ds["label_v3c"]
    @test ds isa CDFDataset
end

# Include DimensionalData extension tests if available
include("test_dimensionaldata.jl")
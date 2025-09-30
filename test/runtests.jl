using CDFDatasets
using CDFDatasets: var_type, cdf_type
using Test
import CDFDatasets as CDF
import CDFDatasets.CommonDataModel as CDM
using Dates
using DimensionalData

data_path(fname) = joinpath(pkgdir(CDFDatasets), "data", fname)

@testset "Aqua" begin
    using Aqua
    Aqua.test_all(CDFDatasets)
end

@static if VERSION >= v"1.11"
    using PyCDFpp
    using PyCDFpp: UnixTime
    @testset "CDFDatasets.jl (cross validation with pycdfpp)" begin
        omni_file = data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
        ds = CDFDataset(omni_file)
        ds_py = CDFDataset(omni_file, backend = PyCDFpp)
        @test ds isa CDFDataset

        @test PyCDFpp.tt2000_to_datetime_py(ds_py.source.py["Epoch"]) == UnixTime.(ds_py["Epoch"])
        @test Dates.DateTime.(UnixTime.(ds_py["Epoch"])) == Dates.DateTime.(ds["Epoch"])
        @test all(zip(values(ds.attrib), values(ds_py.attrib))) do (k, v)
            k == v
        end
        @test CDM.dimnames(ds["V"], 1) == CDM.dimnames(ds_py["V"], 1)
    end
end


@testset "ConcatCDFVariable and DimArray" begin
    file1 = data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
    file2 = data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf")
    var1 = CDFDataset(file1)["V"]
    var2 = CDFDataset(file2)["V"]
    var = cat(var1, var2; dims = 1)
    @test var == ConcatCDFVariable([var1, var2])
    @test var isa ConcatCDFVariable
    @test var.data == vcat(var1.data, var2.data)
    @test DimArray(var).dims[1] == vcat(DimArray(var1).dims[1], DimArray(var2).dims[1])
    @test var.attrib == var1.attrib
    @test CDM.dimnames(var) == CDM.dimnames(var1)
end

@testset "CDFDatasets.jl (ELFIN)" begin
    # Test file path
    elx_file = data_path("elb_l2_epdef_20210914_v01.cdf")
    ds = CDFDataset(elx_file)
    @testset "Basic CDF Reading" begin
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
        @test cdf_type(var) == CDF.CommonDataFormat.CDF_TIME_TT2000
        @test var_type(var) == "support_data"
        @test length(var.attrib) == length(CDM.attribnames(var))

        @test ndims(ds["elb_pef_hs_epa_spec"]) == 2
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 2) == ds["elb_pef_hs_time"]
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 1) == ds["elb_pef_energies_mean"]

        @test ndims(ds["elb_pef_hs_Epat_eflux"]) == 3
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 3) == ds["elb_pef_hs_time"]
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 1) == ds["elb_pef_hs_epa_spec"]
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 2) == ds["elb_pef_energies_mean"]
        @test is_record_varying(ds["elb_pef_hs_Epat_eflux"]) == true
        @test is_record_varying(ds["elb_pef_hs_epa_spec"]) == true
        @test is_record_varying(ds["elb_pef_energies_mean"]) == false
        @test var_type(ds["elb_pef_hs_Epat_eflux"]) == "data"
    end

    @testset "replace_invalid" begin
        var = ds["elb_pef_hs_Epat_eflux"]
        @test sanitize(var) isa Array
        @test sanitize(ds["elb_pef_hs_epa_spec"]) isa Matrix
    end

end


@testset "CDFDataset" begin
    test_file = joinpath(@__DIR__, "..", "data", "ge_h0_cpi_00000000_v01.cdf")
    ds = CDFDataset(test_file)
    @test ds["label_v3c"].data == ["Ion Vx GSE    "; "Ion Vy GSE    "; "Ion Vz GSE    ";;]
    @test ds isa CDFDataset
end

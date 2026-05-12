using CDFDatasets
using CDFDatasets: var_type, cdf_type
using Test
import CDFDatasets as CDF
import CDFDatasets.CommonDataModel as CDM
import CDFDatasets.DiskArrays
using Dates
using DimensionalData
using Chairmarks

include("utils.jl")

@testset "Aqua" begin
    using Aqua
    Aqua.test_all(CDFDatasets)
end

const RUN_JET_TESTS = isempty(VERSION.prerelease)

@testset "JET static analysis" begin
    if RUN_JET_TESTS
        using Pkg; Pkg.add("JET"); Pkg.instantiate()
        using JET
        JET.test_package(CDFDatasets; target_modules = [CDFDatasets])
    end
end


@testset "CDFDatasets.jl (cross validation with pycdfpp)" begin
    @static if VERSION >= v"1.11"
        using PyCDFpp
        using PyCDFpp: UnixTime

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

        @testset "py show" begin
            io = IOBuffer()
            show(io, MIME"text/plain"(), ds_py)
            str = String(take!(io))
            @test occursin("Support variables: Epoch", str)
        end
    end
end

@testset "CDFDataset (Edge cases)" begin
    tha_state_url = "https://github.com/JuliaSpacePhysics/CDFDatasets.jl/releases/download/v0.1.8/tha_l1_state_20100225_v03.cdf"
    ds = cdfopen(download_test_data(tha_state_url))
    @test eltype(CDM.dim(ds["tha_pos"], 2)) <: Dates.AbstractDateTime
end

@testset "Concatenated CDFVariable and DimArray" begin
    file1 = data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
    file2 = data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf")
    var1 = CDFDataset(file1)["V"]
    var2 = CDFDataset(file2)["V"]
    var = cat(var1, var2; dims = 1)
    @test var == cat(var1, var2; dims = 1)
    @test var.data isa DiskArrays.ConcatDiskArray
    @test var.data.parents[1] === parent(var1)
    @test var.data == vcat(var1.data, var2.data)
    @test DimArray(var).dims[1] == vcat(DimArray(var1).dims[1], DimArray(var2).dims[1])
    @test var.attrib == var1.attrib
    @test CDM.dimnames(var) == CDM.dimnames(var1)
end

@testset "ConcatCDFDataset" begin
    using DimensionalData

    files = [data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"), data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf")]
    ds1 = CDFDataset(files[1])
    concat_ds = cdfopen(files)

    @test CDM.varnames(concat_ds) == CDM.varnames(ds1)
    @test CDM.attribnames(concat_ds) == CDM.attribnames(ds1)
    var = concat_ds["V"]
    @test size(var) == (1464,)
    @test var.data isa DiskArrays.ConcatDiskArray
    @test CDM.variable(var, "V") == var
    @test CDF.is_record_varying(var) == true


    @testset "SubVariable" begin
        t0 = DateTime(2020, 05, 03)
        t1 = DateTime(2020, 05, 04)
        subvar = var[t0 .. t1]
        @test size(subvar) == (25,)
        @test DimArray(subvar).dims[1] ⊆ t0 .. t1
        @test (@b DimArray(subvar)).time < (@b DimArray(var)).time
    end

    @testset "Dataset view (time clip)" begin
        t0 = DateTime(2020, 05, 03)
        t1 = DateTime(2020, 05, 04)
        vds = view(concat_ds, t0 .. t1)
        @test Array(vds["Epoch"])[1] == t0
        @test vds["V"] == concat_ds["V"][t0 .. t1]
        da = DimArray(vds["V"])
        @test da.dims[1] ⊆ t0 .. t1
        @test parent(da) isa Array  # data materialized
        @test parent(dims(da)[1].val) isa Vector  # dim materialized

        str = sprint(show, MIME("text/plain"), vds)
        @test occursin("View:", str)
        @test_broken (@b DimArray($vds["V"])).time < (@b DimArray($concat_ds["V"])).time
    end

    # TODO: address memory allocation concerns for view operations
    # julia> @b Array(vds["Epoch"])
    # 2.073 μs (24 allocs: 13.656 KiB)
    # julia> @b Array(ds1["Epoch"])
    # 1.023 μs (13 allocs: 7.141 KiB)
    # julia> @b Array(vds["V"])
    # 3.990 μs (49 allocs: 15.688 KiB)
    # julia> @b Array(ds1["V"])
    # 979.167 ns (13 allocs: 4.141 KiB)
end

@testset "CDFDatasets.jl (Multidimensional, ELFIN)" begin
    elx_file = data_path("elb_l2_epdef_20210914_v01.cdf")
    ds = cdfopen(elx_file)
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

    @testset "SubVariable" begin
        t0 = DateTime("2021-09-14T16:23:44.432")
        t1 = DateTime("2021-09-14T16:27:35.676")
        var = ds["elb_pef_hs_Epat_eflux"]
        subvar = var[t0 .. t1]
        @test size(subvar) == (10, 16, 22)
        @test size(CDM.dim(subvar, 1)) == (10, 22)
        @test size(CDM.dim(subvar, 2)) == (16, 1)
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

@testset "Materialized CDFVariable array operations" begin
    within(actual, baseline; factor) = actual.time <= baseline.time * factor
    within(pair; factor) = within(pair...; factor)

    ds = CDFDataset(data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))
    disk_var = ds["V"]
    var = materialize(disk_var)
    data = parent(var)

    @test data isa Array

    @test_broken cdf_type(var) == cdf_type(disk_var)
    @test disk_var .* 2 isa DiskArrays.BroadcastDiskArray
    @test CDM.dimnames(var) == CDM.dimnames(disk_var)
    @test CDM.dimnames(var, 1) == CDM.dimnames(disk_var, 1)
    @test var[1] == data[1]
    @test sum(var) == sum(data)
    @test maximum(var) == maximum(data)
    @test copy(var) == data
    @test var .* 2 == data .* 2
    @test var .* 2 isa Array

    @testset "Performance" begin
        @test within(@b sum($var), sum($data); factor = 1.1)
        @test within(@b maximum($var), maximum($data); factor = 1.1)
        @test within(@b copy($var), copy($data); factor = 1.1)
        @test_broken within(@b $var .* 2, $data .* 2; factor = 1.1)
    end
end

@testset "CDFVariable array operation performance" begin
    ds = CDFDataset(data_path("elb_l2_epdef_20210914_v01.cdf"))
    disk_var = ds["elb_pef_hs_Epat_eflux"]
    mem_var = materialize(disk_var)

    disk_sum = @b(sum($disk_var))
    mem_sum = @b(sum($mem_var))
    @test mem_sum.time < disk_sum.time
    @test mem_sum.bytes < disk_sum.bytes
    @test mem_sum.bytes == 0

    disk_maximum = @b(maximum($disk_var))
    mem_maximum = @b(maximum($mem_var))
    @test mem_maximum.time < disk_maximum.time
    @test mem_maximum.bytes < disk_maximum.bytes
    @test mem_maximum.bytes == 0
    disk_broadcast = @b(Array($disk_var .* 2))
    mem_broadcast = @b($mem_var .* 2)
    @test mem_broadcast.bytes < disk_broadcast.bytes
end

include("test_show.jl")

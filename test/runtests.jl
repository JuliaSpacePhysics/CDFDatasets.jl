using CDFDatasets
using CDFDatasets: var_type, cdf_type
using Test
import CDFDatasets as CDF
import CDFDatasets.CommonDataModel as CDM
import CDFDatasets.DiskArrays
using Dates
using DimensionalData
using Chairmarks
import SpaceDataModel as SDM

include("utils.jl")

@testset "Aqua" begin
    using Aqua
    Aqua.test_all(CDFDatasets)
end

# JET refuses to analyze on Julia prereleases
if isempty(VERSION.prerelease)
    @testset "JET static analysis" begin
        using JET
        JET.test_package(CDFDatasets; target_modules = [CDFDatasets])
    end
end


@testset "CDFDataset (Edge cases)" begin
    tha_state_url = "https://github.com/JuliaSpacePhysics/CDFDatasets.jl/releases/download/v0.1.8/tha_l1_state_20100225_v03.cdf"
    ds = cdfopen(download_test_data(tha_state_url))
    var = ds["tha_pos"]
    tdim = CDM.dim(var, 2)
    @test tdim isa CDFVariable
    @test parent(tdim) isa DiskArrays.AbstractDiskArray  # lazy, like other coordinates
    @test eltype(tdim) <: Dates.AbstractDateTime
    @test CDFDatasets.unix2timestamp(1.267056060123e9) == DateTime(2010, 2, 25, 0, 1, 0, 123)
    # subview keeps the swapped DEPEND_TIME coordinate
    t = Array(tdim)
    subvar = var[t[10] .. t[20]]
    @test Array(CDM.dim(subvar, 2)) == t[10:20]
    @test SDM.tdimnum(var) == 2
    @test SDM.times(subvar) == t[10:20]
end

@testset "Concatenated CDFVariable and DimArray" begin
    file1 = data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
    file2 = data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf")
    var1 = CDFDataset(file1)["V"]
    var2 = CDFDataset(file2)["V"]
    var = cat(var1, var2; dims = 1)
    @test var == cat(var1, var2; dims = 1)
    @test var.data isa DiskArrays.ConcatDiskArray
    @test var.data.parents[1] === var1
    @test var.data == vcat(var1.data, var2.data)
    @test DimArray(var).dims[1] == vcat(DimArray(var1).dims[1], DimArray(var2).dims[1])
    @test var.attrib == var1.attrib
    @test CDM.dimnames(var) == CDM.dimnames(var1)
    @test SDM.times(SDM.DataVariable(var)) == vcat(SDM.times(var1), SDM.times(var2))

    # files with zero records chunk as RegularChunks(1, 0, 0)
    empty = CDFVariable(EmptyDiskVector(), "e", nothing, Dict())
    @test isempty(Array(cat(empty, empty; dims = 1)))
    padded = cat(empty, var1, empty; dims = 1)
    @test size(padded) == size(var1)
    @test isequal(padded[:], var1[:])

    # views read through the parts, across their boundary
    e = CDFDataset(data_path("elb_l2_epdef_20210914_v01.cdf"))["elb_pef_hs_Epat_eflux"]
    e2 = cat(e, e; dims = 3)
    @test isequal(Array(view(e2, 2, :, 40:50)), Array(e2)[2, :, 40:50])
end

@testset "Multi-file CDFDataset" begin
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
        # reads only the clipped records (timing at this size measures fixed overhead)
        @test (@b DimArray(subvar)).bytes < (@b DimArray(var)).bytes
    end

    @testset "Dataset view (time clip)" begin
        t0 = DateTime(2020, 05, 03)
        t1 = DateTime(2020, 05, 04)
        vds = view(concat_ds, t0 .. t1)
        @test Array(vds["Epoch"])[1] == t0
        @test Array(vds["V"]) == Array(concat_ds["V"][t0 .. t1])
        da = DimArray(vds["V"])
        @test da.dims[1] ⊆ t0 .. t1
        @test parent(da) isa Array  # data materialized
        @test parent(dims(da)[1].val) isa Vector  # dim materialized

        str = sprint(show, MIME("text/plain"), vds)
        @test occursin("View:", str)
        @test (@b DimArray($vds["V"])).time > 0

        # indices bisected once per epoch, shared by all variables on it
        @test keys(vds.indices) == Set(["Epoch"])
        vds["BR"]
        @test length(vds.indices) == 1
        # nested views intersect rather than replace
        nested = view(view(concat_ds, t0 .. DateTime(2020, 06, 01)), DateTime(2020, 04, 01) .. t1)
        @test nested.interval == t0 .. t1
        @test Array(nested["V"]) == Array(vds["V"])
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
        @test CDF.data_version(ds) == v"1"
        @test CDM.name(ds) == "elb_l2_epdef"

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

        @test depend(ds["elb_pef_hs_time"], 1) === nothing
        @test CDM.dim(ds["elb_pef_hs_time"], 1) == axes(ds["elb_pef_hs_time"], 1)
        @test CDM.dimnames(ds["elb_pef_hs_time"]) == (nothing,)

        @test ndims(ds["elb_pef_hs_epa_spec"]) == 2
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 2) == ds["elb_pef_hs_time"]
        @test CDM.dim(ds["elb_pef_hs_epa_spec"], 1) == ds["elb_pef_energies_mean"]

        @test ndims(ds["elb_pef_hs_Epat_eflux"]) == 3
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 3) == ds["elb_pef_hs_time"]
        @test isequal(CDM.dim(ds["elb_pef_hs_Epat_eflux"], 1), ds["elb_pef_hs_epa_spec"])
        @test CDM.dim(ds["elb_pef_hs_Epat_eflux"], 2) == ds["elb_pef_energies_mean"]
        @test is_record_varying(ds["elb_pef_hs_Epat_eflux"]) == true
        @test is_record_varying(ds["elb_pef_hs_epa_spec"]) == true
        @test is_record_varying(ds["elb_pef_energies_mean"]) == false
        @test var_type(ds["elb_pef_hs_Epat_eflux"]) == "data"
    end

    @testset "SubVariable" begin
        t0 = DateTime("2021-09-14T16:23:44")
        t1 = DateTime("2021-09-14T16:27:36")
        var = ds["elb_pef_hs_Epat_eflux"]
        subvar = var[t0 .. t1]
        @test size(subvar) == (10, 16, 22)
        @test size(CDM.dim(subvar, 1)) == (10, 22)
        @test size(CDM.dim(subvar, 2)) == (16, 1)
    end

    @testset "decoding on read" begin
        # FILLVAL is NaN here, so only the VALIDMAX range check can change anything
        var = ds["elb_pef_hs_Epat_eflux"]
        A = Array(parent(var))
        S = Array(var)
        @test all(isnan.(S) .== (isnan.(A) .| (A .> only(var.attrib["VALIDMAX"]))))
        @test isequal(var[2:3, :, 5:6], S[2:3, :, 5:6])

        # Int8 with Int16 FILLVAL; no fill values in this file, but sector numbers fall
        # outside VALIDMIN/VALIDMAX = [0, 32]
        ivar = ds["elb_pef_sectnum"]
        I = Array(parent(ivar))
        bad = (I .< 0) .| (I .> 32)
        @test any(bad) && !all(bad)
        F = Array(ivar)
        @test F isa Vector{Float32}
        @test isnan.(F) == bad
        @test F[.!bad] == I[.!bad]
        @test eltype(variable(ds, "elb_pef_sectnum"; fillval = nothing, validmin = nothing, validmax = nothing)) == Int8
        # integer support_data (a status code) keeps stored values unless checks are given
        po = cdfopen(data_path("po_h1_tim_00000000_v01.cdf"))
        @test eltype(po["Quality"]) == UInt8
        @test eltype(variable(po, "Quality"; validmax = 0)) == Float32

        # per-component VALIDMIN/VALIDMAX along dim 1, also for a block of components
        A = Float32[1 5 9; 2 6 10; 3 7 11]
        md = Dict("VALIDMIN" => [1, 6, 11], "VALIDMAX" => [1, 6, 11])
        expected = Bool[0 1 1; 1 0 1; 1 1 0]
        @test isnan.(Array(CDF.CDFVariable(A, "v", nothing, md))) == expected
        lazy = CDF.CDFVariable(view(A, :, :), "v", nothing, md)
        @test isnan.(lazy[2:3, :]) == expected[2:3, :]
        decoded = Array(lazy)
        @test isequal(Array(view(lazy, 2:3, :)), decoded[2:3, :])
        @test isequal(Array(view(view(lazy, 2:3, :), 2:2, :)), decoded[3:3, :])
        @test isequal(Array(selectdim(lazy, 1, 2)), decoded[2, :])
        @test isequal(Array(view(lazy, :)), vec(decoded))
        @test isequal(Array(reshape(lazy, (1, 9))), reshape(decoded, 1, 9))
        @test isequal(Array(cat(lazy, lazy; dims = 1)), vcat(decoded, decoded))
        # bounds whose length matches no dimension: equal values act as one, others are dropped
        scalar = CDF.CDFVariable(view(Float32[1, -7.0e4], :), "s", nothing, Dict("VALIDMIN" => [-6.0e4, -6.0e4, -6.0e4]))
        @test isnan.(Array(scalar)) == [false, true]
        garbage = CDF.CDFVariable(view(Float32[1, 2.0e7], :), "g", nothing, Dict("VALIDMAX" => [1.0e7, 7.0e22, 7.0e-13]))
        @test !any(isnan, Array(garbage))
        precise = 1.0 + 2.0^-40
        mixedtypes = CDF.CDFVariable(CDF._concat((Float32[1], [precise]), 1), "mixed", nothing, Dict("FILLVAL" => -999))
        @test Array(mixedtypes) == [1.0, precise]

        # dataset-wide checks reach variables, their coordinates and views; call keywords override them
        unbounded = cdfopen(elx_file; checks = (; validmin = nothing, validmax = nothing))
        stored = Array(parent(ds["elb_pef_hs_Epat_eflux"]))
        @test isequal(Array(unbounded["elb_pef_hs_Epat_eflux"]), stored)
        @test isequal(Array(variable(unbounded, "elb_pef_hs_Epat_eflux"; validmax = 1.0f6)), Array(ds["elb_pef_hs_Epat_eflux"]))
        @test isequal(Array(CDM.dim(unbounded["elb_pef_hs_Epat_eflux"], 1)), Array(parent(ds["elb_pef_hs_epa_spec"])))
        t0, t1 = DateTime("2021-09-14T16:23:44"), DateTime("2021-09-14T16:27:36")
        clipped = view(unbounded, t0 .. t1)["elb_pef_hs_Epat_eflux"]
        @test isequal(Array(clipped), Array(parent(view(ds, t0 .. t1)["elb_pef_hs_Epat_eflux"])))
        @test_throws ArgumentError cdfopen(elx_file; checks = (; valid_max = nothing))

        raw = variable(ds, "elb_pef_sectnum"; fillval = nothing, validmin = nothing, validmax = nothing)
        mixed = cat(raw, ivar; dims = 1)
        @test isequal(Array(mixed), vcat(Array(raw), Array(ivar)))
        @test isequal(mixed[2:end-1], Array(mixed)[2:end-1])
    end

end


@testset "SpaceDataModel time series interface" begin
    ds = cdfopen(data_path("elb_l2_epdef_20210914_v01.cdf"))
    var = ds["elb_pef_hs_Epat_eflux"]
    t = SDM.times(var)
    @test SDM.tdimnum(var) == 3
    @test t == Array(ds["elb_pef_hs_time"])
    @test isnothing(SDM.tdimnum(cdfopen(data_path("po_h1_tim_00000000_v01.cdf"))["Quality"]))

    # time-varying DEPEND_1 kept whole; non-record-varying DEPEND_2 drops its record dimension
    @test size(SDM.dims(var, 1)) == (10, 44)
    energies = SDM.dims(var, 2)
    @test energies == vec(Array(ds["elb_pef_energies_mean"]))
    @test SDM.getmeta(energies, "UNITS") == "keV"
    @test SDM.ISTPSchema()(ds["elb_pef_Et_eflux"])[:depend_1_unit] == "keV"
    # DEPEND_1 lists 16 energies for 10 pitch-angle bins
    @test isnothing(SDM.dims(ds["elb_pef_hs_epa_spec"], 1))
    @test lookup(DimArray(ds["elb_pef_hs_epa_spec"]), 1) isa DimensionalData.NoLookup

    t0, t1 = DateTime("2021-09-14T16:23:44.432"), DateTime("2021-09-14T16:27:35.676")
    sub = var[t0 .. t1]
    idx = findall(in(t0 .. t1), t)
    @test SDM.times(sub) == t[idx]
    @test SDM.unwrap(SDM.dims(sub, 1)) == SDM.unwrap(SDM.dims(var, 1))[:, idx]

    # integer indices drop dimensions, so view dimension i maps to a later stored DEPEND_i/LABL_PTR_i; coordinates are sliced like the data
    v = view(var, 2:3, 5, 1:10)
    @test SDM.tdimnum(v) == 2 && SDM.times(v) == t[1:10]
    @test SDM.unwrap(SDM.dims(v, 1)) == SDM.unwrap(SDM.dims(var, 1))[2:3, 1:10]
    v = view(var, :, 3:4, 7)
    @test isnothing(SDM.tdimnum(v))
    @test SDM.unwrap(SDM.dims(v, 1)) == SDM.unwrap(SDM.dims(var, 1))[:, 7]
    @test SDM.unwrap(SDM.dims(v, 2)) == energies[3:4]
    nflux = ds["elb_pef_Et_nflux"]
    @test SDM.times(SDM.DataVariable(view(nflux, 4, :))) == SDM.times(nflux)

    @test !SDM.hastimedim(ds["elb_pef_energies_mean"])  # non-record-varying
    @test !SDM.hastimedim(ds["elb_pef_hs_time"])

    dv = SDM.DataVariable(var)
    # rebuilds that drop or replace the time axis keep the other coordinates
    for r in (SDM.rebuild(var, zeros(10, 16), (Val(1), Val(2))), SDM.rebuild(var, zeros(10, 16, 2), 3, t[1:2]))
        @test SDM.unwrap(SDM.dims(r, 2)) == energies
    end
    @test SDM.times(SDM.rebuild(var, zeros(10, 16, 2), 3, t[1:2])) == t[1:2]
    @test SDM.getmeta(SDM.dims(dv[:, 3:4, :], 2), "UNITS") == "keV"

    # LABL_PTR_1 of a dimension with a DEPEND_1 is a coordinate, which follows slicing
    vc = cdfopen(data_path("ge_h0_cpi_00000000_v01.cdf"))["SW_Vc"]
    @test SDM.ISTPSchema()(SDM.DataVariable(vc)[2:3, :], :labels) == ["Ion Vy GSE", "Ion Vz GSE"]  # the labels LABL_PTR_1 names
    flux = SDM.DataVariable(cdfopen(data_path("labl_ptr.cdf"))["flux"])  # record-varying DEPEND_1
    @test SDM.dims(flux[2:3, 2:2], 1) == [4.0; 5.0;;]
    @test SDM.ISTPSchema()(flux[2:3, :], :labels) == ["By", "Bz"]
    se = cdfopen(data_path("labl_ptr.cdf"))["self_epoch"]
    @test SDM.times(SDM.DataVariable(se)) == Array(se)
end

@testset "LABL_PTR labels" begin
    labels(x) = SDM.ISTPSchema()(x, :labels)
    ds = cdfopen(data_path("labl_ptr.cdf"))
    @test labels(ds["ok"]) == ["Bx", "By", "Bz"]
    @test isnothing(SDM.dims(ds["ok"], 1))  # labels are not values
    @test labels(SDM.DataVariable(ds["ok"])[2:3, :]) == ["By", "Bz"]
    @test labels(view(ds["ok"], 2:3, :)) == ["By", "Bz"]
    @test labels(view(ds["ok"], :, 2)) == ["Bx", "By", "Bz"]
    @test isnothing(labels(ds["dangling"]))
    @test labels(DimArray(ds["ok"])[X = 2:3]) == ["By", "Bz"]
    @test labels(cdfopen(data_path("ge_h0_cpi_00000000_v01.cdf"))["SW_V"]) ==
        ["Ion Bulk Speed", "Ion Bulk Polar Angle", "Ion Bulk Azimuth Angle"]
end

@testset "DEPEND from metadata" begin
    ds = cdfopen(data_path("labl_ptr.cdf"))
    @test CDM.dimnames(CDM.variable(ds, "flux"; metadata = Dict("DEPEND_1" => "labels")), 1) == "labels"
    @test isnothing(SDM.dims(CDM.variable(ds, "flux"; metadata = Dict("DEPEND_1" => "flux_energy")), 1))
end

@testset "Attributes from a master" begin
    file, master = data_path("labl_ptr.cdf"), data_path("labl_ptr_master.cdf")
    t0, t1 = DateTime(2020, 1, 1, 0, 1), DateTime(2020, 1, 2)
    # `ok` has no DEPEND_0 nor FILLVAL, as in Wind 3DP files whose masters alone carry them
    @test size(cdfopen(file, t0, t1)["ok"]) == (3, 2)
    @test_throws ArgumentError cdfopen(file)["ok"][t0 .. t1]
    # nor with a DEPEND_0 of other than times (ICON's `Epoch` holds integer milliseconds)
    ok = cdfopen(file, t0, t1; master)["ok"]
    @test size(ok) == (3, 1)
    @test all(isnan, Array(ok))

    @test Array(SDM.dims(cdfopen(file; master)["flux"], 1)) == [10, 20, 30]
    @test SDM.ISTPSchema()(cdfopen(file; master)["ok"], :labels) == ["Ex", "Ey", "Ez"]
    @test "energy_vals" in keys(cdfopen(file; master))
    @test cdfopen(file; master).attrib["Logical_source"] == ["labl_ptr"]
    ge = data_path("ge_h0_cpi_00000000_v01.cdf")
    @test cdfopen(ge; master).attrib["Logical_source"] == cdfopen(ge).attrib["Logical_source"] != ["labl_ptr"]
end

@testset "Fewer records than the time coordinate" begin
    ds = cdfopen(data_path("labl_ptr.cdf"), DateTime(2020), DateTime(2021))
    @test size(ds["unwritten"]) == (0,)
    @test size(ds["unwritten_epoch"]) == (0,)
    @test size(ds["unwritten_swapped"]) == (0,)
end

@testset "CDFDataset" begin
    test_file = joinpath(@__DIR__, "..", "data", "ge_h0_cpi_00000000_v01.cdf")
    ds = CDFDataset(test_file)
    @test ds["label_v3c"].data == ["Ion Vx GSE    "; "Ion Vy GSE    "; "Ion Vz GSE    ";;]
    @test ds isa CDFDataset
end

@testset "Array operations" begin
    var = CDFDataset(data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))["V"]
    @test var .* 2 isa DiskArrays.BroadcastDiskArray
    @test convert(Vector, var) == Array(var)  # copyto! must not bounce between DiskArrays and broadcast
end

include("test_show.jl")

@testset "find_indices" begin
    t = DateTime(2020, 1, 1) .+ Hour.(0:9)
    @test CDFDatasets.find_indices(t, t[2] .. t[4]) == 2:4
    @test CDFDatasets.find_indices(t, CDFDatasets.Interval{:open, :open}(t[2], t[4])) == 3:3
    @test CDFDatasets.find_indices(reverse(t), t[2] .. t[4]) == (length(t) - 3):(length(t) - 1)
    tj = [t[1], t[3], t[2], t[4], t[5]]
    @test CDFDatasets.find_indices(tj, t[2] .. t[3]) == 2:3
    @test CDFDatasets.find_indices(tj, t[3] .. t[4]) == [2, 4]
    @test CDFDatasets.find_indices(tj, t[6] .. t[7]) === 1:0
    @test CDFDatasets.find_indices(tj, CDFDatasets.Interval{:open, :open}(t[2], t[4])) == 2:2
end

@testset "Unsorted dataset interval" begin
    ds = CDFDataset(data_path.([
        "omni_coho1hr_merged_mag_plasma_20200601_v01.cdf",
        "omni_coho1hr_merged_mag_plasma_20200501_v01.cdf",
    ]))
    interval = DateTime(2020, 5, 31) .. DateTime(2020, 6, 2)
    epochs = Array(ds["Epoch"])
    indices = findall(in(interval), epochs)
    @test length(indices) < last(indices) - first(indices) + 1
    clipped = view(ds, interval)
    @test Array(clipped["V"]) == Array(ds["V"])[indices]
    @test Array(clipped["Epoch"]) == epochs[indices]
    @test Array(CDFDatasets.depend(clipped["V"], 1)) == epochs[indices]
end

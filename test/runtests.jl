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

@testset "JET static analysis" begin
    using JET
    JET.test_package(CDFDatasets; target_modules = [CDFDatasets])
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
        @test isequal(Array(ds["V"]), Array(ds_py["V"]))
        @test get(ds_py["V"].metadata, "absent", nothing) === nothing

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
    var = ds["tha_pos"]
    tdim = CDM.dim(var, 2)
    @test tdim isa CDFVariable
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

    # files with zero records chunk as RegularChunks(1, 0, 0)
    empty = CDFVariable(EmptyDiskVector(), "e", nothing, Dict())
    @test isempty(Array(cat(empty, empty; dims = 1)))
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
        @test isequal(materialize(var).data, S)

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
    @test SDM.tdimnum(materialize(var)) == 3
    @test isnothing(SDM.tdimnum(cdfopen(data_path("po_h1_tim_00000000_v01.cdf"))["Quality"]))

    # time-varying DEPEND_1 kept whole; non-record-varying DEPEND_2 drops its record dimension
    @test size(SDM.dims(var, 1)) == (10, 44)
    energies = SDM.dims(var, 2)
    @test energies == vec(Array(ds["elb_pef_energies_mean"]))
    @test SDM.getmeta(energies, "UNITS") == "keV"
    @test SDM.ISTPSchema()(ds["elb_pef_Et_eflux"])[:depend_1_unit] == "keV"
    # DEPEND_1 lists 16 energies for 10 pitch-angle bins
    @test SDM.dims(ds["elb_pef_hs_epa_spec"], 1) == 1:10

    t0, t1 = DateTime("2021-09-14T16:23:44.432"), DateTime("2021-09-14T16:27:35.676")
    sub = var[t0 .. t1]
    idx = findall(in(t0 .. t1), t)
    @test SDM.times(sub) == t[idx]
    @test SDM.unwrap(SDM.dims(sub, 1)) == SDM.unwrap(SDM.dims(var, 1))[:, idx]

    @test !SDM.hastimedim(ds["elb_pef_energies_mean"])  # non-record-varying
    @test !SDM.hastimedim(ds["elb_pef_hs_time"])
end

@testset "CDFDataset" begin
    test_file = joinpath(@__DIR__, "..", "data", "ge_h0_cpi_00000000_v01.cdf")
    ds = CDFDataset(test_file)
    @test ds["label_v3c"].data == ["Ion Vx GSE    "; "Ion Vy GSE    "; "Ion Vz GSE    ";;]
    @test ds isa CDFDataset
end

@testset "Materialized CDFVariable array operations" begin
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
    @test convert(Vector, var) == data  # copyto! must not bounce between DiskArrays and broadcast
    @test var .* 2 == data .* 2
    @test var .* 2 isa Array

    @testset "Zero-overhead forwarding" begin
        time_ratio(pair) = pair[1].time / pair[2].time
        @test (@b sum($var)).bytes == 0
        @test (@b maximum($var)).bytes == 0
        # Broadcast reads elementwise through the wrapper instead of its parent.
        @test_broken time_ratio(@b ($var .* 2, $data .* 2)) < 1.2
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

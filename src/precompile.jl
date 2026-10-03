# Multi-file opens mirror CDAWeb's `cdfopen(::Vector{String})` + interval view path;
# the ELFIN file adds TT2000-indexed 2-D variables, single- and multi-file.
PrecompileTools.@setup_workload begin
    data = joinpath(@__DIR__, "..", "data")
    omni = [joinpath(data, "omni_coho1hr_merged_mag_plasma_2020$(m)01_v01.cdf") for m in ("05", "06")]
    elb = joinpath(data, "elb_l2_epdef_20210914_v01.cdf")

    PrecompileTools.@compile_workload begin
        ds = cdfopen(omni)
        for name in ("BR", "Epoch")
            var = ds[name]
            var[:]
            Array(var)
        end
        view(ds, DateTime(2020, 5, 2) .. DateTime(2020, 6, 3))["BR"][:]

        for ds in (cdfopen(elb), cdfopen([elb, elb]))
            ds["elb_pef_Et_nflux"][:, :]
            ds["elb_pef_pa"][:]  # 1-D Float32
            ds["elb_pef_sectnum"][:]  # Int8 decoded to Float32
            ds["elb_pef_hs_Epat_eflux"][:, :, :]  # energy × pitch angle × time
            view(ds, DateTime(2021, 9, 14) .. DateTime(2021, 9, 15))["elb_pef_Et_nflux"][:, :]
        end
    end
end

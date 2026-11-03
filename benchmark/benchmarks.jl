using BenchmarkTools
using CDFDatasets
using Dates
using DimensionalData
using CDFDatasets: SDM

const SUITE = BenchmarkGroup()

const DATA_DIR = joinpath(dirname(@__DIR__), "data")
data_path(file) = joinpath(DATA_DIR, file)

const OMNI_FILES = [
    data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"),
    data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf"),
]
const ELFIN_FILE = data_path("elb_l2_epdef_20210914_v01.cdf")

const OMNI = cdfopen(OMNI_FILES[1])
const OMNI_MULTI = cdfopen(OMNI_FILES)
const ELFIN = cdfopen(ELFIN_FILE)

const OMNI_V = OMNI["V"]
const OMNI_MULTI_V = OMNI_MULTI["V"]

const ELFIN_FLUX = ELFIN["elb_pef_hs_Epat_eflux"]

const CLIP = DateTime(2020, 5, 3) .. DateTime(2020, 5, 4)
const OMNI_MULTI_VIEW = view(OMNI_MULTI, CLIP)

let g = SUITE["variable"], dv = SDM.DataVariable(ELFIN_FLUX)
    g["disk"]["sum"] = @benchmarkable sum($ELFIN_FLUX)
    g["disk"]["maximum"] = @benchmarkable maximum($ELFIN_FLUX)
    g["disk"]["broadcast-realized"] = @benchmarkable Array($ELFIN_FLUX .* 2)

    g["in-memory"]["sum"] = @benchmarkable sum($dv)
    g["in-memory"]["maximum"] = @benchmarkable maximum($dv)
    g["in-memory"]["broadcast"] = @benchmarkable $dv .* 2

    g["DataVariable"]["omni-v"] = @benchmarkable SDM.DataVariable($OMNI_V)
    g["DataVariable"]["elfin-flux"] = @benchmarkable SDM.DataVariable($ELFIN_FLUX)
end

let g = SUITE["decode"], sectnum = ELFIN["elb_pef_sectnum"]  # Int8, promoted to Float32
    g["float-3d"] = @benchmarkable Array($ELFIN_FLUX)
    g["float-3d-raw"] = @benchmarkable Array(parent($ELFIN_FLUX))
    g["int8"] = @benchmarkable Array($sectnum)
    g["omni-v"] = @benchmarkable Array($OMNI_V)

    g["lookup"]["float-3d"] = @benchmarkable Array($ELFIN["elb_pef_hs_Epat_eflux"])
    g["lookup"]["int8"] = @benchmarkable Array($ELFIN["elb_pef_sectnum"])
    g["lookup"]["omni-v"] = @benchmarkable Array($OMNI["V"])
    g["lookup"]["concat"] = @benchmarkable Array($OMNI_MULTI["V"])
end

let g = SUITE["concat"], cat_v = cat(OMNI_V, cdfopen(OMNI_FILES[2])["V"]; dims = 1)  # parts mask themselves
    g["variable"]["construct"] = @benchmarkable cat($OMNI_V, $OMNI["V"]; dims = 1)
    g["variable"]["array"] = @benchmarkable Array($OMNI_MULTI_V)
    g["variable"]["cat-array"] = @benchmarkable Array($cat_v)
    g["dataset"]["variable"] = @benchmarkable $OMNI_MULTI["V"]
    g["dataset"]["epoch"] = @benchmarkable $OMNI_MULTI["Epoch"]
end

let g = SUITE["clip"]
    g["variable"] = @benchmarkable $OMNI_MULTI_V[$CLIP]
    g["dataset-variable"] = @benchmarkable $OMNI_MULTI_VIEW["V"]
    g["dataset-epoch"] = @benchmarkable Array($OMNI_MULTI_VIEW["Epoch"])
end

let g = SUITE["dimarray"]
    g["single"] = @benchmarkable DimArray($OMNI_V)
    g["concat"] = @benchmarkable DimArray($OMNI_MULTI_V)
    g["clip"] = @benchmarkable DimArray($OMNI_MULTI_VIEW["V"])
end

let g = SUITE["metadata"]
    g["depend"] = @benchmarkable CDFDatasets.depend($OMNI_MULTI_V, 1)
    g["dataset"] = @benchmarkable CDFDatasets.dataset($OMNI_MULTI_V)
end

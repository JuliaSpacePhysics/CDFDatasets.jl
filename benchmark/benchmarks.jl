using BenchmarkTools
using CDFDatasets
using CommonDataModel
using Dates
using DimensionalData

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
const OMNI_V_MATERIALIZED = materialize(OMNI_V)
const OMNI_MULTI_V = OMNI_MULTI["V"]

const ELFIN_FLUX = ELFIN["elb_pef_hs_Epat_eflux"]
const ELFIN_FLUX_MATERIALIZED = materialize(ELFIN_FLUX)

const CLIP = DateTime(2020, 5, 3) .. DateTime(2020, 5, 4)
const OMNI_MULTI_VIEW = view(OMNI_MULTI, CLIP)

SUITE["variable"]["disk"]["sum"] = @benchmarkable sum($ELFIN_FLUX)
SUITE["variable"]["disk"]["maximum"] = @benchmarkable maximum($ELFIN_FLUX)
SUITE["variable"]["disk"]["broadcast-realized"] = @benchmarkable Array($ELFIN_FLUX .* 2)

SUITE["variable"]["materialized"]["sum"] = @benchmarkable sum($ELFIN_FLUX_MATERIALIZED)
SUITE["variable"]["materialized"]["maximum"] = @benchmarkable maximum($ELFIN_FLUX_MATERIALIZED)
SUITE["variable"]["materialized"]["broadcast"] = @benchmarkable $ELFIN_FLUX_MATERIALIZED .* 2

SUITE["variable"]["materialize"]["omni-v"] = @benchmarkable materialize($OMNI_V)
SUITE["variable"]["materialize"]["elfin-flux"] = @benchmarkable materialize($ELFIN_FLUX)

SUITE["concat"]["variable"]["construct"] = @benchmarkable cat($OMNI_V, $OMNI["V"]; dims = 1)
SUITE["concat"]["variable"]["array"] = @benchmarkable Array($OMNI_MULTI_V)
SUITE["concat"]["dataset"]["variable"] = @benchmarkable $OMNI_MULTI["V"]
SUITE["concat"]["dataset"]["epoch"] = @benchmarkable $OMNI_MULTI["Epoch"]

SUITE["clip"]["variable"] = @benchmarkable $OMNI_MULTI_V[$CLIP]
SUITE["clip"]["dataset-variable"] = @benchmarkable $OMNI_MULTI_VIEW["V"]
SUITE["clip"]["dataset-epoch"] = @benchmarkable Array($OMNI_MULTI_VIEW["Epoch"])

SUITE["dimarray"]["single"] = @benchmarkable DimArray($OMNI_V)
SUITE["dimarray"]["concat"] = @benchmarkable DimArray($OMNI_MULTI_V)
SUITE["dimarray"]["clip"] = @benchmarkable DimArray($OMNI_MULTI_VIEW["V"])

SUITE["metadata"]["dim"] = @benchmarkable CommonDataModel.dim($OMNI_MULTI_V, 1)
SUITE["metadata"]["dataset"] = @benchmarkable CommonDataModel.dataset($OMNI_MULTI_V)

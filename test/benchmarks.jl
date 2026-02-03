using CDFDatasets
import CDFDatasets.CommonDataModel as CDM
using Dates
using DimensionalData
using Chairmarks

include("utils.jl")

# Setup
files = [
    data_path("omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"),
    data_path("omni_coho1hr_merged_mag_plasma_20200601_v01.cdf"),
]
ds1 = CDFDataset(files[1])
concat_ds = cdfopen(files)

t0 = DateTime(2020, 05, 03)
t1 = DateTime(2020, 05, 04)

var = concat_ds["V"]
subvar = var[t0 .. t1]
vds = view(concat_ds, t0 .. t1)

# DimArray creation benchmarks
@info "full ConcatCDFVariable" (@b DimArray($var))
@info "SubVariable (time-clipped)" @b DimArray($subvar)

@info "from CDFDataset" @b DimArray($concat_ds["V"])
@info "from ClippedCDFDataset view" @b DimArray($vds["V"])
@info "from CDFDataset view" @b DimArray($concat_ds["V"][t0 .. t1])

# Array materialization
@info @b Array($concat_ds["Epoch"])
@info @b Array($vds["Epoch"])

# Dimension access
@info @b CDM.dim($var, 1)
@info @b CDM.dim($subvar, 1)

# Dataset reconstruction
@info @b CDM.dataset($var)

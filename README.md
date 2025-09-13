# CDFDatasets

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaspacephysics.github.io/CDFDatasets.jl/dev/)
[![Build Status](https://github.com/JuliaSpacePhysics/CDFDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSpacePhysics/CDFDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl)


CDFDatasets.jl is a julia package to read [CDF](https://cdf.gsfc.nasa.gov/) datasets based on the C++ implementation [CDFpp](https://github.com/SciQLop/CDFpp) using the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface.

## Quick Example

```julia
using CDFDatasets

# Open a CDF file
ds = CDFDataset("omni_coho1hr_merged_mag_plasma_20250901_v01.cdf")

# Access variables and their data
times = ds["Epoch"][:]  # Automatic TT2000 to DateTime conversion
bx = ds["BX_GSE"][:]    # Solar wind magnetic field X component

# Access metadata
println("BX units: ", ds["BX_GSE"].attrib["UNITS"])

# Work with the data
println("Data spans from $(times[1]) to $(times[end])")
close(ds)
```
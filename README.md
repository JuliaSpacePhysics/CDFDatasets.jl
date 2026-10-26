# CDFDatasets.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDFDatasets.jl/dev/)
[![DOI](https://zenodo.org/badge/1056209910.svg)](https://doi.org/10.5281/zenodo.17517175)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl)

A julia package to read [Common Data Format (CDF)](https://cdf.gsfc.nasa.gov/) datasets compatible with the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface.


## Quick Start

```julia
using Pkg; Pkg.add("CDFDatasets")
using CDFDatasets

ds = cdfopen("data/omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
times = ds["Epoch"]
bx = ds["BR"]
ds = cdfopen(files, t0, t1)  # files concatenated along records; record-varying variables restricted to [t0, t1)
```

## Missing values

Reads return `NaN` for values equal to `FILLVAL` or outside `VALIDMIN`/`VALIDMAX` (per component), so masked integer variables read as floats; integer `support_data`/`metadata` variables (flags, status codes) read as stored.

```julia
var = ds["BR"]                                                      # lazy: nothing read yet
Array(var)                                                          # reads and decodes; `var[i]` reads part
parent(var)                                                         # stored on-disk data, undecoded
variable(ds, "BR"; validmax = nothing)                              # one variable: override `fillval`/`validmin`/`validmax`; `nothing` disables
cdfopen(file; checks = (; validmin = nothing, validmax = nothing))  # every variable, its coordinates and views (e.g. placeholder bounds)
cdfopen(file; master = path)                                        # master CDF's variable attributes and non-record-varying variables override the file's; its global attributes fill the file's gaps
```

## Time series

`CDFVariable`s implement the [SpaceDataModel](https://github.com/JuliaSpacePhysics/SpaceDataModel.jl) / [TimeseriesUtilities](https://github.com/JuliaSpacePhysics/TimeseriesUtilities.jl) container interface: `times(var)`, `dims(var, i)` (the `DEPEND_i` coordinate, a lazy `CDFVariable` with its attributes), and operations such as `tmean(var, Minute(5)) :: DataVariable`.

- `DataVariable(var)` reads it into memory whose indexing keeps the time dimension, sliced coordinates and attributes; `DataVariable(view(var, :, 1:10))` reads part.
- `LABL_PTR_i` labels, trailing space padding stripped, are a further coordinate along dimension `i` (`SpaceDataModel.coords`); `var.attrib["LABL_PTR_i"]` is the stored name of the labels variable. `DimArray(var)` takes labels as the lookup of a dimension without `DEPEND_i`.

## Features

It provides a high-level interface with features:

- Concatenation of multiple CDF files;
- Integration with [`DimensionalData.jl`](https://github.com/rafaqz/DimensionalData.jl).


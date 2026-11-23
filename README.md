# CDFDatasets.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDFDatasets.jl/dev/)
[![DOI](https://zenodo.org/badge/1056209910.svg)](https://doi.org/10.5281/zenodo.17517175)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl)

A julia package to read [Common Data Format (CDF)](https://cdf.gsfc.nasa.gov/) datasets.


## Quick Start

```julia
using Pkg; Pkg.add("CDFDatasets")
using CDFDatasets

ds = cdfopen(joinpath(pkgdir(CDFDatasets), "data/omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))
times = ds["Epoch"]
br = ds["BR"]
```

`keys(ds)` lists variables; `ds.attrib` and `var.attrib` are attribute dictionaries; `depend(var, i)` is the `DEPEND_i` coordinate variable, or `nothing`.

`cdfopen(files)` lazily concatenates records in file order. `cdfopen(files, t0, t1)` clips variables with a time coordinate to `[t0, t1)`.

## Missing values

Reads return `NaN` for values equal to `FILLVAL`, so integer `data` variables with a `FILLVAL` read as floats; integer `support_data`/`metadata` (flags, status codes) read as stored. `VALIDMIN`/`VALIDMAX` (per component) are opt-in.

```julia
var = ds["BR"]                                                      # lazy: nothing read yet
Array(var)                                                          # reads and decodes; `var[i]` and `copyto!(view(buf, :, 1:10), view(var, :, 11:20))` reads part
parent(var)                                                         # stored on-disk data, undecoded
variable(ds, "BR"; validmin = true, validmax = 100)                 # `true` uses the attribute, `nothing` disables, a value overrides it
cdfopen(file; checks = (; validmin = true, validmax = true))        # dataset-wide `variable` keywords
cdfopen(file; master = path)                                        # master CDF's variable attributes and non-record-varying variables override the file's; its global attributes fill the file's gaps
cdfopen(file; varattrib = Dict(name => Dict("FILLVAL" => nothing)))  # skip fill masking for this variable
```

## Time series

`CDFVariable`s implement the [SpaceDataModel](https://github.com/JuliaSpacePhysics/SpaceDataModel.jl) / [TimeseriesUtilities](https://github.com/JuliaSpacePhysics/TimeseriesUtilities.jl) container interface: `times(var)`, `dims(var, i)` (the `DEPEND_i` coordinate, a lazy `CDFVariable` with its attributes), and operations such as `tmean(var, Minute(5)) :: DataVariable`.

- `DataVariable(var)` reads it into memory whose indexing keeps the time dimension, sliced coordinates and attributes; `DataVariable(view(var, :, 1:10))` reads part.
- `LABL_PTR_i` labels, trailing space padding stripped, are a further coordinate along dimension `i` (`SpaceDataModel.coords`); `var.attrib["LABL_PTR_i"]` is the stored name of the labels variable. [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl) uses these labels in `DimArray(var)` as the lookup of a dimension without `DEPEND_i`.

# CDFDatasets.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDFDatasets.jl/dev/)
[![DOI](https://zenodo.org/badge/1056209910.svg)](https://doi.org/10.5281/zenodo.17517175)

A julia package to read [Common Data Format (CDF)](https://cdf.gsfc.nasa.gov/) datasets.


## Quick Start

```julia
using Pkg; Pkg.add("CDFDatasets")
using CDFDatasets

ds = cdfopen(joinpath(pkgdir(CDFDatasets), "data/omni_coho1hr_merged_mag_plasma_20200501_v01.cdf"))
times = ds["Epoch"]
br = ds["BR"]           # lazy handle to the variable
subset = br[11:20]      # read and decode ten records into an array
values = Array(br)      # read and decode the entire variable into memory
copyto!(values, br)     # read into an existing buffer
```

`keys(ds)` lists variables; `ds.attrib` and `var.attrib` are attribute dictionaries; `depend(var, i)` is the `DEPEND_i` coordinate variable, or `nothing`.

`cdfopen(files)` lazily concatenates records in file order. `cdfopen(files, t0, t1)` clips variables with a time coordinate to `[t0, t1)`.

## Master CDFs and attribute overrides

Either keyword can be passed to `cdfopen` on its own.

```julia
ds = cdfopen(file; master = master_path,
    varattrib = Dict("BR" => Dict("CATDESC" => "Radial magnetic field")))
```

For variable attributes, `varattrib` overrides the master, which overrides the data file. The master also supplies non-record-varying values and fills missing global attributes.

## Missing values

Reads replace `FILLVAL` with `NaN`. Integer data variables with a fill value therefore read as floats. Integer flags and other `support_data` or `metadata` variables keep their stored type. `parent(br)` gives access to undecoded values.

Range checks are opt-in. Set defaults when opening the dataset or override them for one variable.

```julia
ds = cdfopen(file; checks = (; validmin = true, validmax = true))
br = variable(ds, "BR"; validmax = 100)
```

For each check, `true` uses the corresponding attribute (per component when applicable), `false` disables the check, and a number supplies an explicit value.

## Time series

`CDFVariable`s implement the [SpaceDataModel](https://github.com/JuliaSpacePhysics/SpaceDataModel.jl) / [TimeseriesUtilities](https://github.com/JuliaSpacePhysics/TimeseriesUtilities.jl) container interface: `times(var)`, `dims(var, i)` (the `DEPEND_i` coordinate, a lazy `CDFVariable` with its attributes), and operations such as `tmean(var, Minute(5)) :: DataVariable`.

- `DataVariable(var)` reads it into memory whose indexing keeps the time dimension, sliced coordinates and attributes; `DataVariable(view(var, :, 1:10))` reads part.
- `LABL_PTR_i` labels, trailing space padding stripped, are a further coordinate along dimension `i` (`SpaceDataModel.coords`); `var.attrib["LABL_PTR_i"]` is the stored name of the labels variable. [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl) uses these labels in `DimArray(var)` as the lookup of a dimension without `DEPEND_i`.

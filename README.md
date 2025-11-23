# CDFDatasets

[![DOI](https://zenodo.org/badge/1056209910.svg)](https://doi.org/10.5281/zenodo.17517175)

[![Build Status](https://github.com/JuliaSpacePhysics/CDFDatasets.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSpacePhysics/CDFDatasets.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/CDFDatasets.jl)


CDFDatasets.jl is a julia package to read [Common Data Format (CDF)](https://cdf.gsfc.nasa.gov/) datasets compatible with the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface.

**Installation**: at the Julia REPL, run `using Pkg; Pkg.add("CDFDatasets")`

**Documentation**: [![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDFDatasets.jl/dev/)

It provides a high-level interface with features:

- Concatenation of multiple CDF files;
- Multi-backend support ([`CommonDataFormat.jl`](https://github.com/JuliaSpacePhysics/CommonDataFormat.jl) and [`CDFpp` (C++)](https://github.com/SciQLop/CDFpp));
- Integration with [`DimensionalData.jl`](https://github.com/rafaqz/DimensionalData.jl).

It is recommended to use the native Julia implementation `CommonDataFormat.jl` for reading CDF files. `CDFpp` backend is mainly used for cross-validation, available in the `PyCDFpp` directory.


## Quick Example

```julia
using CDFDatasets

# Open a CDF file
ds = CDFDataset("omni_coho1hr_merged_mag_plasma_20250901_v01.cdf")
times = ds["Epoch"]
bx = ds["BR"]
```
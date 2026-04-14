# PyCDFpp

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaspacephysics.github.io/PyCDFpp.jl/dev/)
[![Build Status](https://github.com/JuliaSpacePhysics/PyCDFpp.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSpacePhysics/PyCDFpp.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/PyCDFpp.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/PyCDFpp.jl)

A Julia wrapper around `pycdfpp` based on the C++ implementation [CDFpp](https://github.com/SciQLop/CDFpp). See [CDFDatasets.jl](https://github.com/JuliaSpacePhysics/CDFDatasets.jl) for a high-level interface.


## Quick Example

```julia
using CDFDatasets

# Open a CDF file
ds = CDFDataset("omni_coho1hr_merged_mag_plasma_20250901_v01.cdf"; backend = :pycdfpp)
times = ds["Epoch"]
bx = ds["BR"]
```
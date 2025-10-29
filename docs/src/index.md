```@meta
CurrentModule = CDFDatasets
```

# CDFDatasets

CDFDatasets.jl is a Julia package for reading [CDF (Common Data Format)](https://cdf.gsfc.nasa.gov/) files, commonly used in space physics and other scientific domains. It provides a Julia interface to CDF files using the [CommonDataModel.jl](https://github.com/JuliaGeo/CommonDataModel.jl) interface. See [CDF reader benchmarks](https://juliaspacephysics.github.io/tutorials/cdf) for comparison with other CDF readers.

## Installation

```julia
using Pkg
Pkg.add("CDFDatasets")
```

## Quickstart

Here's a quick example using OMNI solar wind data:

```@example omni
using CDFDatasets

# Open a CDF dataset
omni_file = joinpath(pkgdir(CDFDatasets), "data/omni_coho1hr_merged_mag_plasma_20200501_v01.cdf")
ds = CDFDataset(omni_file)
```

Explore the dataset

```@repl omni
println("Variables: ", keys(ds))
println("Attributes: ", keys(ds.attrib))
ds.attrib["Descriptor"]
```

Access variables

```@repl omni
ds["Epoch"]
ds["Epoch"][[1,end]]
ds["BR"]
```

```@example omni
# Calculate magnetic field magnitude
br = ds["BR"]
bt = ds["BT"]
bn = ds["BN"]
b_mag = sqrt.(br.^2 + bt.^2 + bn.^2) |> collect
```

## API Reference

```@index
```

```@autodocs
Modules = [CDFDatasets]
```

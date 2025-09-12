using CDFDatasets
using Documenter

DocMeta.setdocmeta!(CDFDatasets, :DocTestSetup, :(using CDFDatasets); recursive=true)

makedocs(;
    modules=[CDFDatasets],
    authors="Beforerr <zzj956959688@gmail.com> and contributors",
    sitename="CDFDatasets.jl",
    format=Documenter.HTML(;
        canonical="https://Beforerr.github.io/CDFDatasets.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Beforerr/CDFDatasets.jl",
    devbranch="main",
)

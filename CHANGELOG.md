# Changelog

## [Unreleased]

## [0.2.0]

### Changed

- **Breaking**: Remove exported `ConcatCDFVariable`; concatenating CDF variables now returns a `CDFVariable` backed by `DiskArrays.ConcatDiskArray`.
- **Breaking**: Remove exported `ConcatCDFDataset`; multi-file datasets are represented by `CDFDataset` with multiple sources.
- **Breaking**: Remove internal `ClippedCDFDataset`; dataset views are represented by `CDFDataset` with an interval.
- **Breaking**: `CDFVariable` type parameters are now ordered as `{T, N, A, S, P, MD}` so storage type `A` is the first dispatch parameter after element type and rank.

## [TODO]

- [ ] Full support for `CommonDataModel.jl` interface

[Unreleased]: https://github.com/JuliaSpacePhysics/CDFDatasets.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/JuliaSpacePhysics/CDFDatasets.jl/releases/tag/v0.2.0

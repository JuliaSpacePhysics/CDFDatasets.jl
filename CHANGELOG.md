# Changelog

## [Unreleased]

### Changed

- **Breaking**: Remove exported `ConcatCDFVariable`; concatenating CDF variables now returns a `CDFVariable` backed by `DiskArrays.ConcatDiskArray`.
- **Breaking**: Remove exported `ConcatCDFDataset`; multi-file datasets are represented by `CDFDataset` with multiple sources.
- **Breaking**: Remove internal `ClippedCDFDataset`; dataset views are represented by `CDFDataset` with an interval.
- **Breaking**: `CDFVariable` type parameters are now ordered as `{T, N, A, S, P, MD}` so storage type `A` is the first dispatch parameter after element type and rank.

## [TODO]

- [x] Static analysis test with `JET.jl` 
- [ ] Full support for `CommonDataModel.jl` interface

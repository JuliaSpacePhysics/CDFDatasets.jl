# Changelog

## [Unreleased]

### Added

- SpaceDataModel time series interface for `CDFVariable` (SpaceDataModel is now a dependency): `tdimnum` from metadata without reading data (`nothing` for non-record-varying variables), `dims` returning in-memory coordinate variables with their attributes (a time-varying `DEPEND_i` is kept whole, sliced like the variable), and `unwrap`.

### Changed

- **Breaking**: reads decode, like NCDatasets: values equal to `FILLVAL` or outside `VALIDMIN`/`VALIDMAX` read as `NaN`, and masked integer variables read as floats (`Int8`/`Int16` as `Float32`). `variable(ds, name; fillval, validmin, validmax)` overrides or (`nothing`) disables each check; `parent(var)` is the stored data. Without a `FILLVAL` attribute no fill value is assumed.

### Removed

- **Breaking**: `sanitize` (reads decode) and the `replace_fillval`/`replace_invalid` keywords of `DimArray(var)` (use `variable` keywords).
- **Breaking**: the SpacePhysicsMakie extension; SpacePhysicsMakie plots CDF variables through the SpaceDataModel interface instead of converting them to `DimArray`s.

### Fixed

- `is_record_varying` of a materialized variable.

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

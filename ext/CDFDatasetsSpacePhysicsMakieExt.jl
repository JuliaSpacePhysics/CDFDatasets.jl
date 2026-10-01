module CDFDatasetsSpacePhysicsMakieExt

import SpacePhysicsMakie: transform
using DimensionalData: DimArray
using CDFDatasets: AbstractCDFVariable

transform(var::AbstractCDFVariable) = transform(DimArray(var))

end

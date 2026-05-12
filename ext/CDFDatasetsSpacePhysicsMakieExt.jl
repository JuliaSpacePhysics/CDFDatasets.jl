module CDFDatasetsSpacePhysicsMakieExt

import SpacePhysicsMakie: transform
using SpacePhysicsMakie: DimArray
using CDFDatasets: AbstractCDFVariable

transform(var::AbstractCDFVariable) = transform(DimArray(var))

end

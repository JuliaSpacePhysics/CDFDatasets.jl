module CDFDatasetsSpacePhysicsMakieExt

import SpacePhysicsMakie: transform
using SpacePhysicsMakie: DimArray
using CDFDatasets: AbstractCDFVariable, SubCDFVariable

transform(var::Union{AbstractCDFVariable, SubCDFVariable}) = transform(DimArray(var))

end

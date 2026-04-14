module PyCDFppDiskArraysExt

using PyCDFpp: PyCDFVariable
import DiskArrays

function DiskArrays.readblock!(var::PyCDFVariable, aout, inds::AbstractUnitRange...)
    aout .= var.data[inds...]
end


end
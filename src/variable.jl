struct CDFVariable{T, N, S, A <: AbstractArray{T, N}, P} <: AbstractCDFVariable{T, N}
    name::S
    data::A
    parentdataset::P
end

unwrap(x) = x
unwrap(var::AbstractCDFVariable) = var.data

Base.parent(var::AbstractCDFVariable) = var.data
Base.size(var::AbstractCDFVariable) = size(var.data)

function DiskArrays.readblock!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    return DiskArrays.readblock!(a.data, aout, inds...)
end

DiskArrays.eachchunk(var::CDFVariable) = DiskArrays.eachchunk(var.data)

_parent1(var::CDFVariable) = var.data

CDM.name(var::CDFVariable) = var.name
CDM.dataset(var::CDFVariable) = var.parentdataset
CDM.attribnames(var::CDFVariable) = CDM.attribnames(var.data)
CDM.attrib(var::CDFVariable) = CDM.attrib(var.data)
CDM.attrib(var::CDFVariable, name::String) = CDM.attrib(var.data, name)
CDM.dimnames(var::AbstractCDFVariable, i::Int) = dimnames(_parent1(var), i)
CDM.parentdataset(var::CDFVariable) = var.parentdataset


function CDM.dimnames(var::AbstractCDFVariable)
    if var_type(var) == "data"
        N = ndims(var.data)
        return ntuple(i -> dimnames(var, i), N)
    else
        return ()
    end
end

function CDM.dim(var::CDFVariable, i::Int; lazy = false)
    dname = dimnames(var, i)
    if !isnothing(dname)
        return lazy ? var.parentdataset[dname] : Array(var.parentdataset[dname])
    else
        return axes(var.data, i)
    end
end

cdf_type(var::AbstractCDFVariable) = cdf_type(_parent1(var))
CDF.is_record_varying(var::AbstractCDFVariable) = is_record_varying(_parent1(var))

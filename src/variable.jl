struct CDFVariable{T, N, A <: AbstractArray{T, N}, P} <: AbstractCDFVariable{T, N}
    name::String
    data::A
    parentdataset::P
end

unwrap(x) = x
unwrap(var::AbstractCDFVariable) = var.data

Base.parent(var::AbstractCDFVariable) = var.data
Base.size(var::AbstractCDFVariable) = size(var.data)
Base.getindex(var::AbstractCDFVariable, inds...) = var.data[inds...]
Base.setindex!(var::AbstractCDFVariable, v, inds...) = var.data[inds...] = v

CDM.name(var::CDFVariable) = var.name
CDM.dataset(var::CDFVariable) = var.parentdataset
CDM.attribnames(var::CDFVariable) = CDM.attribnames(var.data)
CDM.attrib(var::CDFVariable, name::String) = CDM.attrib(var.data, name)
CDM.dimnames(var::CDFVariable, i::Int) = CDM.dimnames(var.data, i)

cdf_type(var::CDFVariable) = cdf_type(var.data)

function CDM.dimnames(var::AbstractCDFVariable)
    if var_type(var) == "data"
        N = ndims(var.data)
        return ntuple(i -> dimnames(var, i), N)
    else
        return ()
    end
end

function CDM.dim(var::CDFVariable, i::Int)
    dname = dimnames(var, i)
    if !isnothing(dname)
        return var.parentdataset[dname]
    else
        return axes(var.data, i)
    end
end

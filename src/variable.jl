struct CDFVariable{T, N, S, A <: AbstractArray{T, N}, P, MD} <: AbstractCDFVariable{T, N}
    name::S
    data::A
    parentdataset::P
    metadata::MD
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

function CDM.dimnames(var::AbstractCDFVariable)
    if var_type(var) == "data"
        N = ndims(var.data)
        return ntuple(i -> dimnames(var, i), N)
    else
        return ()
    end
end

is_virtual(var) = var.attrib["VIRTUAL"] == "TRUE"

function CDM.dim(var::AbstractCDFVariable, i::Int)
    dname = dimnames(var, i)
    isnothing(dname) && return axes(var.data, i)
    dvar = dataset(var)[dname]
    return if i == ndims(var) && is_virtual(dvar) && "DEPEND_TIME" in attribnames(var)
        depend_time(var)
    else
        dvar
    end
end

cdf_type(var::AbstractCDFVariable) = cdf_type(_parent1(var))
CDF.is_record_varying(var::AbstractCDFVariable) = is_record_varying(_parent1(var))

# https://github.com/JuliaSpacePhysics/CDFDatasets.jl/issues/23
function depend_time(var; lazy = false)
    @debug "Non compliant CDF file, swapping DEPEND_0 with DEPEND_TIME"
    dname = attrib(var, "DEPEND_TIME")
    dimvar = dataset(var)[dname]
    return unix2datetime.(lazy ? dimvar : Array(dimvar))
end

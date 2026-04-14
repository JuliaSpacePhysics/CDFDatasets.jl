struct CDFVariable{T, N, S, A <: AbstractArray{T, N}, P, MD} <: AbstractCDFVariable{T, N}
    name::S
    data::A
    parentdataset::P
    metadata::MD
end

struct MaterializedCDFVariable{T, N, A <: AbstractArray{T, N}, P, MD} <: AbstractArray{T, N}
    name::String
    data::A
    parentdataset::P
    metadata::MD
end

const CDFVariableLike = Union{AbstractCDFVariable, MaterializedCDFVariable}

Base.parent(var::AbstractCDFVariable) = var.data
Base.size(var::CDFVariableLike) = size(var.data)

function Base.getindex(var::MaterializedCDFVariable, I...)
    result = getindex(var.data, I...)
    return result isa AbstractArray ?
        MaterializedCDFVariable(var.name, result, var.parentdataset, var.metadata) : result
end
Base.view(var::MaterializedCDFVariable, I...) =
    MaterializedCDFVariable(var.name, view(var.data, I...), var.parentdataset, var.metadata)
Base.reshape(var::MaterializedCDFVariable, dims::Dims) =
    MaterializedCDFVariable(var.name, reshape(var.data, dims), var.parentdataset, var.metadata)

function DiskArrays.readblock!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    return DiskArrays.readblock!(a.data, aout, inds...)
end

DiskArrays.eachchunk(var::CDFVariable) = DiskArrays.eachchunk(var.data)

_parent1(var::CDFVariable) = var.data

CDM.name(var::CDFVariableLike) = var.name
CDM.dataset(var::CDFVariableLike) = var.parentdataset
CDM.attribnames(var::CDFVariableLike) = keys(var.metadata)
CDM.attrib(var::CDFVariableLike) = var.metadata
CDM.attrib(var::Union{AbstractCDFVariable, MaterializedCDFVariable}, name::String) = var.metadata[name]
CDM.dimnames(var::AbstractCDFVariable, i::Int) = dimnames(_parent1(var), i)

function CDM.dimnames(var::AbstractCDFVariable)
    return if var_type(var) == "data"
        N = ndims(var.data)
        ntuple(i -> dimnames(var, i), N)
    else
        ()
    end
end

"""
    materialize(var)::MaterializedCDFVariable

Load the variable data from disk into memory.
"""
materialize(var) =
    MaterializedCDFVariable(CDM.name(var), Array(var), CDM.dataset(var), var.metadata)

is_virtual(var) = get(var.attrib, "VIRTUAL", nothing) == "TRUE"

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

struct CDFVariable{T, N, A <: AbstractArray{T, N}, S, P, MD} <: AbstractCDFVariable{T, N}
    data::A
    name::S
    parentdataset::P
    metadata::MD
end

Base.parent(var::CDFVariable) = var.data
Base.size(var::CDFVariable) = size(var.data)


rebuild(var, data) = CDFVariable(data, var.name, var.parentdataset, var.metadata)

Base.view(var::CDFVariable, I...) = rebuild(var, view(var.data, I...))
Base.reshape(var::CDFVariable, dims::Dims) = rebuild(var, reshape(var.data, dims))

function DiskArrays.readblock!(a::CDFVariable, aout, inds::AbstractUnitRange...)
    d = a.data
    if d isa AbstractDiskArray
        DiskArrays.readblock!(d, aout, inds...)
    else
        copyto!(aout, view(d, inds...))
    end
    return aout
end

DiskArrays.eachchunk(var::CDFVariable{T, N, <:AbstractDiskArray}) where {T, N} =
    DiskArrays.eachchunk(var.data)

CDM.name(var::CDFVariable) = var.name
CDM.dataset(var::CDFVariable) = var.parentdataset
CDM.attribnames(var::CDFVariable) = keys(var.metadata)
CDM.attrib(var::CDFVariable) = var.metadata
CDM.attrib(var::CDFVariable, name::String) = var.metadata[name]
CDM.variable(var::CDFVariable, name::String) = variable(dataset(var), name)

_parent1(data) = data
_parent1(data::CDFVariable) = _parent1(data.data)
_parent1(data::DiskArrays.ConcatDiskArray) = _parent1(data.parents[1])
_parent1(data::Union{SubArray, DiskArrays.SubDiskArray}) = _parent1(parent(data))

function CDM.dimnames(var::CDFVariable, i::Int)
    data = _parent1(var)
    return data isa Array ? _dataset_dimname(var, i) : dimnames(data, i)
end

function _dataset_dimname(var::CDFVariable, i::Int)
    source_var = variable(dataset(var), CDM.name(var))
    return dimnames(source_var, i)
end

function CDM.dimnames(var::CDFVariable)
    return if var_type(var) == "data"
        ntuple(i -> dimnames(var, i), ndims(var))
    else
        ()
    end
end

is_virtual(var) = get(var.attrib, "VIRTUAL", nothing) == "TRUE"

function CDM.dim(var::CDFVariable, i::Int)
    dname = dimnames(var, i)
    isnothing(dname) && return axes(var.data, i)
    dvar = dataset(var)[dname]
    return if i == ndims(var) && is_virtual(dvar) && "DEPEND_TIME" in attribnames(var)
        depend_time(var)
    else
        dvar
    end
end

const _SubView = Union{SubArray, DiskArrays.SubDiskArray}

function CDM.dim(var::CDFVariable{T, N, <:_SubView}, i::Int) where {T, N}
    parent_var = rebuild(var, parent(var.data))
    dvar = CDM.dim(parent_var, i)
    if (dvar isa CDFVariable && is_record_varying(dvar)) || (eltype(dvar) <: AbstractDateTime)
        indices = parentindices(var.data)[ndims(var)]
        return selectdim(dvar, ndims(dvar), indices)
    end
    return dvar
end

cdf_type(var::CDFVariable) = cdf_type(_parent1(var))
CDF.is_record_varying(var::CDFVariable) = is_record_varying(_parent1(var))

# https://github.com/JuliaSpacePhysics/CDFDatasets.jl/issues/23
function depend_time(var; lazy = false)
    @debug "Non compliant CDF file, swapping DEPEND_0 with DEPEND_TIME"
    dname = attrib(var, "DEPEND_TIME")
    dimvar = dataset(var)[dname]
    return unix2datetime.(lazy ? dimvar : Array(dimvar))
end

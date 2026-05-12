"""
    materialize(var)::CDFVariable

Load variable data from disk into memory, preserving name, dataset link, and metadata.
"""
materialize(var::CDFVariable) = rebuild(var, Array(var.data))

Base.BroadcastStyle(::Type{<:CDFVariable{T, N, A}}) where {T, N, A<:Array} =
    Base.BroadcastStyle(A)

Base.@propagate_inbounds Base.getindex(var::CDFVariable{T, N, A}, I...) where {T, N, A<:Array} =
    getindex(var.data, I...)
Base.getindex(var::CDFVariable{T, N, A}, name::Union{AbstractString, Symbol}) where {T, N, A<:Array} =
    invoke(getindex, Tuple{AbstractVariable, Union{AbstractString, Symbol}}, var, name)
Base.getindex(var::CDFVariable{T, N, <:Array}, name::CDM.CFStdName) where {T, N} =
    invoke(getindex, Tuple{Union{AbstractDataset, AbstractVariable}, CDM.CFStdName}, var, name)
Base.copy(var::CDFVariable{T, N, <:Array}) where {T, N} = copy(var.data)

for fname in (:sum, :prod, :all, :any, :minimum, :maximum)
    @eval begin
        Base.$fname(var::CDFVariable{T, N, <:Array}) where {T, N} =
            Base.$fname(var.data)
        Base.$fname(f::Function, var::CDFVariable{T, N, <:Array}) where {T, N} =
            Base.$fname(f, var.data)
    end
end

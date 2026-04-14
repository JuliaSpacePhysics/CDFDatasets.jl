struct PyCDF
    py::Py
end

struct PyCDFVariable{T, N, A <: AbstractArray{T, N}} <: AbstractArray{T, N}
    data::A
    py::Py
end

Base.keys(py::PyCDF) = py2jlkeys(py.py)
Base.keys(var::PyCDFVariable) = CDM.attribnames(var)

Base.parent(var::PyCDFVariable) = var.data
Base.iterate(A::PyCDFVariable, args...) = iterate(parent(A), args...)
for f in (:size, :Array)
    @eval Base.$f(var::PyCDFVariable) = $f(parent(var))
end

for f in (:getindex,)
    @eval Base.@propagate_inbounds Base.$f(var::PyCDFVariable, I::Vararg{Int}) = $f(parent(var), I...)
end

Base.getindex(ds::PyCDF, name::String) = CDM.variable(ds, name)
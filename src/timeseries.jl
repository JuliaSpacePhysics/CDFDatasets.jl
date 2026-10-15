function SDM.tdimnum(var::CDFVariable)
    N = ndims(var)
    dname = dimvarname(var, N)
    (isnothing(dname) || !is_record_varying(var)) && return nothing
    dname == dimnames(var, N) || return N  # swapped in DEPEND_TIME
    return eltype(_source1(dataset(var))[dname]) <: AbstractDateTime ? N : nothing
end

"""
    SpaceDataModel.dims(var::CDFVariable, i)

In-memory coordinate variable of dimension `i` (its `DEPEND`), else `axes(var, i)` (also when the
`DEPEND` does not fit). A non-record-varying coordinate loses its length-1 record dimension; a
record-varying one keeps its records, sliced like `var`.
"""
SDM.dims(var::CDFVariable, i::Integer) = @something _depend(var, i) axes(var, i)

function _depend(var::CDFVariable, i::Integer)
    dv = depend(var, i)
    isnothing(dv) && return nothing
    c = _inmemory(dv)
    i == ndims(var) || is_record_varying(dv) || (c = _droprecord(c))
    return _fits(c, var, i) ? c : nothing
end

# `LABL_PTR_i`, which CommonDataFormat resolves to the labels, when it fits dimension `i`.
function _labels(var::CDFVariable, i::Integer)
    l = get(CDM.attrib(var), "LABL_PTR_$i", nothing)
    return l isa AbstractVector{<:AbstractString} && length(l) == size(var, i) ? l : nothing
end

# Labels along dimension `i`, which slicing keeps aligned with it.
SDM.coords(var::CDFVariable) = [(i,) => l for i in 1:ndims(var) for l in (_labels(var, i),) if !isnothing(l)]

SDM.DataVariable(var::CDFVariable) = _datavariable(var, Array(var))

function _datavariable(var::CDFVariable, data; read = Returns(true))
    t = SDM.tdimnum(var)
    coord(i) = read(i) ? _coordvar(SDM.dims(var, i)) : axes(var, i)
    return SDM.DataVariable(data; time = isnothing(t) ? nothing : t => coord(t),
        dims = [i => coord(i) for i in 1:ndims(var) if i != t],
        coords = [axs => _coordvar(c) for (axs, c) in SDM.coords(var)], metadata = CDM.attrib(var), name = CDM.name(var))
end
_coordvar(c::CDFVariable) = SDM.DataVariable(Array(c); metadata = CDM.attrib(c), name = CDM.name(c))
_coordvar(c) = c

# A CDFVariable cannot hold new coordinates, so results are `DataVariable`s. 
SDM.rebuild(var::CDFVariable, data) = SDM.rebuild(_datavariable(var, var), data)
function SDM.rebuild(var::CDFVariable, data, newdims::Tuple)
    kept = [_axis(n) for n in newdims if n isa Val]
    return SDM.rebuild(_datavariable(var, var; read = in(kept)), data, newdims)
end
_axis(::Val{i}) where {i} = i

SDM.unwrap(var::CDFVariable) = parent(_inmemory(var))
SDM.axiskeys(var::CDFVariable, i::Integer) = SDM.unwrap(SDM.dims(var, i))

_inmemory(var) = parent(var) isa Array ? var : materialize(var)

_droprecord(v) = ndims(v) > 1 && size(v, ndims(v)) == 1 ? rebuild(v, dropdims(parent(v); dims = ndims(v))) : v

_fits(c, var, i) = ndims(c) == 1 ? length(c) == size(var, i) : size(c) == (size(var, i), size(var, ndims(var)))

function SDM.tdimnum(var::CDFVariable)
    N = ndims(var)
    dname = dimvarname(var, N)
    (isnothing(dname) || !is_record_varying(var)) && return nothing
    dname == dimnames(var, N) || return N  # swapped in DEPEND_TIME
    return eltype(_parent1(dataset(var))[dname]) <: AbstractDateTime ? N : nothing
end

"""
    SpaceDataModel.dims(var::CDFVariable, i)

In-memory coordinate variable of dimension `i` (its `DEPEND`), or `axes(var, i)` when there is
none or its shape does not fit. A non-record-varying coordinate loses its length-1 record dimension;
a record-varying one keeps its records, sliced like `var`.
"""
function SDM.dims(var::CDFVariable, i::Integer)
    dv = depend(var, i)
    isnothing(dv) && return axes(var, i)
    c = _inmemory(dv)
    i == ndims(var) || is_record_varying(dv) || (c = _droprecord(c))
    return _fits(c, var, i) ? c : axes(var, i)
end

SDM.unwrap(var::CDFVariable) = parent(_inmemory(var))

_inmemory(var) = parent(var) isa Array ? var : materialize(var)

_droprecord(v) = ndims(v) > 1 && size(v, ndims(v)) == 1 ? rebuild(v, dropdims(parent(v); dims = ndims(v))) : v

_fits(c, var, i) = ndims(c) == 1 ? length(c) == size(var, i) : size(c) == (size(var, i), size(var, ndims(var)))

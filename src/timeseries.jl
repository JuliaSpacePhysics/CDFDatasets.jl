function SDM.tdimnum(var::CDFVariable)
    N = ndims(var)
    dname = dimvarname(var, N)
    (isnothing(dname) || !is_record_varying(var)) && return nothing
    dname == dimnames(var, N) || return N  # swapped in DEPEND_TIME
    return eltype(_source1(dataset(var))[dname]) <: AbstractDateTime ? N : nothing
end

"""
    SpaceDataModel.dims(var::CDFVariable, i)

In-memory coordinate variable of dimension `i` (its `DEPEND`), or its `LABL_PTR_i` labels or
`axes(var, i)` when there is none or its shape does not fit. A non-record-varying coordinate loses its length-1 record dimension;
a record-varying one keeps its records, sliced like `var`.
"""
function SDM.dims(var::CDFVariable, i::Integer)
    labels = _labels(var, i)
    dv = depend(var, i)
    isnothing(dv) && return @something labels axes(var, i)
    c = _inmemory(dv)
    i == ndims(var) || is_record_varying(dv) || (c = _droprecord(c))
    _fits(c, var, i) || return @something labels axes(var, i)
    return isnothing(labels) ? c : _labeled(c, labels)
end

# `LABL_PTR_i`, which CommonDataFormat resolves to the labels, when it fits dimension `i`.
function _labels(var::CDFVariable, i::Integer)
    l = get(CDM.attrib(var), "LABL_PTR_$i", nothing)
    return l isa AbstractVector{<:AbstractString} && length(l) == size(var, i) ? l : nothing
end

# The labels become the coordinate's own first dimension, so slicing keeps them aligned with it.
_labeled(c::CDFVariable, labels) = SDM.DataVariable(parent(c), (labels, Base.tail(axes(parent(c)))...), nothing, CDM.attrib(c); name = CDM.name(c))

SDM.DataVariable(var::CDFVariable) = _datavariable(var, Array(var))
# Coordinates convert too, so slicing keeps their attributes.
_datavariable(var::CDFVariable, data) = SDM.DataVariable(data, map(_datadim, SDM.dims(var)), SDM.tdimnum(var), CDM.attrib(var); name = CDM.name(var))
_datadim(d::CDFVariable) = SDM.DataVariable(d)
_datadim(d) = d

# A CDFVariable cannot hold new coordinates, so results are `DataVariable`s. `var` stands in for the
# data, which `rebuild` replaces, so it is not read again.
SDM.rebuild(var::CDFVariable, args...) = SDM.rebuild(_datavariable(var, var), args...)

SDM.unwrap(var::CDFVariable) = parent(_inmemory(var))
SDM.axiskeys(var::CDFVariable, i::Integer) = SDM.unwrap(SDM.dims(var, i))

_inmemory(var) = parent(var) isa Array ? var : materialize(var)

_droprecord(v) = ndims(v) > 1 && size(v, ndims(v)) == 1 ? rebuild(v, dropdims(parent(v); dims = ndims(v))) : v

_fits(c, var, i) = ndims(c) == 1 ? length(c) == size(var, i) : size(c) == (size(var, i), size(var, ndims(var)))

function SDM.tdimnum(var::CDFVariable)
    N = ndims(var)
    dname = dimvarname(var, N)
    (isnothing(dname) || !is_record_varying(var)) && return nothing
    dname == dimnames(var, N) || return N  # swapped in DEPEND_TIME
    return eltype(_source1(dataset(var))[dname]) <: AbstractDateTime ? N : nothing
end

"""
    SpaceDataModel.dims(var::CDFVariable, i)

Coordinate of dimension `i`: its `DEPEND`, lazily, else `axes(var, i)` (also when the `DEPEND`
does not fit). A non-record-varying coordinate loses its length-1 record
dimension; a record-varying one keeps its records, sliced like `var`.
"""
SDM.dims(var::CDFVariable, i::Integer) = @something _depend(var, i) axes(var, i)

# A DEPEND that is the `LABL_PTR_i` variable itself holds labels, not values.
function _depend(var::CDFVariable, i::Integer)
    c = depend(var, i)
    (isnothing(c) || CDM.name(c) == get(CDM.attrib(var), "LABL_PTR_$i", nothing)) && return nothing
    i == ndims(var) || is_record_varying(c) || (c = _droprecord(c))
    return _fits(c, var, i) ? c : nothing
end

# Labels of the variable `LABL_PTR_i` names, when they fit dimension `i`, under its name so the pointer
# finds them. Dangling pointers exist in the wild (e.g. IM_K0_EUV); ISTP writers pad labels with spaces to the CHAR width.
function _labels(var::CDFVariable, i::Integer)
    p = get(CDM.attrib(var), "LABL_PTR_$i", nothing)
    source = _source1(dataset(var))
    p isa AbstractString && haskey(source, p) || return nothing
    lv = source[p]
    l = vec(Array(lv))  # `Array` skips DiskArrays indexing
    eltype(l) <: AbstractString && length(l) == size(var, i) || return nothing
    return SDM.DataVariable(map(s -> String(rstrip(s)), l); metadata = CDM.attrib(lv), name = p)
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

SDM.unwrap(var::CDFVariable) = Array(var)
SDM.axiskeys(var::CDFVariable, i::Integer) = SDM.unwrap(SDM.dims(var, i))

_droprecord(c) = ndims(c) > 1 && size(c, ndims(c)) == 1 ? view(c, ntuple(_ -> :, ndims(c) - 1)..., 1) : c

_fits(c, var, i) = ndims(c) == 1 ? length(c) == size(var, i) : size(c) == (size(var, i), size(var, ndims(var)))

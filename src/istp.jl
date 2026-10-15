# Reference
# [ISTP Metadata Guidelines: Global Attributes](https://spdf.gsfc.nasa.gov/istp_guide/gattributes.html)
# [ISTP Metadata Guidelines: Variables](https://spdf.gsfc.nasa.gov/istp_guide/variables.html)

# Values are free-form strings ("1", "01", "2.0", "v3.4.0"); VersionNumber parses all and orders them correctly.
function data_version(ds)
    dv = get(CDM.attribs(ds), "Data_version", nothing)
    isnothing(dv) && return nothing
    v = dv isa AbstractVector ? only(dv) : dv
    return VersionNumber(v isa AbstractString ? strip(v) : v)
end
var_type(var) = get(var.metadata, "VAR_TYPE", "")

# Recommended FILLVAL per type: https://spdf.gsfc.nasa.gov/istp_guide/vattributes.html#FILLVAL
fillvalue(::Type{Float32}) = -1.0f31
fillvalue(::Type{Float64}) = -1.0e31
fillvalue(::Type{Int8}) = Int8(-128)
fillvalue(::Type{Int16}) = Int16(-32768)
fillvalue(::Type{Int32}) = Int32(-2147483648)
fillvalue(::Type{Int64}) = Int64(-9223372036854775808)
fillvalue(::Type{UInt8}) = UInt8(255)
fillvalue(::Type{UInt16}) = UInt16(65535)
fillvalue(::Type{UInt32}) = UInt32(4294967295)

# Variable attributes with `LABL_PTR_i` resolved, on access, to the labels of the variable it names.
struct ISTPAttrib{K, V, D <: AbstractDict{K, V}, S} <: AbstractDict{K, V}
    attrib::D
    source::S
end
# PyCDFpp metadata is not an `AbstractDict`; it stays unresolved.
istp_attrib(attrib::AbstractDict, source) = ISTPAttrib(attrib, source)
istp_attrib(attrib, source) = attrib

const _NOTFOUND = gensym()
function Base.get(a::ISTPAttrib, k, default)
    v = get(a.attrib, k, _NOTFOUND)
    return v === _NOTFOUND ? default : _resolve(a.source, k, v)
end
Base.haskey(a::ISTPAttrib, k) = haskey(a.attrib, k)
Base.keys(a::ISTPAttrib) = keys(a.attrib)
Base.length(a::ISTPAttrib) = length(a.attrib)
Base.IteratorSize(::Type{<:ISTPAttrib{K, V, D}}) where {K, V, D} = Base.IteratorSize(D)
function Base.iterate(a::ISTPAttrib, s...)
    r = iterate(a.attrib, s...)
    isnothing(r) && return nothing
    (k, v), state = r
    return k => _resolve(a.source, k, v), state
end

_resolve(source, k, v) = v
function _resolve(source, k::AbstractString, v::AbstractString)
    # Dangling pointers exist in the wild (e.g. IM_K0_EUV); keep the raw name.
    startswith(k, "LABL_PTR_") && haskey(source, v) || return v
    # `Array` skips DiskArrays indexing
    labels = vec(Array(source[v]))
    # ISTP writers pad labels with spaces to the CHAR width.
    return eltype(labels) <: AbstractString ? map(rstrip, labels) : labels
end

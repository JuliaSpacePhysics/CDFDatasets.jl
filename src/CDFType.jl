# https://github.com/SciQLop/CDFpp/blob/main/include/cdfpp/cdf-enums.hpp

@enum CDFType begin
    CDF_NONE = 0
    CDF_INT1 = 1
    CDF_INT2 = 2
    CDF_INT4 = 4
    CDF_INT8 = 8
    CDF_UINT1 = 11
    CDF_UINT2 = 12
    CDF_UINT4 = 14
    CDF_BYTE = 41
    CDF_REAL4 = 21
    CDF_REAL8 = 22
    CDF_FLOAT = 44
    CDF_DOUBLE = 45
    CDF_EPOCH = 31
    CDF_EPOCH16 = 32
    CDF_TIME_TT2000 = 33
    CDF_CHAR = 51
    CDF_UCHAR = 52
end

const CDFType2JuliaType = Dict(
    CDF_NONE => Nothing,
    CDF_INT1 => Int8,
    CDF_INT2 => Int16,
    CDF_INT4 => Int32,
    CDF_INT8 => Int64,
    CDF_UINT1 => UInt8,
    CDF_UINT2 => UInt16,
    CDF_UINT4 => UInt32,
    CDF_BYTE => Int8,
    CDF_REAL4 => Float32,
    CDF_REAL8 => Float64,
    CDF_FLOAT => Float32,
    CDF_DOUBLE => Float64,
    CDF_EPOCH => Float64,
    CDF_EPOCH16 => Float64,
    CDF_TIME_TT2000 => UnixTime,
    CDF_CHAR => Char,
    CDF_UCHAR => UInt8,
)

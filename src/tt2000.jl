# 1. CDF_EPOCH is milliseconds since Year 0 represented as a single double,
# 2. CDF_EPOCH16 is picoseconds since Year 0 represented as 2-doubles,
# 3. CDF_TIME_TT2000 (TT2000 as short) is nanoseconds since J2000 with leap seconds

# https://github.com/SciQLop/CDFpp/blob/main/include/cdfpp/chrono/cdf-chrono.hpp
# https://github.com/SciQLop/CDFpp/blob/main/include/cdfpp/chrono/cdf-leap-seconds.h#L36
# TT2000 offset constant from C++ implementation
const TT2000_OFFSET = Int64(946727967816000000)  # nanoseconds from 1970 to J2000 with corrections

# Leap seconds table from C++ implementation
# https://www.wikiwand.com/en/articles/Leap_second
# Stores (nanoseconds_since_1970, leap_seconds_in_nanoseconds)
const LEAP_SECONDS_TT2000 = [
    (Int64(63072000000000000), Int64(10000000000)),   # 1-Jan-1972
    (Int64(78796800000000000), Int64(11000000000)),   # 1-Jul-1972
    (Int64(94694400000000000), Int64(12000000000)),   # 1-Jan-1973
    (Int64(126230400000000000), Int64(13000000000)),  # 1-Jan-1974
    (Int64(157766400000000000), Int64(14000000000)),  # 1-Jan-1975
    (Int64(189302400000000000), Int64(15000000000)),  # 1-Jan-1976
    (Int64(220924800000000000), Int64(16000000000)),  # 1-Jan-1977
    (Int64(252460800000000000), Int64(17000000000)),  # 1-Jan-1978
    (Int64(283996800000000000), Int64(18000000000)),  # 1-Jan-1979
    (Int64(315532800000000000), Int64(19000000000)),  # 1-Jan-1980
    (Int64(362793600000000000), Int64(20000000000)),  # 1-Jul-1981
    (Int64(394329600000000000), Int64(21000000000)),  # 1-Jul-1982
    (Int64(425865600000000000), Int64(22000000000)),  # 1-Jul-1983
    (Int64(489024000000000000), Int64(23000000000)),  # 1-Jul-1985
    (Int64(567993600000000000), Int64(24000000000)),  # 1-Jan-1988
    (Int64(631152000000000000), Int64(25000000000)),  # 1-Jan-1990
    (Int64(662688000000000000), Int64(26000000000)),  # 1-Jan-1991
    (Int64(709948800000000000), Int64(27000000000)),  # 1-Jul-1992
    (Int64(741484800000000000), Int64(28000000000)),  # 1-Jul-1993
    (Int64(773020800000000000), Int64(29000000000)),  # 1-Jul-1994
    (Int64(820454400000000000), Int64(30000000000)),  # 1-Jan-1996
    (Int64(867715200000000000), Int64(31000000000)),  # 1-Jul-1997
    (Int64(915148800000000000), Int64(32000000000)),  # 1-Jan-1999
    (Int64(1136073600000000000), Int64(33000000000)), # 1-Jan-2006
    (Int64(1230768000000000000), Int64(34000000000)), # 1-Jan-2009
    (Int64(1341100800000000000), Int64(35000000000)), # 1-Jul-2012
    (Int64(1435708800000000000), Int64(36000000000)), # 1-Jul-2015
    (Int64(1483228800000000000), Int64(37000000000)), # 1-Jan-2017
]

function leap_second(ns_from_1970::Int64)
    if ns_from_1970 > LEAP_SECONDS_TT2000[1][1]
        idx = findlast(x -> x[1] < ns_from_1970, LEAP_SECONDS_TT2000)
        return LEAP_SECONDS_TT2000[idx][2]
    end
    return Int64(0)
end

function tt2000_to_datetime(t::Integer)
    # Handle special fill/pad values
    # if t == 9223372036854775805  # CDF fill value
    #     return DateTime(9999, 12, 31, 23, 59, 59, 999)
    # elseif t == 9223372036854775806  # CDF pad value
    #     return DateTime(1, 1, 1, 0, 0, 0, 0)
    # end

    tt2000 = Int64(t)
    ns_from_1970 = tt2000 + TT2000_OFFSET
    leap_seconds_ns = leap_second(ns_from_1970)  # Already in nanoseconds
    return UNIX_EPOCH + Nanosecond(ns_from_1970 - leap_seconds_ns)
end

epoch_to_datetime(t) = DateTime(0) + Millisecond(t)

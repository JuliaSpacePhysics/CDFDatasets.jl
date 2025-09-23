# 1. CDF_EPOCH is milliseconds since Year 0 represented as a single double,
# 2. CDF_EPOCH16 is picoseconds since Year 0 represented as 2-doubles,
# 3. CDF_TIME_TT2000 (TT2000 as short) is nanoseconds since J2000 with leap seconds

function tt2000_to_datetime(t::Integer)
    # Handle special fill/pad values
    # if t == 9223372036854775805  # CDF fill value
    #     return DateTime(9999, 12, 31, 23, 59, 59, 999)
    # elseif t == 9223372036854775806  # CDF pad value
    #     return DateTime(1, 1, 1, 0, 0, 0, 0)
    # end
    return Dates.DateTime(CDF.TT2000(t))
end

epoch_to_datetime(t) = DateTime(0) + Millisecond(t)

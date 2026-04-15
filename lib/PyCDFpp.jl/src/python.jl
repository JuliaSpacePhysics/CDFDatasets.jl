using PythonCall: pyconvert
using PythonCall.Core: pyisnone

_string(x::Py) = pyconvert(String, x)
_char(x::Py) = pyconvert(Char, x)
py2jlkeys(py::Py) = pyconvert(Vector{String}, @py py.keys())

field_dtype(dtype::Py) = @py begin
    field_name = dtype.names[0]
    dtype.fields[field_name][0]
end

function tt2000_to_datetime_py(t)
    to_datetime64 = @pyconst pyimport("pycdfpp").to_datetime64
    py_dt64 = to_datetime64(t)
    py_ns = PyArray{Int64, 1, true, false, Int64}(@py py_dt64.view("i8"); copy = false)
    return reinterpret(UnixTime, py_ns)
end

# https://numpy.org/doc/stable/reference/arrays.dtypes.html
function py2jlvalues(var; copy = false)
    py = @py var.values
    # Check if the array has byte string dtype (e.g., '|S22')
    dtype = @py py.dtype
    dtype_num = pyconvert(Int, @py dtype.num)
    valid_py = if dtype_num == 18 # string dtype 'S'
        @py py.astype("U") # Convert byte strings to Unicode strings in Python first
    elseif dtype_num == 20 # Structured dtype like [('value', '<i8')]
        view_dtype = field_dtype(dtype)
        @py py.view(view_dtype)
    else
        py
    end

    cdftype = py_cdf_type(var)
    if cdftype == CDF_TIME_TT2000
        pyarr = PyArray{Int64, 1, true, false, Int64}(valid_py)
        return tt2000_to_datetime.(pyarr)
    elseif cdftype == CDF_EPOCH
        pyarr = PyArray{Float64, 1, true, false, Float64}(valid_py)
        return epoch_to_datetime.(pyarr)
    else
        return PyArray(valid_py; copy)
    end
end

py_cdf_type(var::Py) = pyconvert(Int, @py var.type.value)

function py2jlattrib(py, name)
    at = @py py.attributes[name]
    v = @py at.value
    return if pyisinstance(v, pybuiltins.list)
        pyconvert(PyList, v)
    else
        pyconvert(Any, v)
    end
end

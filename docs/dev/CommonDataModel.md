## Why not CommonDataModel.jl

CommonDataModel encodes NetCDF/CF; CDF/ISTP differs on nearly every point:

| NetCDF/CF (CommonDataModel)                         | CDF/ISTP                                                 |
|-----------------------------------------------------|----------------------------------------------------------|
| Named dimensions shared across variables            | None; `DEPEND_i` attributes point to coordinate variables |
| `_FillValue`/`scale_factor` decoding to `missing`   | `FILLVAL`/`VALIDMIN`/`VALIDMAX` decoding to `NaN`         |
| Groups, unlimited dimensions                        | Record variance, master CDFs, `VIRTUAL`/`DEPEND_TIME`, `LABL_PTR` |

Even `ds[name]` goes through `cfvariable`, so a CDF backend overrides most of the interface;
only the function names can carry over. The interface also costs:

- a hard DiskArrays dependency, as `AbstractVariable <: AbstractDiskArray`;
- eager `attribs`, which builds a dictionary of every attribute;
- Preferences.jl loaded only for display colours.

CDF variables fit in memory, so `lazy.jl` reads each request as one unchunked region instead.
The cost is a Base override for every path that would otherwise read element by element
(`getindex`, `copyto!`, `iterate`, …).
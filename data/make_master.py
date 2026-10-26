# Master for labl_ptr.cdf: attributes its `ok` lacks; a DEPEND_1 overriding its `flux`'s that names a
# non-record-varying variable only the master holds; `labels` with other values than the file's; a global attribute.
# Run: uv run --with cdflib python data/make_master.py data/labl_ptr_master.cdf
import sys
import numpy as np
from cdflib.cdfwrite import CDF

c = CDF(sys.argv[1], delete=True)
c.write_globalattrs({"Logical_source": {0: "labl_ptr"}})
vec = {"Data_Type": 45, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": [3]}
c.write_var({**vec, "Variable": "ok"}, var_attrs={"DEPEND_0": "epoch", "FILLVAL": np.float64(0.0)}, var_data=np.zeros((1, 3)))
c.write_var({**vec, "Variable": "flux"}, var_attrs={"DEPEND_1": "energy_vals"}, var_data=np.zeros((1, 3)))
c.write_var({**vec, "Variable": "energy_vals", "Rec_Vary": False}, var_data=np.array([10.0, 20.0, 30.0]))
c.write_var({"Variable": "labels", "Data_Type": 51, "Num_Elements": 2, "Rec_Vary": False, "Dim_Sizes": [3]},
            var_data=np.array(["Ex", "Ey", "Ez"]))
c.close()

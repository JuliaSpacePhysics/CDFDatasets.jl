# LABL_PTR_1 pointing at an existing variable and at a missing one (seen in IM_K0_EUV), and labelling a
# record-varying DEPEND_1; an epoch naming itself as its DEPEND_0; variables with no records
# written (ACE `Time_PB5`; THEMIS virtual epochs and the DEPEND_TIME standing in for them).
# Run: uv run --with cdflib python data/make_labl_ptr.py data/labl_ptr.cdf
import sys
import numpy as np
from cdflib.cdfwrite import CDF
from cdflib.epochs import CDFepoch

c = CDF(sys.argv[1], delete=True)
vec = {"Data_Type": 45, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": [3]}
c.write_var({"Variable": "labels", "Data_Type": 51, "Num_Elements": 2, "Rec_Vary": False, "Dim_Sizes": [3]},
            var_data=np.array(["Bx", "By", "Bz"]))
c.write_var({**vec, "Variable": "ok"}, var_attrs={"LABL_PTR_1": "labels"}, var_data=np.zeros((2, 3)))
c.write_var({**vec, "Variable": "dangling"}, var_attrs={"LABL_PTR_1": "CARTESIAN"}, var_data=np.zeros((2, 3)))
c.write_var({"Variable": "epoch", "Data_Type": 31, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": []},
            var_data=np.array(CDFepoch.compute_epoch([[2020, 1, 1, 0, 0, 0, 0], [2020, 1, 1, 0, 1, 0, 0]])))
c.write_var({**vec, "Variable": "energy"}, var_attrs={"DEPEND_0": "epoch"}, var_data=np.arange(6.0).reshape(2, 3))
c.write_var({**vec, "Variable": "flux"}, var_attrs={"DEPEND_0": "epoch", "DEPEND_1": "energy", "LABL_PTR_1": "labels"},
            var_data=np.ones((2, 3)))
c.write_var({"Variable": "self_epoch", "Data_Type": 31, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": []},
            var_attrs={"DEPEND_0": "self_epoch"}, var_data=np.array(CDFepoch.compute_epoch([[2020, 1, 1, 0, 0, 0, 0], [2020, 1, 1, 0, 1, 0, 0]])))
c.write_var({"Variable": "unwritten", "Data_Type": 45, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": []},
            var_attrs={"DEPEND_0": "epoch"}, var_data=None)
scalar = {"Data_Type": 45, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": []}
c.write_var({"Variable": "unwritten_epoch", "Data_Type": 31, "Num_Elements": 1, "Rec_Vary": True, "Dim_Sizes": []},
            var_attrs={"VIRTUAL": "TRUE"}, var_data=None)
c.write_var({**scalar, "Variable": "unwritten_time"}, var_data=None)
c.write_var({**scalar, "Variable": "unwritten_swapped"},
            var_attrs={"DEPEND_0": "unwritten_epoch", "DEPEND_TIME": "unwritten_time"}, var_data=None)
c.close()

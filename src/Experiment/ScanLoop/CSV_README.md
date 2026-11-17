# Current × X scan with ESR: CSV columns

One row per scan point, so one ESR measurement per row. The rows are in the order they were measured.

## The scan
A wire current I is set and the stage moves X. An ESR spectrum is then measured at each point. A static bias field of about 26 G is applied, and the wire field adds to it.
At each X move the stage goes Z back (retract), then X to the new position, then Z returns to the scan height.

## Columns

Column names start with `sN_`, where N is the number of the step in the loop. The step numbers depend on the loop order:

| Order | Step columns |
|---|---|
| **current outer** (a full X scan per current) | `s1_Current`, `s2_Z`, `s3_X`, `s4_Z`, `s6_experiment_*` |
| **X outer** (all currents at each X position) | `s1_Z`, `s2_X`, `s3_Z`, `s4_Current`, `s6_experiment_*` |

Step 5 is a settle wait, so it has no column.

| Column | Meaning | Unit |
|---|---|---|
| `point` | Point index, 1…N | – |
| `I` | Requested wire current | **mA** |
| `x` | Requested X offset from the X position at the start of the scan | **µm** |
| `time` | When the point started | yyyy-MM-dd HH:mm:ss |
| `sN_Current` | Current read back from the HP E3631A source | **A** |
| `sN_Z` (the first one) | Absolute Z while retracted, during the X move | **mm** |
| `sN_X` | Absolute X position read back from the stage | **mm** |
| `sN_Z` (the second one) | Absolute Z at the scan height, where the ESR was measured | **mm** |
| `s6_experiment_file` | Name of the ESR data file for this point | – |
| `s6_experiment_averages` | Number of ESR averages completed | – |
| `s6_experiment_path` | Full path of that ESR file | – |

## Notes
- The **absolute X in mm** is the true position. `x` is the nominal offset, and `(sN_X − sN_X[row 1]) × 1000 − x` should be about 0 µm.
- If `s6_experiment_averages` is smaller than the planned number of averages, that point was cut short because the run was stopped. Treat it as lower quality, or drop it.
- In **X outer** order, the stage does not move when only the current changes. The Z and X columns still hold the actual stage readback for every row.
- The ESR curves themselves are not in the CSV. They are in the per-point ESR files (`_path`) and in the `.mat` file of the same name as the CSV. In the `.mat` file, `data(i).s6_experiment` holds:
  - `x`: microwave frequencies [MHz]
  - `y` and `ySterr`: the normalized ESR signal and its standard error
  - `meanKcps`: the mean photon counts [kcps]
- If an ESR background (BG) was set in the ESR experiment, the saved signal follows the subtract-BG setting that was active at the time of the run.

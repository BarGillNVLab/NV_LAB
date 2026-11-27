# Current × X scan with ESR: CSV columns

One row per scan point, so one ESR measurement per row. The rows are in the order they were measured.

## The scan
A wire current I is set and the stage moves X. An ESR spectrum is then measured at each point. A static bias field of about 26 G is applied, and the wire field adds to it.
At each X move the stage goes Z back (retract), then X to the new position, then Z returns to the scan height.
If the **Z focus search** was on, Z is then stepped (3 µm steps by default) to the best count rate, and the ESR is measured there.

## Columns

Column names start with `sN_`, where N is the number of the step in the loop. The step numbers depend on the loop order:

| Order | Step columns |
|---|---|
| **current outer** (a full X scan per current) | `s1_Current`, `s2_Z`, `s3_X`, `s4_Z`, `s6_experiment_*` |
| **X outer** (all currents at each X position) | `s1_Z`, `s2_X`, `s3_Z`, `s4_Current`, `s6_experiment_*` |

Step 5 is a settle wait, so it has no column.

**With the Z focus search** a focus step is inserted after the Z return, so every later step number goes up by one:
- **current outer:** `s5_focus*`, then `s7_experiment_*`
- **X outer:** `s4_focus*`, then `s5_Current`, `s7_experiment_*`

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
| `sN_focusZ` | Z chosen by the focus search; the ESR was measured here | **mm** |
| `sN_focusShiftUm` | How far that is from the scan height (+ = forward) | **µm** |
| `sN_focusKcps` | Count rate at that Z during the search | **kcps** |
| `sN_focusStd` | Count fluctuation there: STD between 10 sub-reads of 0.1 s each | **kcps** |
| `sN_focusScore` | What the search maximised: `kcps − w × STD` (w set in the scan window) | **kcps** |
| `sN_focusVerifyKcps`, `sN_focusVerifyStd` | The re-read after the final approach from below | **kcps** |
| `sN_focusReads` | Number of 1 s readings the search took | – |
| `sN_focusTravel` | 1 if the search hit its max travel, so the best Z may lie beyond it | – |
| `sN_focusSpcmError` | 1 if the SPCM failed during the search (after retries): Z went back to the scan height without a search, and the focus values are empty | – |
| `s6_experiment_file` | Name of the ESR data file for this point | – |
| `s6_experiment_averages` | Number of ESR averages completed | – |
| `s6_experiment_path` | Full path of that ESR file | – |

## Notes
- The **absolute X in mm** is the true position. `x` is the nominal offset, and `(sN_X − sN_X[row 1]) × 1000 − x` should be about 0 µm.
- If `s6_experiment_averages` is smaller than the planned number of averages, that point was cut short because the run was stopped. Treat it as lower quality, or drop it.
- In **X outer** order the focus search runs once per X position, so the `focus` columns are empty on the other rows of that X.
- `sN_focusShiftUm` across X traces the sample tilt or focal drift, to a resolution of about one step.
- The search history (each Z, kcps, standard error, STD, score) is in the `.mat` file as `data(i).sN_focusHistory`.
- In **X outer** order, the stage does not move when only the current changes. The Z and X columns still hold the actual stage readback for every row.
- The ESR curves themselves are not in the CSV. They are in the per-point ESR files (`_path`) and in the `.mat` file of the same name as the CSV. In the `.mat` file, `data(i).s6_experiment` (`s7_` with the focus search) holds:
  - `x`: microwave frequencies [MHz]
  - `y` and `ySterr`: the normalized ESR signal and its standard error
  - `meanKcps`: the mean photon counts [kcps]
- If an ESR background (BG) was set in the ESR experiment, the saved signal follows the subtract-BG setting that was active at the time of the run.

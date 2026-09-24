# EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922

## Verdict

```text
RESULT                           = PASS_STEP6B_POSTFIT_TIMING_PROVEN
SLAVE_TIMING_RESULT              = PASS_STEP6B_POSTFIT_TIMING_PROVEN
MASTER_TIMING_RESULT             = PASS_STEP6B_POSTFIT_TIMING_PROVEN
STEP6B_HARDWARE_TRIGGER          = NOT_RUN
STEP6_OVERALL                    = NOT_YET_CLAIMED
```

This experiment proves the post-fit static-timing gate for the digital
scheduled dual-board trigger. It does not prove that two programmed boards
actually fired together; that requires a separate hardware experiment after
adviser review.

## Scope and protocol

The run was performed on Pain using the already fitted artifacts from
`EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-20260922`:

- checker-only correction; no RTL, SDC, QSF, or MIF change;
- no firmware build and no full Quartus compile;
- no FPGA programming, reset, PTP restart, or power cycle;
- no hardware access;
- both Slave and Master were checked with Quartus TimeQuest 17.0.

The fitted design provenance was source commit
`c24568e383be3355ac8684b7d13f293115931586`. The offline checker and report
were run at branch commit `a7d21522172369efa1e5a9f092e88d4661a83208`.

## Provenance check

All six design-source hashes and all four fitted-artifact hashes matched the
previous build record. In particular:

```text
MASTER_SOF_SHA256 = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
SLAVE_SOF_SHA256  = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
MASTER_MIF_SHA256 = 8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
SLAVE_MIF_SHA256  = eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b
MIF_UNCHANGED     = YES
PROVENANCE_CHECK  = PASS
```

## Timing query contract

The checker now uses `get_path_info $path -slack` and preserves the resolved
path endpoints, path type, and TimeQuest clock aliases. The public query
domain is recorded explicitly as `qsfp_ref_125m`; TimeQuest reports its
resolved object as `clock_3` for these paths.

The nine required groups were checked for both setup and hold:

1. `target_meta_to_sync`
2. `target_sync_to_latched`
3. `arm_meta_to_sync`
4. `arm_sync_to_prev`
5. `refclk_to_armed`
6. `refclk_to_fired`
7. `refclk_to_fire_count`
8. `refclk_to_actual_tai`
9. `refclk_to_actual_cycles`

For P1–P4, the source and destination register collections were explicit.
For P5–P9, the source domain was the public `qsfp_ref_125m` clock, as
required by the adviser contract.

## Worst setup/hold slack (ns)

| Timing group | Slave setup | Slave hold | Master setup | Master hold |
|---|---:|---:|---:|---:|
| `target_meta_to_sync` | 7.246 | 0.049 | 6.662 | 0.047 |
| `target_sync_to_latched` | 6.558 | 0.153 | 6.863 | 0.126 |
| `arm_meta_to_sync` | 7.503 | 0.086 | 7.571 | 0.047 |
| `arm_sync_to_prev` | 7.002 | 0.491 | 7.300 | 0.212 |
| `refclk_to_armed` | 4.686 | 0.178 | 4.008 | 0.188 |
| `refclk_to_fired` | 4.738 | 0.158 | 4.232 | 0.153 |
| `refclk_to_fire_count` | 3.814 | 0.150 | 3.925 | 0.161 |
| `refclk_to_actual_tai` | 4.371 | 0.281 | 3.537 | 0.187 |
| `refclk_to_actual_cycles` | 4.371 | 0.262 | 3.537 | 0.190 |

All 36 required setup/hold path groups had non-empty path collections,
numeric non-negative slack, and valid public clock-domain provenance.

## Raw evidence

- `raw/stop.txt` — terminal result and zero program/reset/power-cycle counts;
- `raw/provenance.txt` — source and fitted-artifact hash comparison;
- `raw/timing/slave_step6b_timing.txt`;
- `raw/timing/master_step6b_timing.txt`;
- `raw/timing/*setup.rpt` and `raw/timing/*hold.rpt` — full TimeQuest path reports;
- `analysis/summary.json` — machine-readable PASS classification.

## Boundary and next step

The Step6A global-time validity and same-PPS consistency result remains PASS
from the preceding experiment. This report adds the Step6B digital scheduler
post-fit timing proof only. Do not call overall Step6 PASS yet: the next
hardware run must first be reviewed by the adviser, then program the existing
Slave and Master SOFs once and perform the prescribed read-only scheduled-fire
capture.

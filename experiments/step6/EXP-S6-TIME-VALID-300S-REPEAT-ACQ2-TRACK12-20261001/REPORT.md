# EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001 — Historical image rebuild pending

## Current verdict

~~~text
STEP6_TIME_VALID_300S_BOTH_BOARDS = NOT_ESTABLISHED
BUILD_AND_PROGRAM                 = ABORTED_BEFORE_PROGRAM
DUAL_BOARD_303S_CAPTURE           = NOT_RUN
NEXT_ACTION                       = rebuild from historical build commit in an isolated worktree
~~~

One build attempt has occurred. No programming or hardware capture for this
experiment has occurred.
The historical evidence is a near-pass only:

~~~text
/2 acquisition + /12 tracking, Slave only:
STATUS_TIME_VALID = 959 / 959
sample span       = 299,998 ms
maximum gap       = 411 ms
observer done     = 300,403 ms
~~~

The prior 300,000-ms request ended its last sample 2 ms short of the required
span. The intended repeat holds the exact historical candidate image and
requests 303,000 ms on each board. No Step 6 pass is claimed until both boards
independently satisfy the complete acceptance contract in PLAN.md.

## Build attempt 1 — stopped safely before programming

The first build used the synchronized repository HEAD `62234ab7` and applied
the correct historical `/2 + /12` source patch. Both Quartus compilations
succeeded, but the rebuilt firmware MIF and SOF hashes did not equal the
previously exercised candidate, so the mandatory hash gate stopped the script.
No programming command ran and neither board was changed.

The cause is established from source and build logs: both defconfigs set
`CONFIG_DETERMINISTIC_BINARY=y`, but `revision.c` still initializes
`.commit_id = __GIT_VER__`; the firmware Makefile obtains this from
`git describe --always --dirty`. The successful candidate build commit was
`4c1adf73ab762506939163d467fb8c6b35bca9b4`, whereas this aborted build used
`62234ab7e9dd01ddb93bcc201b8ea4057032a6d6`; the latter embedded
`master-diagnostic-baseline-20260817-1503-g62234ab7-dirty`. The old and new
Master/Slave QSF, SDC, and fitter timing summaries matched. The changed
firmware build ID is the identified difference in the MIF input, and the
MIF/SOF hash gates independently confirmed that the generated artifacts were
not the historical ones.

| Board | Historical MIF SHA-256 | Aborted MIF SHA-256 | Historical SOF SHA-256 | Aborted SOF SHA-256 |
|---|---|---|---|---|
| Master | `07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6` | `8e7bb3c20e7729f05336611ad5a6ea64d92f36d2634865f6e9f9b0c605acb658` | `2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b` | `99c935d267573cf4b061c37bc81a1660c4dbc46d5f88774523496c3b7d1ce665` |
| Slave | `d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916` | `1681bf3595c1ee8e1fa40dbb91abee57049219b5d4a335673232b0d7da13259e` | `dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b` | `6ebb1aab6a54d32a9394995d54d689da58b60e8f18fff8413792a1904753d2a1` |

The script restored the patched source, verified both source/artifact manifests,
and confirmed unrelated untracked paths were preserved. Raw build logs with
the `20261001T085322Z-` prefix are in `raw/build/`; preflight/restore logs are
in `raw/preflight/`.
The next attempt is constrained to a temporary isolated worktree at the exact
historical build commit; both historical MIF hashes will be checked before
Quartus and both SOF hashes before any programming. A mismatch remains a
hard stop.

## Run evidence

Append the exact Laptop/Pain/GitHub commits, manifest results, build and
programming logs, candidate SOF hashes, readiness observations, raw capture
SHA-256, analyzer output, per-board spans/rows/gaps/valid counts, and final
verdict here after the hardware run.

# Master HPLL physical-step accounting: two independent root reproductions

Result: **PASS_TWO_INDEPENDENT_ROOT_CYCLES**, 2026-10-02.

## What failed before

The prior bootstrap2048 archive and main root had identical source/scripts/SOFs.
After the 15:32 reprogram, Slave still had five PLL lock bits high but TIME_VALID
was 0, offset about -1941 ps and WAIT_OFFSET_STABLE. Master Helper was unlocked,
its phase tracker unready; passive readings showed Master output ranging 5–65531.
Those sequential scalar readings are diagnostic, not coherent causal frames.
The precondition logs preserve this failure. Therefore a copy checksum alone
could not establish startup reproduction; the old single-session PASS was not
enough to promote a repeatable milestone.

## Sole production change

In `quartus/DE5a_wr_master_jtag.vhd`, Master
`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP` changed **34 → 64**, matching physical
step accounting already used by Slave. Master bootstrap 2048, reverse direction,
Slave bootstrap 3388, PI/gains/thresholds, servo `/2 acquisition + /12 tracking`,
timeout, PHY/reset and all firmware control code remain unchanged.

Master MIF: `18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea`.
Slave MIF: `91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379`.

## Complete hardware cycles, not repeated reads of one boot

| Cycle | Start → finish (+08:00) | Actual compile checkout |
|---|---|---|
| 1 | 16:28:17 → 16:58:29 | `3b68162d8c13998478f970b9d6c1020b682cb4c6` |
| 2 | 16:59:49 → 17:31:23 | `7b6550123986a9d7cea5f4be0dbb8af1f5a019ab` |

Each ran in `/home/b10504072/04_WR`: firmware build → full clean Master/Slave
Quartus compile → Slave then Master programming → dashboard/readiness → qualified
capture → dashboard. Both programmers succeeded. Each cycle acquired both valid
bits after about 130 seconds; neither capture started from invalid data.
Observer/report-only changes distinguish the Git commits; **all 3110 production
compile-input hashes and the two MIFs match exactly**. SOF bytes differ between
fresh compiles; each cycle retains its actual programmed pair and build identity.

| Cycle / board | TIME_VALID rows | Sample span | Capture elapsed | Max gap | Invalid |
|---|---:|---:|---:|---:|---:|
| 1 Master | 1192/1192 | 302791 ms | 303044 ms | 257 ms | 0 |
| 1 Slave | 1192/1192 | 302901 ms | 303154 ms | 257 ms | 0 |
| 2 Master | 1192/1192 | 302815 ms | 303069 ms | 258 ms | 0 |
| 2 Slave | 1192/1192 | 302885 ms | 303140 ms | 256 ms | 0 |

Raw captures are complete, sequence/board identity checks pass, no transport
errors. PPS, link, live counter progression and snapshot validity were also good
in these rows, but **STATUS_TIME_VALID is the acceptance signal**. Board windows
were sequential, requested 250 ms sampling, not simultaneous physical measurements.
Master Helper was locked in both post-capture dashboards; cycle1 also exposed
sequencer ready and phase tracker ready with phase 1708 ps. Slave five lock bits
were high in both post-capture dashboards; these snapshots are not a separate
300-second PLL-lock series.

## Actual images retained

| Cycle | Master SHA256 | Slave SHA256 |
|---|---|---|
| 1 | `d593846302998a8601b244212dc32e283d9c2d0c3ff66bfa751e195774b12861` | `a79633978091796bc4b78122bbf4df04c3704456c814d13acd2cde66f03cb412` |
| 2 | `9f66cef3f06697085325916126e6da61d76ace7138e7203af068df1a69d30036` | `b92e3356580691814e113e8c3278f1044bee621e2808d207541c9efc3ba59727` |

Cycle records: `raw/cycles/20261002T082817Z-cycle1/` and
`raw/cycles/20261002T085949Z-cycle2/`; each includes cycle log, actual SOFs,
source/input identity, build metadata, independent raw capture and verdict.
The Laptop independently reran `scripts/analysis/step6_reproduction_pair.py`:
both raw captures passed, actual SOFs match build identity, complete pipeline
markers occur once each, cycles are consecutive and non-overlapping, captures
are distinct and production manifests/MIFs identical.

The verified second-cycle source/products become the **only** active Step6
milestone. Old packages are recoverable from Git history and separate backups,
not mixed into this directory. Protected `04_WR_archive_step6_pass` was not used
or modified. No consultant, power cycle or extra control tuning was used.

## Limits

PASS means two complete reproductions of sampled TIME_VALID ≥300 seconds on
each board. It does not guarantee every future boot, uninterrupted validity
between samples, offset <60 ps, correct absolute UTC/TAI, equal Master/Slave
time labels or physical edge skew. Timing closure remains separate and is not
required by the user. A new WAITING result must be diagnosed honestly, not
hidden by historical PASS or forced validity.

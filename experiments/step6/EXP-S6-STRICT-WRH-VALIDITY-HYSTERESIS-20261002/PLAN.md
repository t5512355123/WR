# Strict WR validity hysteresis and reproducibility — 2026-10-02

Baseline: `4c53b7132f963cc7f67fc3e24f9f3bf225614f69`, `feat/file_cleanup`.
The frozen Step6 package and `/home/b10504072/04_WR_archive_step6_pass/`
remain untouched. Historical TIME_VALID-only passes are not this goal's PASS.

## Full goal

Slave must first observe a trustworthy full WR offset strictly inside +/-60 ps.
After acquisition it must sustain TIME_VALID and PPS_VALID for at least 300 s,
with every observed full offset within inclusive +/-120 ps. Any new measured
offset beyond that band must revoke validity, also while phase hardware is
busy or IPC/demo tracking is disabled. Link/PLL loss, reset, coarse correction
and unsuccessful timestamp calculation cannot retain Slave validity.

The final qualification must combine fresh coherent offset/servo identities,
lock/link/reset health and validity over the same window. A completed observer,
one in-band sample, a stale diagnostics frame or a TIME_VALID-only capture is
not sufficient. No claim of analogue SMA skew or timing closure is made.

## Source-proven discrepancy

The baseline WAIT state enables timing output once on a <60 ps sample. TRACK
exits at >120 ps but does not disable that output. Init/reset/coarse correction
and PLL-loss paths likewise do not consistently revoke it. The TRACK test also
uses wrapped phase residual, after the busy return and inside tracking-enabled.
This explains why historical VALID can coexist with multi-ns CKO; it does not
prove that the acquisition controller or timestamp measurements are stable.

## First candidate, not a gain sweep

- Fail-closed state transitions and early error paths in `wrh-servo.c`.
- Signed-64 full-offset checks, strict +/-60 acquisition, +/-120 retention.
- Clear old WAIT misses on successful entry.
- Disallow force-PPS from bypassing the Slave gate; preserve Master/GM force.
- Preserve acquisition /2, tracking /12, PI gains, thresholds, DMS/PTP,
  bootstrap, RTL, SDB, port mapping and reset tree.
- Add executable tests against the actual servo C with hardware stubs, not
  only a Python behavioural model. Include +/-60, +/-120, busy, tracking off,
  coarse jumps, 64-bit extrema, PLL loss, invalid calculation, reset/reinit.
- Keep build manifests source-pinned; old SOFs must fail after source changes.

## Evidence and next decision

Precondition dashboard on 2026-10-02 22:31: Slave five PLL lock bits are 1,
TIME_VALID/PPS_VALID are 0, WAIT_OFFSET_STABLE, CKO +3676 ps. The interleaved
same-frame reader is INCONCLUSIVE (5/5 publication epoch changes); do not use
these rows as coherent data. The independent UCNT-pair smoke yielded 26/30
counter-bracketed rows and 12 adjacent update pairs, with no payload conflicts.
UCNT-only bracketing is useful diagnosis, not a final atomic-frame guarantee.

Collect a bounded longer precondition trace of CKO/SETP/raw RTT/DMS. Test and
push on Laptop before Pain pulls/builds. Build firmware first, record and pin
its new MIFs before full compile/program. Preserve all actual source/SOF hashes.
Stop captures on reset, transport failure, conflicting frames or invalid data.
If this candidate revokes validity correctly but cannot retain the required
band, record FAIL (not narrowed PASS), then use coherent measurements to isolate
timestamp/actuator/control behaviour before the next in-scope candidate.

The WR phase controller is `setpoint += measured_error/divisor`, not a separate
Ki setting. PLL Ki and WR phase correction are different loops. A gain change
cannot explain an offset jump during a zero-SETP-delta interval by itself;
correlation of RTT/DMS/phase/timestamp state is required. No advisor messages.

## Pre-compile qualification

Pain pulled `8f8a5af51f5f6ab471cf001d03e1d23c4ad3fa77`. The actual C
test with undefined-behaviour sanitizer passed 31 cases; all 7 Python tests
passed there. Laptop passed 6 contracts, with the native-C test explicitly
skipped because no native C compiler is installed. Both role firmware builds
succeeded. MIFs are pinned before full FPGA compile:

- Master: `61d7ba5ef46c58521377a59fd7b134d331a77e6ea45a8130d5ba3de71aad1c5c`.
- Slave: `4b61c3e22a3f78671f3443fcfab346df0d79940dc7a59eacc99fd12b75e275a1`.

The 120 s precondition trace contained 117 unique UCNT-bracketed updates,
115 adjacent pairs, CKO -2432..+4050 ps, and only 2 updates inside +/-120 ps.
70 adjacent pairs jumped by >120 ps with zero SETP change. Several raw RTT
changes were about +/-8000 ps and DMS changes about +/-4000 ps. This supports
investigating timestamp/phase measurements, not assigning every jump to Ki.
The trace also exposed 113 pointwise VALID updates outside +/-120 ps; these
cannot count toward the stricter goal. These are diagnostic correlations,
not publication-epoch coherent physical causality or a root-cause proof.

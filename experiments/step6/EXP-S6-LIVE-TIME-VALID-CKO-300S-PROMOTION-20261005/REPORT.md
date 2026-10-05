# Live Step6 TIME_VALID 300 s revalidation and CKO timeline

Date: 2026-10-05, Asia/Taipei. Source of truth: live Pain
`/home/b10504072/04_WR`, initially `feat/file_cleanup` at `9b8a231c`.
Pain's existing documentation is the baseline for README/STATUS/MILESTONES
updates. Retained products record full-build source `bcb84305`, with Master and
Slave compilation completed on 2026-10-04 at 19:45/19:57 and successful recorded
programming pair `20261004T122705Z`. Checkout/build records are not independent
on-chip image identification. This run directly observes hardware state.

## Outcome

**PASS_TIME_VALID_300S_BOTH_BOARDS**, for this already-running root session.
No new firmware/FPGA build, programming, reset, power-cycle, consultant request,
control/gain/threshold change or operational-script change was performed.
Frozen milestones and `/home/b10504072/04_WR_archive_step6_pass/` are unchanged.

| Board / saved capture | Valid samples | Actual sample span | Maximum gap | Verdict |
|---|---:|---:|---:|---|
| Slave, `cko-303s.log` | 359/359 | 302667 ms | 909 ms | PASS_TIME_VALID_300S |
| Master, `master-time-valid-303s.log` | 1190/1190 | 302874 ms | 257 ms | PASS_TIME_VALID_300S |

Both use the existing `step6_time_valid_300s.py`, >=300000 ms actual sample span,
>=301 numbered samples, <=1000 ms gap, exact board identity, matching DONE count,
every exported STATUS_TIME_VALID=1 and no capture errors. Reader/analyzer exits
are 0; invalid TIME_VALID rows are 0. No gap threshold or validity definition was
relaxed. Each board is analyzed independently with its actual reader/filter;
raw files are not stitched or edited to manufacture a combined capture.
Windows are sequential, not a simultaneous-clock or physical-skew measurement.

Slave capture command ran 11:34:02–11:39:07; Master 11:40:10–11:45:14 local time.
The final dashboard at 11:48:17 shows both TIME_VALID/PPS_VALID = 1, Slave all five
locks = 1, TRACK_PHASE and current CKO −48 ps. Dashboard labels are short-window
presentation: Step5 INFO/LOCK_ACQUIRED_NOT_STABLE does not negate the saved
359-row/302.667 s lock observation. No dashboard logic was changed.

## CKO versus time

![Slave CKO time series and independently sampled TIME_VALID](analysis/cko-timeseries.png)

Actual CKO-host timestamps: **11:34:03–11:39:06, Asia/Taipei**. The horizontal
axis is elapsed observer sample time in seconds, not firmware boot elapsed.
Vertical axis is picoseconds. The figure is generated from raw capture data,
not a sketch, synthetic signal or interpolated replacement dataset.

| CKO diagnostic | Result |
|---|---:|
| Raw rows | 359 |
| Guarded phase rows | 289 |
| Rejected untrusted phase frames | 70 |
| Duplicate UCNT updates omitted | 46 |
| Trusted unique updates plotted | 243 |
| Trusted-update span | 302667 ms |
| Minimum / maximum | −490 / +459 ps |
| Peak-to-peak | 949 ps = 0.949 ns |
| Median | −44 ps |
| Population standard deviation | 171.293 ps |
| Fitted slope over this observed window | −0.1741 ps/s |
| Strict abs(CKO)<60 ps | 68/243 |
| abs(CKO)<=120 ps | 131/243 |
| Maximum gap between trusted new updates | 4302 ms |
| SETP range | 2567..2975 ps |
| DMS range | 174500..175388 ps |
| State counts | SYNC_PHASE 42 / TRACK_PHASE 75 / WAIT_OFFSET_STABLE 126 |

Only rows passing the existing READS_VALID/phase/frame/epoch/context guards and
matching phase-context UCNT are admitted. Boot/reset identity is held constant;
repeated and regressed UCNT updates are not new measurements. Plot export count,
minimum, maximum and median are cross-checked against the existing analyzer.
Each line segment connects adjacent retained raw sample IDs only; omitted rows
create breaks. The CSV preserves sample ID, elapsed time, UCNT, CKO, SETP, DMS,
servo state, TIME_VALID, health and CKO host timestamp.

The TIME_VALID panel uses all 359 separate status reads, not only the 243 phase
rows. Health/time/lock and phase publications are separately acquired; this
figure does not claim single-cycle or atomic cross-domain correspondence.

**Diagnostic capture completed, but strict continuous-CKO qualification remains
INCONCLUSIVE_INCOMPLETE_CAPTURE** under the unchanged >=90% guarded-row and
<=2000 ms unique-update-gap rules: 289/359 = 80.5%, max gap 4302 ms. Trusted out-of-band
samples also directly contradict confinement of this observed series to ±120 ps.
There is no sustained ±60/120 ps accuracy PASS. A sampled TIME_VALID 300 s PASS
does not depend on CKO meeting these accuracy limits.

CKO spread is a timestamp/WR-servo diagnostic, not physical oscillator jitter.
No oscilloscope/PPS edge-skew or simultaneous physical measurement was made.
Active SETP changes show this is not the earlier fixed-SETP/no-correction run.
Compared with the historical `/0+/0` diagnostic's 929 ps peak-to-peak spread, the
present 949 ps spread is similar in magnitude but its median is near zero rather
than −6120 ps. The boots and control conditions differ: this is context, not a
causal gain/jitter conclusion. No new tuning is authorized or performed here.

## Other observed signals and data-quality qualifications

In all 359 Slave raw status rows, READS_VALID, STEP1_GATE, GLOBAL_TIME_VALID,
STATUS_TIME_VALID, STATUS_PPS_VALID, Helper/Main frequency/Main phase/Main/PSTAT
lock are 1. Reset signature `(BOOT_GENERATION,CPU_RESET_COUNT,WR_CORE_RESET_COUNT,
SI_CONFIG_DROP_COUNT)` stays `(1,1,1,1)`; RESET_CHANGED rows 0. Slave snapshot TAI
advances 53883→54186. Master 1190/1190 rows have PPS/snapshot/link prerequisites = 1
and the dedicated LIVE time fields progress monotonically.

The existing generic TIME_VALID analyzer reports Slave
`step1_link_ready_rows=0` and `live_time_monotonic=false`: the interleaved reader
uses alternate Step1 field names and lacks the dedicated LIVE_* fields that
those diagnostic calculations expect. These are not evidence of a stopped
clock or failed link. `live-state-diagnostics.json` recomputes the actual raw
STEP1_GATE counts separately. Acceptance remains the explicitly selected
STATUS_TIME_VALID signal; unsupported diagnostic fields are not changed to 1.

Both preflight and postflight are saved. Reading boards sequentially explains
why their printed TAI labels are not required to match; this observation is not
a same-PPS comparison, calibrated absolute UTC/TAI proof or physical PPS skew
test. Timing is still not closed and is not this functional milestone's gate.
The earlier failed fresh standalone acquisition remains documented: no new
cold/fresh startup was tested, so deterministic acquisition is NOT_ESTABLISHED.

## Reproduction and files

- [Raw CKO capture](raw/observe/cko-303s.log)
- [Raw Master Global-Time capture](raw/observe/master-time-valid-303s.log)
- [Slave TIME_VALID verdict](analysis/slave-time-valid-from-cko.json)
- [Master TIME_VALID verdict](analysis/master-time-valid-300s.json)
- [Guarded CKO statistics](analysis/cko-300s.json)
- [Raw status/lock counts](analysis/live-state-diagnostics.json)
- [Chart CSV](analysis/cko-timeseries.csv), [SVG](analysis/cko-timeseries.svg)
- [Chart source](analysis/plot_cko.py)

From repository root, reproduce the portable SVG/CSV:

```sh
python3 experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/analysis/plot_cko.py
```

The PNG is a 1800×1140 rasterization of this SVG. It has been visually inspected
for visible marks, axis units, reference bands, missing-row breaks and no label
clipping. SVG/CSV contain the same 243 reviewed observations. The portable chart
renderer uses only Python standard library plus the repository's existing
analyzer; PNG rasterization used the bundled local Sharp renderer.
Existing TIME_VALID/CKO analyzer tests: 16 PASS. Laptop reanalysis reproduces
Pain's saved verdicts and statistics; floating-point slope differs only by
6e-17 ps/s between Python runtimes. No SHA acceptance check was added
to the user's editable build/compile/program/dashboard workflow.

README embeds the chart near the top for the GitHub `main` homepage.
Root MILESTONES now distinguishes live-root qualification from the sealed
package and fixes its formerly stale Step6 source/SOF references using the
package's existing records; no frozen file was rewritten or resealed.
Only root documents and this evidence folder are part of the new publication.

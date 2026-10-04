# CKO diagnostic with WR fine-phase correction disabled from boot

User requested main-code change only, expressing it as acquire/0+track/0:
do not correct WR CKO, so its uncorrected variation can be observed. This is
implemented safely as `WRH_PHASE_CORRECTION_ENABLED=0` in wrh-servo.c, NOT
integer division by zero. The preserved /2 acquisition and /12 tracking
expressions are compiled OUT, together with their adjust_phase() calls.
Init/reinit's phase-setpoint trim/write is also compiled OUT. IPC tracking
enable cannot bypass these compile-time guards. To restore the intact /2+/12
behavior, set this ONE source default to1 and rebuild/program normally.

## Scope and diagnostic limits

Only production path changed: vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c.
CKO/delay calculations, update_count and publication continue. Tracking status
reports effective phase-control enable, not the ignored IPC request. Existing
60ps entry/120ps fallback,10 missed-iteration retry and timing-validity behavior
are retained; SYNC_PHASE still advances to WAIT, without pretending to wait
for a phase write it never issued. TIME_VALID may never acquire in this mode;
do not force its bit or widen thresholds to make an open-loop diagnosis PASS.

SoftPLL/DAC/PI/bootstrap/arbiter/timing constraints/PHY/reset/calibration are
unchanged. Coarse SYNC_TAI/SYNC_NSEC counter adjustments remain active. Thus
this is open-loop with respect to WR FINE phase correction, not a bare/free-
running oscillator or a physical jitter measurement. Other producers such as
manual PLL phase commands or calibration can still affect the hardware; do
not issue them during capture. No change to either frozen milestone/archive.

SETP should remain constant across trustworthy rows within one stable boot.
If a reset, reinit/lock loss/coarse correction occurs, preserve its evidence
and interpret intervals separately. A state outside3/4/5 is not a pure
fine-phase window; even fine-state samples alone do not prove absence of
between-sample coarse corrections. Lower32-bit CKO during coarse startup is
not full absolute-time offset. CKO fluctuations may reflect timestamps,
calibration, packet measurement, reference drift or live SoftPLL as well as
physical clock jitter. Correlation is not causation.

## Manual implementation workflow

Only Laptop code edit/test/push and Pain exact source pull are performed by
the assistant in this request. No firmware/FPGA build, programming, power
cycle, JTAG capture, consultant message or termination of an existing reader.
Pain's user-generated build products and active milestone dashboard are
preserved; older SOFs are NOT the new diagnostic implementation.

The user manually runs the existing four root scripts, stopping any existing
dashboard before programming:

```sh
cd /home/b10504072/04_WR
bash scripts/build/build_current.sh &&
bash scripts/build/compile_current.sh &&
bash scripts/program/program_current.sh &&
bash scripts/monitor/step1_6_dashboard.sh
```

Do not program stale output if compile/export failed. New actual SOFs will be
in output/DE5a_wr_master_jtag.sof and output/DE5a_wr_slave_jtag.sof. Root pipeline
remains editable without fixed SHA verification; milestones remain pinned.

## Optional manual CKO amplitude capture

Dashboard's10-second frames can miss fast variations. After successful fresh
programming, stop the dashboard with Ctrl+C, wait for stable link/five PLL
locks, then use ONE read-only reader:

```sh
bash scripts/monitor/observe_cko_no_correction.sh
```

Default303s Slave capture, requested500ms interval; mode2 separately epoch-
guarded CKO/state/UCNT and SETP/DMS frames, joined by equal UCNT. Actual read
times are recorded and are slower than the requested interval. Optionally
first use `DURATION_MS=20000` for a short smoke. Maximum duration900000ms.
Do not start another JTAG reader/dashboard simultaneously.

Raw and JSON are saved in this experiment's raw/observe and analysis folders.
The existing analyzer reports trusted CKO minimum/maximum/peak-to-peak,
median/stddev, descriptive slope, state occupancy, fresh UCNT count, rejected
frames, health/identity and SETP/DMS ranges. Repeated UCNT is not a new sample;
untrusted frames are excluded. The wrapper additionally reports sampled SETP
constancy and whether accepted states are fine-only. It does NOT independently
verify which firmware is loaded: only the actual fresh build/program sequence
can establish intervention provenance with current published observations.

A stopped/partial/inconsistent capture is retained, not counted as a completed
diagnostic. Complete CKO diagnostic is not TIME_VALID300s, physical PPS skew,
timing closure or precision qualification. No hardware result exists for this
candidate until the user runs it and returns the raw data.

## Offline tests

Source audit permits only the three phase guards, mode default/validation and
effective tracking-status expressions relative to the historical production
C; all other3110 baseline inputs and7 inert declarations are unchanged.
Native C test executes actual default-disabled code and tests initialization,
reinitialization, IPC toggles, threshold edges, coarse sync, PLL loss, hardware
busy, and changing measurements with no phase writes. The original22-case
reference is also tested with an explicit enabled-mode compiler override.
These are small host unit tests, not firmware/FPGA compilation or deployment.

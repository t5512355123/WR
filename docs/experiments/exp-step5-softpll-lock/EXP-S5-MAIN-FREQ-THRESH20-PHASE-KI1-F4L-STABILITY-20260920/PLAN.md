# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-20260920

## Objective

Measure whether the already direct-confirmed `threshold20 + phase-Ki1`
configuration retains Main phase lock for one 120-second F4L stability window.
This is a read-only continuation of the same live FPGA session.  It is not a
new firmware or control-parameter experiment.

## Frozen provenance

```text
source/control commit       = 26e138fdc0bfc8426704b397141d563cf4d580a2
Slave SOF                   = e149a70147c969765beb6705b4daaaacc47965354177af47be6728ef6d97c449
Slave MIF                   = 1fe50c67ac75354034fbe11c7db0924ade8a8f1ef2fa3d782c4f78c1eca75ab
control candidate            = Slave phase Ki1, Main frequency threshold20
Master                       = unchanged
program/reset/power-cycle   = prohibited in this round
PI/gain/threshold/delock    = frozen
timeout/bootstrap/arbiter   = frozen
PHY/RTL/SDB                  = frozen
```

Admission was established by the preceding direct gate (`28c603b0`):

```text
SEQ_READY                    = held
MAIN_ENABLED                 = 1
MAIN_FREQ_LOCKED             = 1
MAIN_PHASE_LOCKED            = 1
MAIN_FREQ_COUNT              = 50/50
MAIN_PHASE_COUNT             = 1000/1000
PSTAT_LOCKED                 = 1
HELPER_LOCKED                = 1
PHY/link                     = healthy
reset/generation/SI-drop     = stable
```

## Single observation

Run exactly once on the same live session:

```bash
set -o pipefail
RAW="f4l_threshold20_phase_ki1_stability_120s.log"

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l \
  2>&1 | tee "$RAW"

rc=${PIPESTATUS[0]}
echo "quartus_exit=$rc" | tee -a "$RAW"
sha256sum "$RAW"
exit "$rc"
```

The capture stops immediately at the 120000 ms target or at any observer
early-stop.  Do not append a direct gate, F4J, second formal run, reset, or
reprogramming attempt.

## Acceptance evidence

For a normal 120-second capture, verify all of:

```text
quartus_exit=0
run_end_reason=TARGET_REACHED
stop_reason=NONE
session_elapsed_ms >= 120000
MAIN_F4L_VALID > 0
unique producer frames > 0
page0/page1/page2 all observed
Helper locked throughout
PSTAT_LOCKED=1 throughout
PHY_LINK_USABLE=1 throughout
TERMINAL=0 and TERMINAL_FRESH_EDGE=0
generation/reset/SI-drop stable
Main update/sample progress
```

For functional phase-lock retention, every unique coherent Slave producer
frame must retain:

```text
BRANCH_ID=PHASE
FREQ_LOCK_AFTER=1
PHASE_LOCK_BEFORE=1
PHASE_LOCK_AFTER=1
```

For the Ki1 causal chain, page accounting must show nonzero integral motion:

```text
phase_i_count_delta > 0
phase_actual_i_sum_delta != 0
phase_ki_x_sum_delta != 0
```

Also calculate the normalized mean residual frequency, modulo phase drift,
boundary-crossing rate, and phase in-band ratio against the threshold20/Ki0
formal baseline.

## Stop and verdict rules

Any phase-lock loss, PSTAT unlock, Helper/link/reset regression, terminal fresh
edge, data ambiguity, update stall, or observer early-stop means that
120-second stable lock is **not proven**; do not rerun to compensate.

Only if the full capture and all unique-frame/accounting conditions pass may
the report state:

```text
PHASE_KI1_F4L_CAPTURE       = PASS
PHASE_KI1_LOCK_RETENTION    = PASS
FUNCTIONAL_STEP5_LOCK       = PASS
```

Even then, the top-level Step5 milestone remains subject to the repository's
timing-closure requirement; current WNS remains open (`Slave=-0.361 ns`,
`Master=-0.289 ns`).

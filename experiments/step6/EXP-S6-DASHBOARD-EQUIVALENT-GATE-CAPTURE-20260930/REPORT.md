# EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930

## Verdict

```text
STEP6_FUNCTIONAL_POINTWISE_GATE       = PASS
STEP6_DASHBOARD_EQUIVALENT_GATE       = PASS (2 consecutive sampled rows)
STEP6_PHASE_OFFSET_300S_STABILITY     = NOT_ESTABLISHED
STEP6_PHYSICAL_SMA_EDGE_SKEW          = NOT_EVALUATED
TIMING_CLOSED                         = NO (not a functional gate)
```

This experiment establishes the requested pointwise Step 6 condition: the
Slave had valid/stable Global Time, every dashboard Step 1 status prerequisite,
all five Step 5 lock indicators, and a strict `abs(CKO) < 60 ps` value in two
consecutive trustworthy sampled rows. It does **not** claim that phase offset
remained in range for 300 seconds, nor that physical SMA edges have a measured
skew. The historical same-PPS and dual-board scheduled digital-trigger gates
remain supported by the independently reproduced milestone evidence.

## Method and change boundary

- Source baseline on Pain: `7175d2e2dbcbf52dab49b75ac644b98b17ff1686`
  (`feat/file_cleanup`).
- The only hardware-facing change was read-only output/qualification in
  `scripts/jtag/read_step6_servo_interleaved_offset.tcl`; it decodes the
  dashboard's complete Step 1 status gate from the already-read probe. The
  captured CKO is the same `cko` snapshot field that the dashboard converts
  to signed `WR_SERVO_OFFSET_PS` (`0x00100A40`).
- The observer issued no Wishbone register writes, FPGA programming, reset,
  or power-cycle. Production C/RTL, servo settings, frozen SOFs, and timing
  constraints were unchanged.
- Two 15-second Slave-only smoke captures passed the predeclared reader
  quality gate before the single 300-second capture. Both used one JTAG session
  per run and preserved their raw output.
- Offline raw analysis is reproducible with
  `python scripts/analysis/step6_dashboard_gate_capture.py <capture.log>`.

## Smoke qualification

| Capture | Rows | Trusted/coherent | Row interval median | Step 1 / Global Time / all locks | Reset change | SHA-256 | Result |
|---|---:|---:|---:|---:|---:|---|---|
| `smoke_dashboard_gate_initial_20260929T204647Z.log` | 48 | 39/48 (81.3%) | 294.732 ms | 48/48 | 0 | `9d349500593545537f1120482c13cef9e5dbf8c4dd15cde838b0b9cbe1b0a3ad` | PASS |
| `smoke_dashboard_gate_20260930T204500Z.log` | 48 | 41/48 (85.4%) | 296.956 ms | 48/48 | 0 | `58c4d16e12de0e36c3f9f27ce1848abdbf7fd91234e79709b1e3ed003810c5bd` | PASS |

Both smoke captures exceeded the minimum 20 rows and 75% coherent-row ratio,
had median row intervals below 450 ms, and had no reset or invalid-read row.
Neither smoke happened to sample the strict phase-offset window.

## 300-second capture

Raw file:

`raw/observe/capture_dashboard_gate_20260929T205329Z.log`

```text
SHA-256 = 77cd9e7d770e95d484f740891e9284d4bea327ba053967d76ff442f5a5c458ab
Size    = 2,128,764 bytes
Requested duration = 300,000 ms
Observed duration  = 300,062 ms
Rows               = 958
Coherent accepted  = 854/958 (89.1%)
```

Independent row audit:

| Requirement | Valid rows |
|---|---:|
| Wishbone reads valid | 958/958 |
| Guarded diagnostic frame valid | 958/958 |
| Global Time valid | 958/958 |
| Snapshot valid and stable | 958/958 |
| Full dashboard Step 1 status gate | 958/958 |
| Helper, Main frequency, Main phase, Main lock, and PSTAT all high | 958/958 |
| Reset-signature change | 0 |
| Timeout / invalid-read count | 0 / 0 |
| Independently guarded phase-context frames joined by UCNT | 855/958 |

The strict phase-offset condition occurred in two consecutive sampled rows:

| Sample | Elapsed | CKO | Servo state | TAI / cycles | UCNT | Other gates |
|---:|---:|---:|---|---|---|---|
| 91 | 29,161 ms | +59 ps | `TRACK_PHASE` | 30432 / 123289344 | `0000708D` | Step 1, stable/valid time, all five locks, valid joined frames |
| 92 | 29,457 ms | +59 ps | `TRACK_PHASE` | 30432 / 123289344 | `0000708D` | Step 1, stable/valid time, all five locks, valid joined frames |

The two sample timestamps are 296 ms apart. This is two consecutive pointwise
observations, not proof that every instant between them—or any longer interval—
was continuously in range. Across all 958 valid CKO reads the range was
−4094 ps to +2533 ps; only 2/958 samples (0.21%) were strictly inside ±60 ps.
Accordingly, 300-second phase-offset stability remains unestablished even
though the pointwise functional acceptance is now met.

The dashboard's Step 1 gate was explicitly decoded in every capture row, and
the same gate plus valid/stable Global Time, all five locks, and strict offset
was used for the qualification marker. This is a dashboard-equivalent raw
sample, not a claim that the human-readable two-board dashboard text was
rendered at the same instant. A separate one-shot dashboard observation
earlier in the session showed the dashboard operating correctly but measured
−3779 ps and therefore did not qualify.

## Interpretation and limitations

- Step 6's functional pointwise phase criterion is met on the frozen image;
  the pointwise result does not require a 300-second phase-offset dwell.
- Step 5's separate 300-second lock result remains documented in its own
  milestone. The present capture additionally observed all five lock bits
  continuously high in its 958 sampled rows.
- This experiment does not establish why CKO moved in or out of range. The
  separately read frames are guarded and joined by publication UCNT, but are
  not simultaneous and cannot establish controller causality.
- Same digital TAI/cycle labels do not measure physical SMA/output-pin edge
  skew. No oscilloscope result is claimed.
- Timing closure remains `NO` and is not part of the functional Step 6 gate.

No further experiment or control change was performed after this capture.

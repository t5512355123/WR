# EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001

## Purpose

Replace the prior non-atomic counter-derived success trigger with direct,
source-mapped WR admission events. Determine whether a genuine Slave lock
handoff is followed by a continuous five-second observation window. This is
an observer/analyzer experiment only; it does not test phase convergence or
Step 6 offset acceptance.

## Exact hardware baseline

- Repository: `https://github.com/t5512355123/WR`
- Branch: `feat/file_cleanup`
- Prior report commit: `27d39fee30c048d865c73d3a5a09525a07ff0152`
- Fixed-SETP candidate source: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Slave `DE5 [1-11.2]` SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Master `DE5 [1-11.1]` SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`

Pinned image paths on Pain:

~~~text
artifacts/milestones/step6_global_time/source/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
artifacts/milestones/step6_global_time/source/quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
~~~

If either file is absent or its SHA-256 differs, stop before programming. Do
not compile, rebuild, substitute an image, reset, or power-cycle.

## Single permitted change

Only the passive observer, offline analyzer/tests, wrapper, and this
experiment's records may change. Production C/RTL, `wrh-servo.c`,
`wrpc-spll.c`, WR state machine, PI/gain, thresholds, timeout constants,
DMS/PTP, and SOF contents remain frozen.

Use one read-only Slave JTAG session. No dashboard/second reader, shell
command, control write, reset, or DATA_SNAPSHOT/Helper PI snapshot may overlap
the capture.

## Source-backed event contract

The event observer reads and individually brackets:

1. `0x00100A4C`: packed WR state; current state `2` and next state `4` is the
   `WRS_S_LOCK` handoff toward `WRS_LOCKED`.
2. `0x00100A4C`: current state `4` is `WRS_LOCKED`.
3. `0x00100A68`: packed TX message ID `0x1002` (`LOCKED`) with nonzero count
   is a successful local send. It does not prove the Master received it.

Each source event word has its own read-begin/read-end timestamp. For an
absence observation, both state and TX words must be valid. A matched event
is valid from its own source word. `READ_VALID`, `EVENT_EVIDENCE_VALID`,
`REQUIRED_ROW_VALID`, `CONTEXT_READ_VALID`, and `COUNTER_READ_VALID` are
reported separately. Context validity never blocks a source event. Five
consecutive invalid required rows stop the run.

The following are context only and can never trigger or stop a capture:

- sequential `POLL`, `UNLOCKED`, `CALIB_FAIL`, and `ENABLE` counters;
- their arithmetic differences (`COUNTER_NONATOMIC=1`);
- S_LOCK diagnostic tail (`TAIL_CONTEXT_ONLY=1`; matching sequence values do
  not establish an atomic/seqlock snapshot);
- RX/reject/downstream lock fields.

The low eight bits of the WR failure word are compared with the first trusted
baseline row. A value already present at baseline is not a new failure. A new
counter record is latched; stop for terminal WR exit only after three
consecutive trusted rows report inactive state (`WRS_IDLE`/`WRS_PRESENT`).
An active row or invalid state cannot erase failure evidence; an invalid row
breaks the consecutive-inactive streak.

## Capture protocol

1. Run offline regression tests and Tcl syntax/stub checks on Laptop.
2. Commit/push this observer-only change to GitHub.
3. On Pain, fast-forward to the exact commit; verify both pinned image hashes.
4. Program exact Slave, then exact Master, then immediately run the single
   Slave observer. No compile and no intervening JTAG reader.
5. The first source-backed event starts a 5,000 ms window measured from that
   event word's read-end time. If none is observed, stop at 300,000 ms.
   External watchdog is 330 seconds; no artificial post-row delay.
6. Copy raw/checksum back, verify SHA-256, analyze, update this report, push
   the evidence, and stop. Do not begin another hardware capture without a
   fresh advisor decision.

## Immediate stop conditions

- SOF hash mismatch, absent/ambiguous Slave target, or fatal Tcl/JTAG error;
- boot/reset signature changes;
- Step 1 loss after it was established;
- five consecutive invalid required raw rows;
- a new failure counter record followed by three consecutive trusted
  inactive WR-state rows.

If an event occurs, capture 5 seconds from its source-word read end unless an
immediate stop condition occurs. No event in 300 seconds is
`NO_SUCCESS_EVIDENCE_OBSERVED_300S`, not a firmware failure or Step 6 verdict.

## Interpretation limits

The output is timestamped sampled evidence, not same-cycle causality. A local
`LOCKED` send is not proof of receipt at Master. Counter deltas cannot
establish `locking_poll()` success. This experiment does not establish the
Step 6 stable-offset gate.

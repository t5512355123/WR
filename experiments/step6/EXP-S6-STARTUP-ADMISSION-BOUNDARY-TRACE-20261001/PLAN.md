# EXP-S6-STARTUP-ADMISSION-BOUNDARY-TRACE-20261001

## Purpose

Locate the first inactive boundary in the Slave startup/admission chain after
the latest fixed-SETP ARMING capture ended without Step 5 readiness. This is a
read-only boundary trace; it does not test phase convergence or Step 6 offset
acceptance.

The prior run (`20260930T161852Z`) lasted 300,116 ms, remained in `SSTAT=1`,
and had zero rows with all five Step 5 lock gates high. It was correctly
classified `INCONCLUSIVE_STARTUP_NOT_ARMED`. The original Pain log and local
copy match SHA-256
`449cc3c0d82c32ee5a0f96d59c138c553a88029f87008793daa7f021c344188d`; the
previous report/manifest transcription was corrected without changing the raw
bytes.

## Exact baseline

- Repository: `https://github.com/t5512355123/WR`
- Branch: `feat/file_cleanup`
- Evidence baseline: `b7c32357a9326d6e72e50d54ec3a71a6df76e17a`
- Observer/source baseline used to build the pinned images: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Slave `DE5 [1-11.2]` SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Master `DE5 [1-11.1]` SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`
- Expected existing files on Pain:
  `artifacts/milestones/step6_global_time/source/quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
  and the corresponding `output_files_master_jtag/DE5a_wr_master_jtag.sof`.

The checked-in frozen milestone copies at
`artifacts/milestones/step6_global_time/{slave,master}.sof` have different
hashes and are **not** substitutes for these pinned experiment images. If the
two exact-hash files are missing, stop before programming; do not rebuild or
copy another image into their place.

Use only these existing images. Do not rebuild, substitute another SOF, change
the production firmware/RTL, reset, or power-cycle.

## Single permitted change

Add this experiment's passive observer, offline analyzer/tests, and records.
No changes to servo control, PI/gain, threshold, DMS/PTP behavior, bootstrap,
arbiter, timeout behavior, RTL, SDB, or functional registers.

The observer uses the established `read_wb_runtime.tcl` read-only mailbox
reader and a single Slave JTAG session. It never requests a Helper PI snapshot,
never requests a DATA_SNAPSHOT, and has no automatic dashboard or phase-smoke
follow-on.

## Source-mapped fields

Signal meanings and packing were checked against the source snapshot at
`9c9afa345c1de03760ec9ee07eb742888c3fa8fe`, its `task-diags.c` packing, and
`docs/debug/jtag_register_map.md`. The observer preserves raw words and emits
independent start/end timestamps for each non-atomic group.

| Group | Read-only fields |
|---|---|
| Health | Direct-probe Step 1 status; boot/reset signature; Helper, Main, PSTAT state words |
| Admission | PTP state/meta and RX/TX counts; Ethernet RX/TX counts; WR RX/TX signaling, state, failure/reject; lock result, enable, poll, unlocked, calibration-fail counts |
| SoftPLL | mode, sequencer/alignment, state-visit mask, transition/last-state, init/clear-DAC counts, Helper/Main enabled and lock state, Helper ref source/count/threshold/sample count/error/output, HPLL/Main DAC words |
| Event chain | DMTD REF/FB accepted counts (`0x0010022C/230`), post-CDC REF/FB events (`0x00100298/29C`), TAG, TRR write/pop, IRQ, Helper update |
| Phase publication | Guarded primary CKO/SSTAT/UCNT and separate guarded UCNT/DMS/SETP context; rows join by equal UCNT |

Main state packing is from the pinned source: enabled bit 0, locked bit 1,
frequency-lock bit 2, phase-lock bit 3. Helper ref source is bits 15..8 of the
Helper state word; its lock accumulator is bits 31..16. Existing thresholds
are read-only. The Step 1 gate uses the runtime dashboard's exact expectations:
status bits 0, 1, 2, 3, 6, 7, 15 and high-word bit 0 must be 1; reset/error
bits 11..14 must be 0. Main enabled is also required for the startup-ready
stop, so retained lock bits while Main is disabled cannot stop the trace early.

The phase frames are publication-guarded and UCNT-joined. Other groups are not
atomic with one another or with those frames; their host timestamp brackets
must not be described as same-cycle causality.

## Capture protocol

1. Laptop runs offline tests, commits, and pushes the observer/report plan.
2. Pain fast-forwards to the pushed commit; verify both SOF hashes again.
3. Do not compile. Program the exact existing Slave SOF, then the exact Master
   SOF, and immediately start `run_startup_admission_trace.sh` in the same
   operational session. Do not run a dashboard or second reader in between.
4. Capture at most 300,000 ms with a requested 250 ms post-row delay. The
   observer records actual row spacing and each group’s start/end time.
5. Transfer the raw log and wrapper checksum to Laptop, verify bytes, analyze,
   write the result, then push the report/raw manifest.

Manual programming order is Slave → Master. The Tcl observer itself targets
only the unique `1-11.2` Slave hardware name.

## Stop conditions

Stop immediately on:

- pinned SOF hash mismatch, no/ambiguous Slave identity, or missing device;
- reset signature change or fatal Tcl/JTAG reader exception;
- five consecutive structurally untrusted original phase/health rows;
- five consecutive invalid rows in any required ADMISSION, SPLL, or EVENTS group;
- a trusted `SSTAT` state 3, 4, or 5 (save the boundary and stop; do not run a
  smoke or phase diagnostic);
- Step 1 plus Main enabled and all five Step 5 lock gates continuously healthy
  for at least 10,000 ms and at least 10 rows (record startup recovery and stop);
- 300,000 ms elapsed.

Lock-low, UCNT decrease, or large CKO alone are not stop conditions. Counter
deltas use unsigned 32-bit rollover only when the endpoints are near opposite
ends of the range; unexplained decreases are discontinuities, never negative
progress.

## Offline validation and interpretation

Required before Pain:

- Python unit tests pass.
- Tcl syntax/procedure load succeeds with hardware APIs stubbed.
- Bash syntax and `git diff --check` pass.
- Read-only source mapping and pinned image hashes are unchanged.

The analyzer may identify a *candidate* first inactive counter boundary or
classify the startup trace as inconclusive. It must not claim single-cycle
causality, phase-controller failure, or Step 6 PASS. If lock readiness returns,
this experiment stops at that boundary; a later advisor decision is required
before a phase experiment.

## Status

~~~text
IMPLEMENTATION = COMPLETE
OFFLINE_TESTS = 8/8 PASS
TCL_PARSE_AND_STEP1_SEMANTIC_STUB = PASS
BASH_SYNTAX = PASS
PAIN_PULL = PASS (423c276e7c48724c173498c2259841f9d443eaa0)
SOF_HASH_PREFLIGHT = PASS (BOTH EXACT SHA-256 MATCH)
SOF_PROGRAMMING = PASS (SLAVE THEN MASTER; NO COMPILE)
HARDWARE_CAPTURE = COMPLETE (STOPPED AT PHASE_STATE_BOUNDARY, 56.430 s)
RAW_TRANSFER_AND_SHA256 = PASS
REPORT = COMPLETE
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

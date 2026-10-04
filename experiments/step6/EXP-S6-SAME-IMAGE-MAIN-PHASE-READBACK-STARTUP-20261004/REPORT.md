# Identical-configuration startup failure reproduced with Main progress

2026-10-04, Asia/Taipei. This experiment preserves a new unfavorable boot;
it does not promote another retry as a reproducible Step6 milestone.

## Verdict

- `PASSIVE_MAIN_READER_HARDWARE_SMOKE = PASS`.
- `ROOT_BUILD_COMPILE_PROGRAM = PASS`.
- `FPGA_CONFIGURATION_EXACT_MATCH = PASS`.
- `INITIAL_IMMEDIATE_OBSERVER = INCONCLUSIVE_UPSTREAM_NOT_READY`.
- `SAME_BOOT_600S_TIME_VALID_ACQUISITION = NOT_ACQUIRED`.
- `TIME_VALID_300S = NOT_RUN_ENTRY_GATE_NOT_REACHED`.
- `MAIN_UPDATE_STALL_AS_SOLE_CAUSE = NOT_SUPPORTED`.
- `PERSISTENT_PHASE_SHIFTER_BUSY_AS_SOLE_CAUSE = NOT_SUPPORTED`.
- `DETERMINISTIC_STARTUP = NOT_ESTABLISHED`.
- `PHYSICAL_CAUSE_OF_BOOT_DEPENDENT_CKO = NOT_YET_IDENTIFIED`.

Both the historical successful root run and the failed independent milestone
run remain unchanged. The canonical milestone and protected archive were
not modified. A known-successful snapshot is not a guarantee of fresh-boot
acquisition. No advisor, power-cycle, calibration force/load/set, phase write,
gain/threshold/control change, forced-valid bit, automatic reprogram or role
exchange was used.

## Scope, provenance and tests

Laptop observer/analyzer/tests were pushed first; Pain pulled exact source
`640436ca7c81bfb5fa622f04166f7bf743f263c5` on `feat/file_cleanup`.
Controls remain the qualified root: Master bootstrap2048/account64/reverse1;
Slave Main Kp300/Ki1/physical step16; WR acquisition/2, tracking/12, legacy
60/120ps. All3117 production inputs were checked before and after compilation
against manifest418bb254. No production C, RTL, SDC, QSF or MIF changes.

Only observational code changed: optional passive F4L v1 Main readback, its
bounded runner, analysis and offline tests. Existing reader defaults remain
unchanged. Main and servo groups have independent epoch guards and host
timestamps; they are not atomic. The ideal target calculated from SETP is
an arithmetic model, not the actual target register. Main current is a
firmware pre-shifter-update publication, not measured physical phase.

Laptop Python46/46 cases passed, including11 Tcl-mock cases. Pain Python
executed35 cases with11 explicitly skipped because tkinter is absent; this
is not46 executed hardware/server tests. Actual Quartus-native Tcl12 cases
passed (`hardware_access=0`); actual production-servo native C22 cases under
UBSan passed. Bash syntax and scoped source-diff checks passed.

## Smoke on the already-successful boot

Record `raw/20261004T015045Z-smoke/`,09:50:45–09:51:07. This preserves the
previous09:06 successful boot; no programming or control mutation.
20.182s bounded smoke:31 raw rows,25 accepted, Main8/8 valid frames,7 positive
same-identity update intervals. All5 matched servo-publication pairs have
current equal to the ideal SETP quantization. This validates the passive
reader, not fresh startup or a new300s qualification.

All4 smoke files checksum-matched independently on Laptop; its recomputed
analysis exactly equals the Pain JSON. SHA256:

| File | SHA256 |
|---|---|
| acquisition.log |35122b5160b35ffc88b42a6107b95c1c2c6e12a376b78591d44396f8f72d02ef|
| acquisition.json |e8c69b03d6c761d40a44714fd5d1eb04039f21816e71d8b507ce6456b44eaa52|
| native-tcl-tests.log |825921704e476931e6de3a5adf70bfab3f36eef26e7dc23d1295dbca4bdc6a9f|
| session.log |1aa1c760ec45a544726becc7f3b842b70061fd393d186f883d57973ff789e746|

## One actual root build/compile/program pair

Record `raw/20261004T015209Z-replay/`, began09:52:09. Full firmware build,
Master compile through09:56:39 and Slave compile through10:08:23 succeeded.
The longer Slave fitter remained active; it was not restarted.

| Artifact | SHA256 |
|---|---|
| New Master SOF |6f826945757c565efac1439464e9ce5c8b23553285f2f27394757d8f6bb15cbf|
| New Slave SOF |e4e3f7a6b312446c1f3a0fca0efca7ad2841267a3f7529c7b7f4e0db19fc095f|
| Master RBF |8e5f1ab2c0c44376493f5ff1dedc50c3e6423835e7f96de42ceda96758007f09|
| Slave RBF |886650e7345968e1739087d3e82fb054caa31950d0eb0f7657e97b148ba908dc|

RBF hashes were checked BEFORE programming and equal both the successful
root and failed independent milestone configuration. Different SOF metadata
does not explain different acquisition. Root `build/` and `output/` now
contain THESE actual compile products; neither they nor this run are a fresh
300s PASS. All53 tracked root products are saved in `root-products.tar.gz`.

Actual Slave programming ended10:11:28, Master10:11:47. The earlier10:08:40
PROGRAM_BEGIN includes authentication wait; it is not the FPGA programming
completion time. Only one programming pair occurred.

### First immediate observer: preserve, do not misclassify

The immediate reader exited normally with5 structurally invalid rows and
`FIVE_CONSECUTIVE_STRUCTURALLY_INVALID_ROWS`, total3361ms. No trusted servo
publication or Main frame was obtained. Normal process exit is not valid
hardware data. Preserve `acquisition.log` and `acquisition.json` as
INCONCLUSIVE, not a phase-acquisition failure or PASS.

The wrapper's readonly terminal queries/dashboard ended10:12:34. At this
early point both boards had RX/TX ready but link/TM=0; Slave PLL/startup was
not ready. Master TIME_VALID=1 nevertheless. No retry/program followed.

### Later read-only continuation in this SAME boot

After the first wrapper released JTAG, the same existing startup reader ran
again, with Main readback enabled. No image, programming, reset, clock or
control changes. Link had recovered by this continuation's observation.
This is a later same-boot window, NOT a continuous trace from firmware boot;
observer elapsed must not be reported as boot elapsed.

`acquisition-same-boot-continuation.log` ended normally at DURATION_LIMIT:
arming10492ms, acquisition600210ms, total610702ms. Process RC0 was preserved.

| Measurement | Result |
|---|---:|
| Raw servo rows |923|
| Accepted guarded servo/context rows |789|
| Unique UCNT updates |545|
| Unique state3 / SYNC_PHASE |49|
| Unique state5 / WAIT_OFFSET_STABLE |496|
| TRACK / valid-time accepted rows |0 / 0|
| CKO, observed phase-labelled ps |−2740..+4292|
| SETP ps |5088..7472|
| DMS ps |176198..181032|
| Smallest sampled abs(CKO) in WAIT |177ps|
| Trusted adjacent SYNC→WAIT /2 arithmetic matches |35/35|
| Negative signed32 conversion-risk updates |0|

All789 accepted rows had Step1 and all five Slave lock flags1. Observed
generation, CPU-reset, WR-reset and SI-drop identities stayed00000001;
RESET_CHANGED=0. This does not establish every-cycle state in unobserved
intervals. The phase-labelled CKO alone is not a pure physical-jitter metric.

### Main executed while WR time remained invalid

Main231/231 frames passed their independent publication/source guards.
All230 same-init/producer intervals progressed (minimum7246 updates), total
2319210 Main updates. Of152 matched servo-publication pairs,138 have current
equal to ideal SETP units.124 of those are WAIT with CKO−2614..+4100ps.

14 modeled mismatches range−2052..+1309 units. Separate publication timing
and transient shifter movement preclude treating these as a proven persistent
target defect. Publication agreement does not make Main/servo atomic, nor
does ideal target equal an actual target-register read.

After releasing the reader, existing `pll stat` / `pll gps 0` queries ran
10:25:51–10:26:32, full replies statusOK. The actual Slave current/target were
**5312/5312ps**. Thus the phase shifter was not busy at THAT readback. Do not
equate the earlier `pll stat` raw-unit setpoint5740 with this later ps value.

Final one-shot dashboard through10:27:16: Slave all five locks1,
WAIT_OFFSET_STABLE, CKO−2317ps, TIME_VALID/PPS_VALID0. Master valid. Both CRs
20000006: source `shw_pps_gen_busy()` says bit2=1 means counter adjustment
not busy. These observations reject a continuously stuck Main/PPS busy path
as the sole explanation; they do not prove all requests physically settled
at all packet times.

## Calibration readback: new unfavorable-boot evidence

These are sequential query groups, not atomic packet-correlated records.

| Field | New unfavorable boot | Previous09:06 successful boot |
|---|---:|---:|
| Master active T24P ps |2389|2389|
| Master ptracker phase ps |1448|6939|
| Slave active T24P ps |6800|7150|
| Slave ptracker phase ps |5576|5971|
| Slave scan rising/falling ps |6800/2800|7300/3000|
| Slave GPS current/target ps |5312/5312|7811/7811|

Master scan remains unstarted/default-valued. This does not prove missing
storage or an incorrect2389ps value. Slave scan completed (state2/count5,
phase9500), but measured transitions and active runtime phase differ under
identical configuration. The350ps T24P difference is correlation, not an
established cause of the several-ns CKO behavior.

Source audit narrows the next boundary toward RX timestamp coarse/fine
continuity, phase-tracker freshness/calibration and their WR arithmetic.
For example accepted updates sample62→63 preserve SETP5698ps while CKO moves
−395→+3245ps and DMS176341→180449ps. This is an observed packet-time/offset
change without an observed WR setpoint write; groups are not cycle-atomic
and physical causality is not established by this example alone.

The current pinned firmware has neither the newer RXTS/TS4/PHIST shell
commands nor CONFIG_CMD_LL / CONFIG_CMD_CALIBRATION_SHOW. Those historical
readers cannot retrieve packet histories from THIS image. Do not run the
argument-free `calibration` command: it can start measurement if no stored
value exists. No guessed addresses, fabricated packet data or production
diagnostic changes were made to obtain them.

The CPU upload CSR is not a live-RAM read workaround: source
`wrc_urv_wrapper.vhd` selects its host memory address only while CPU reset is
asserted; while running, UDATA reflects instruction-port activity instead.
Halting/resetting the CPU to read this RAM would destroy the preserved
acquisition state. No upload/debug/reset registers were used.

## What is now explained, and what remains

The apparent contradiction is partly source-proven: initial WR acquisition
must pass legacy<60ps before enabling timing; five PLL locks do not suffice.
Once enabled, TRACK>120ps fallback does not clear existing validity. A boot
that briefly acquires the gate can therefore retain TIME_VALID300s while a
different boot of the same image remains in WAIT. This is an acquisition
versus retained-validity distinction, not evidence of changed SOF payloads.

The new capture reproduces an unfavorable boot and excludes missing Main
progress and continuously stuck phase requests as sole causes. It still does
not identify the underlying physical/timestamp/calibration cause. The
original midnight failed boot was destroyed by later user programming;
this new boot is preserved instead of claiming to reconstruct that lost
state. Further read-only access must be source-proven; no blind gain sweep,
guessed calibration or success-only archive promotion is justified.

## Evidence transfer and synchronization

All30 replay files in TRANSFER_SHA256SUMS independently hash-match on Laptop.
The independently rerun acquisition analyzer exactly equals the complete
Pain JSON. Four smoke files also match as above. Transfer archive SHA256
2402d3ea5f637e77900d25d82ce90801de0f55682e28e7dfd4db3b75dd30b76e.
Root-product extraction was restricted to the exact53 tracked build/output
paths; unrelated changes and old evidence were preserved. Product publication
hashes64/64 and production-input hashes3117/3117 also match on Laptop after
extraction. All46 Laptop tests were rerun successfully. Report/products are
pushed from Laptop before Pain synchronization. The unfavorable hardware
boot is left running with no competing JTAG reader. Diagnosis remains active.

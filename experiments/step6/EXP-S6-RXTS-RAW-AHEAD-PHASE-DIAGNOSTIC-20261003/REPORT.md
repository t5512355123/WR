# RXTS packet diagnosis — completed, strict Step6 NOT_ESTABLISHED

Baseline and rationale: see PLAN.md. The preceding strict660s result was
NOT_ESTABLISHED; current control/validity behavior is unchanged.

Laptop source `fb3a5bce`, test repairs `8778537b`/`62c82492`, pushed before
Pain pull. A native test initially failed because the firmware include path
shadowed the host assert.h; fixed by quote-only include paths, before build
or programming. Original failed log is retained rather than suppressed.

Offline outcomes:

- Laptop 48 tests: OK, one skip (no native C compiler); following addition
  includes a production-function comparison test, skipped on Laptop.
- Pain actual recorder C with UBSan: PASS, immutable input, filtering,
  field packing, ring overwrite, frozen pages, bounded response size.
- Pain actual entire WR servo C with UBSan: 35 cases PASS.
- Pain RXTS tests: 10 OK, four skips (Tk unavailable). Actual unchanged C
  linearizer compared to Python decoder for96000 combinations: three T24P
  values, both ahead states, all8000 phases and two raw nanosecond positions.
- Fresh firmware source `62c82492a72d08dbf9d019110f358d1e511759ce` succeeded.
  Master MIF: `3f18256245691266d02536efd8a85848bf7b6aad2651fe81f644fb8c6e44eaba`;
  Slave MIF: `fb2837b211b488f44a017ccf9ac6f7f3eddfbdf51daa0ee20fcc13b5877b9e2c`.
  text+data+bss:147172 /147132 bytes within196608-byte memory.

## Actual build/program

Both full FPGA compiles succeeded from
`13d5c99b2b1898cf9cd9d9864288f7f9d5cccccf`, ending2026-10-03T00:57:55+08:00.
Slave then Master programming succeeded, Master end01:00:22. Metadata/analysis
changes `05094845`/`1b8e6bfe` were pulled only after both compiles completed;
they change no firmware/HDL inputs. Export was repeated to refresh the entire
publication checksum list, including read-only milestone SOF checksums.

| Role | Actual new root SOF SHA256 |
|---|---|
| Master | `eb3d3b26e286f93d3ec2bd974e2e4127d2ed1c99c733cc54e6ce7f0cf470219e` |
| Slave | `0d98393444d4a6af3840616c723b84fcad6df21b40368ecd37b79cc89b7e1fca` |

These products are retained in root build/output. Both MIF pins matched.
Timing remains open (Master setup+0.192ns, Slave-0.659ns); no timing-closure
claim or constraint change. Frozen milestone/archive unchanged.

The first dashboard (+40s after Master program) found Slave PLL acquisition
still incomplete. The subsequent90s strict preflight had all final link/lock
gates established:256 rows,246 trusted, CKO-3441..+3926ps; three fresh strict
entries, longest qualified span2669ms (three updates), no VALID-outside120
row, no transport/reset errors. It is NOT a300s test or PASS.

## Packet capture results

`raw/observe/20261002T170607Z-rxts-packets.log`: one frozen32-record history
per board,169414ms actual serial query session. No stop/transport error;
all16 pages complete with consistent IDs/counts; live health checks passed.
Data-only verdict: PASS_DIAGNOSTIC_DATA_ONLY, not clock-accuracy PASS.

| Metric | Master | Slave |
|---|---:|---:|
| Stored / correct records |32 /32|32 /31|
| Message types |32 Delay_Req|8 Sync,9 Follow_Up,15 Delay_Resp|
| Active T24P ps |2389|7250|
| Raw tracker phase ps |2035..3888|5372..6739|
| Selected branch, correct records |32 falling|31 falling|
| Ahead bit1 /0, correct records |11 /21|15 /16|

Every correct stamp reproduces the unchanged C linearization exactly. This
rules out a decoder-arithmetic error in these rows; it does NOT validate the
physical ahead bit, calibration or coarse timestamp. There was no branch
switch in this history. The roughly8ns changes in linearization correction
when ahead changes can be normal coarse/fine compensation, not proof of a bug.
Master's default T24P remains unmeasured; do not copy Slave's value into it.
The new Slave auto-calibration value differs from the previous session's7050ps.

Eight unique same-source/port/domain/sequence Sync--Follow_Up pairs gave
pre-servo linearized T2 minus wire T1 =182149..183489ps (range1340ps); adjacent
captured pair changes -603..+300ps. This is NOT servo CKO: it includes offset,
path delay and calibration/correction conventions. Master and Slave histories
are from different windows; no matched four-timestamp RTT/CKO causal claim.
Console querying can perturb main-loop scheduling, although each page-zero
RAM history is frozen before that board's page output. General-message local
RX timestamps are not used as T1/T4; those values come from wire bodies.

Postflight dashboard retained Master valid time and both usable links with
all five Slave locks1, Slave still WAIT_OFFSET_STABLE/invalid. A separate20s
strict postflight obtained56/56 trusted rows, CKO-3257..+2779ps, no entry,
no VALID-outside120, no reset/transport errors. No JTAG reader left running.

## Interpretation and next direction

Strict validity revocation works; repeatable fine-offset convergence remains
NOT_ESTABLISHED. Nothing here isolates Ki as the cause. RX timestamp math and
same-branch operation are consistent, but raw phase also moves while WR is
actively correcting setpoint, so this alone is not uncontrolled PLL jitter.

Next useful controlled intervention: a bounded first-qualified-entry fixed-WR-
setpoint diagnostic on this exact control baseline, retaining fresh PTP/CKO
updates and strict output revocation. Do not tune gains simultaneously. First
audit/guard all phase-write paths and define reset/reinit/state exit stops;
do not infer fixed hardware phase from boot generation alone. Compare constant
SETP invariance, raw timestamp movement and fresh measured offset after entry.
This remains a proposed next experiment, not a result or production fix.

No timestamp selection/calibration/gain/RTL changes; no advisor messages.

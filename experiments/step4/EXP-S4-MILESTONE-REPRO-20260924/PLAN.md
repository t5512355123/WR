# EXP-S4-MILESTONE-REPRO-20260924

## Objective

Reproduce the first independent Step 4 SoftPLL-startup checkpoint from a
standalone frozen source snapshot on Pain. This is not a Step 5 lock test.

## Candidate and provenance

- Candidate source commit: `a1980bff30231376a3182486fd786d906876c2d4`.
- Historical experiment: `experiments/legacy/exp-step5-softpll-lock/EXP-S5-F4B-ARBITRATION-CONTROL-20260915/`.
- Historical Master SOF SHA-256:
  `ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400`.
- Historical Slave SOF SHA-256:
  `ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092`.

The candidate report records Master and Slave clean full-compilation and JTAG
programming PASS, plus a settled Slave Step 4B PASS after the upstream PTP
state became valid. The source package must be independently rebuilt; the
historical SOFs are not the programming inputs for this reproduction.

## Frozen-source construction

`artifacts/milestones/step4_softpll_startup/source/` is copied from the
candidate source commit. The JTAG project is flattened into `quartus/`, the
generated PHY tree is placed under `quartus_generated/`, and only the SI5340
controller RTL required by the JTAG QSF is retained. The QSF and firmware-init
paths are relocated mechanically to match those directories. Functional HDL,
firmware, vendor sources, and generated IP must remain byte-identical to the
candidate commit. RS422 projects and unrelated experiment material are not
part of this milestone source.

## Laptop → GitHub → Pain

1. Commit and push this candidate source, build instructions, and plan on
   `feat/file_cleanup`.
2. On Pain, fast-forward pull that commit and run
   `cd artifacts/milestones/step4_softpll_startup/source && sha256sum -c SOURCE_SHA256SUMS`.
3. Build Master and Slave firmware from `source/firmware/`.
4. Run the isolated source's clean Quartus build scripts for Master and Slave.
5. Save logs, tool version, source and image hashes under this experiment's
   `raw/build/`.
6. Program the rebuilt images using the historical order for this candidate:
   Master, wait approximately 45 seconds, then Slave. Save independent
   programming logs under `raw/program/`.
7. Run read-only Step 1–4 runtime captures; do not issue Wishbone writes,
   restart PTP, reset, or power-cycle.
8. Return raw logs to Laptop, analyze every acceptance gate, update REPORT,
   freeze rebuilt images only if acceptance passes, and push the evidence.

## Runtime acceptance and stop conditions

Capture both boards after startup settling. Require on both boards:

- PHY/RX/TX readiness and WR link healthy.
- Endpoint/PTP prerequisites valid; persistent RX encoding errors absent.

Additionally require on the Slave:

- WR handshake / parent signaling PASS.
- `STEP4B_ALLOWED=YES`, `STEP4B_RESULT=PASS`, and first inactive boundary
  `ACTIVE`.
- `LOCK_ENABLE_COUNT` and `SPLL_INIT_COUNT` nonzero, `SPLL_MODE=SLAVE`, and
  sequencer outside its disabled/reset state.

Across a fixed before/after observation window, require positive deltas for
DMTD accepted, TAG, TRR write, TRR pop, IRQ, and helper update. Require no
boot-generation, CPU reset, WR-core reset, SI-configuration drop, or link-loss
delta. Preserve raw readings and avoid interpreting unrelated/non-atomic
fields as same-cycle causality.

If the upstream gate is not valid, wait once for the documented startup
settling interval and repeat a read-only preflight. If still invalid, stop and
report `NOT_PASS` with the first inactive boundary; do not proceed to Step 5.
If source identity, build, or programming is inconsistent, stop before runtime
acceptance. A successful compile or programming operation alone is never PASS.

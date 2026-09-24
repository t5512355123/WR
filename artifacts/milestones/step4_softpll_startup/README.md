# Step 4 — SoftPLL startup

**Verdict: `PASS`**

This frozen, standalone JTAG source was clean-built for Master and Slave,
programmed to the two DE5a boards, and passed the Step 4A/4B runtime acceptance.
This milestone establishes SoftPLL startup and event processing only; it
does not claim Step 5 lock or timing closure.

## Source and historical provenance

- Historical source commit: `a1980bff30231376a3182486fd786d906876c2d4`.
- Frozen package commit used for build/program:
  `393f402c6af420b45e9ffa1f0b936cdfd017982c`.
- Historical experiment: `EXP-S5-F4B-ARBITRATION-CONTROL-20260915`.
- Historical Master SOF SHA-256:
  `ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400`.
- Historical Slave SOF SHA-256:
  `ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092`.
- Rebuilt Master SOF SHA-256:
  `55cb04191f3e0793623a55ada6c9e842b6d92d26ba196f1b057c5d5595d57717`.
- Rebuilt Slave SOF SHA-256:
  `b6b87623d8c7cb4660a04e97bd7a0ce5792783fdd3e6d04a64880307bb26612e`.
- The historical report records Step 4B PASS, but Step 5 did not complete.

The `source/` tree is a standalone JTAG-only snapshot.
Only project-path relocations required by the current repository layout may
differ from the historical source; those differences and their hashes will be
listed in the reproduction report. No functional RTL or firmware change is
authorized as part of this Step 4 reproduction.

## Reproduction result

- Quartus 17.0.0 Build 595 clean full compilation: Master PASS, Slave PASS.
- Programming: Master on `DE5 [1-11.1]` PASS; Slave on `DE5 [1-11.2]` PASS.
- Runtime: Step 1 and Step 2 PASS on both boards; Slave Step 3 handshake PASS;
  Master Step 4A and Slave Step 4B PASS.
- In the read-only before/after capture, DMTD accepted, TAG, TRR write/pop,
  IRQ, and helper-update counters all advanced on both boards.
- Boot generation, CPU reset, WR-core reset, and SI-configuration-drop counts
  remained unchanged. JTAG/Wishbone transport validation passed.
- Step 5 was not passed (`MAIN_PHASE_LOCK` was the first inactive boundary on
  the Slave); this is outside the Step 4 acceptance boundary.

The complete build, program, and observation logs and detailed verdict are in
`experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/REPORT.md`.
The milestone-root SOF hashes are recorded in `SHA256SUMS`.

## Acceptance

The rebuilt images must demonstrate:

- Step 1 and Step 2 prerequisites PASS on both boards.
- Slave Step 3 WR handshake PASS and Step 4B gate allowed.
- Master Step 4A and Slave Step 4B SoftPLL startup active.
- In a fixed observation window, DMTD accepted events, TAG, TRR write/pop,
  IRQ, and helper-update counters all advance.
- Reset, boot-generation, link, and SI-configuration stability checks remain
  unchanged over the observation window.

Step 5 lock/convergence and timing closure are not Step 4 acceptance gates.
Timing closure was not achieved and is explicitly not claimed here.

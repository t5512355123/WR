# Step 4 — SoftPLL startup

**Verdict: `PENDING_REPRODUCTION`**

This directory is a candidate frozen-source package only. Do not treat it as
an accepted milestone until both images have been rebuilt from this source,
programmed onto the two DE5a boards, and the Step 4 runtime acceptance below
has passed. Historical Step 4B evidence is provenance, not a substitute for
this reproduction.

## Candidate provenance

- Historical source commit: `a1980bff30231376a3182486fd786d906876c2d4`.
- Historical experiment: `EXP-S5-F4B-ARBITRATION-CONTROL-20260915`.
- Historical Master SOF SHA-256:
  `ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400`.
- Historical Slave SOF SHA-256:
  `ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092`.
- The historical report records Step 4B PASS, but Step 5 did not complete.

The `source/` tree is being reconstructed as a standalone JTAG-only snapshot.
Only project-path relocations required by the current repository layout may
differ from the historical source; those differences and their hashes will be
listed in the reproduction report. No functional RTL or firmware change is
authorized as part of this Step 4 reproduction.

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

## Build and hardware reproduction

See `experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/PLAN.md` for the
reproduction procedure and evidence. Rebuilt SOF hashes, programming results,
runtime captures, and final verdict will be added only after those operations
complete.

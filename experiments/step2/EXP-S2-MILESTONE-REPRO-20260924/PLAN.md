# Step 2 milestone reconstruction — plan

## Objective

Rebuild Step 2 from its own frozen JTAG source, program the freshly rebuilt
Master and Slave images, and validate the Endpoint / MiniNIC / PTP packet
path on the two DE5a boards. This checkpoint includes Step 1 PHY/link health,
but does not claim Step 3 WR signaling, SoftPLL lock, or global-time success.

## Candidate and historical evidence

- Historical experiment: `EXP-WRPC-STEP2-DCO-RESTORE-20260819`.
- Exact historical build source commit: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
- Functional DCO handshake change recorded by that experiment:
  `a427ed3f61a54a704c46cf1e0f650ef591f35de1`.
- The historical report describes fresh firmware and Quartus builds,
  successful Master/Slave programming, and Step 2 runtime acceptance.
- Its referenced Pain build/program/runtime directory is no longer present;
  therefore the historical report is candidate-selection evidence only. This
  experiment will produce new, locally retained raw evidence before any PASS
  verdict or official milestone is created.

## Frozen candidate construction

Use the exact source tree at commit `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
Create a self-contained candidate under `candidate_source/`, retaining the
historical JTAG top-level entities and functional source. Only relocate paths
needed for independent compilation:

```text
quartus/jtag_runtime_diag/*             -> quartus/*
generated/work_wrphy_full/*             -> quartus_generated/work_wrphy_full/*
rtl/clock/si5340_controller/*            -> quartus/si5340_controller/*
../../vendor/                            -> ../vendor/
../../generated/work_wrphy_full/         -> ../quartus_generated/work_wrphy_full/
../../rtl/clock/si5340_controller/       -> si5340_controller/
../../build/firmware/{master,slave}/wrc.mif -> ../build/firmware/{master,slave}/wrc.mif
```

No functional RTL, firmware, pin, clock, reset, PTP, or SoftPLL changes are
allowed in this reproduction. Audit every QSF/QIP dependency and confirm the
two top-level entities remain `DE5a_wr_master_jtag` and
`DE5a_wr_slave_jtag` before pushing the candidate for Pain.

## Build, program, and observation

1. Push the candidate and this plan to `feat/file_cleanup`.
2. On Pain, pull that exact commit; verify the candidate manifest and record
   Quartus/toolchain versions and source hashes.
3. Clean-build firmware and Quartus Master and Slave from `candidate_source/`.
   Retain complete logs and fresh SOF/MIF hashes.
4. Program the fresh Master image to `DE5 [1-11.1]`, then Slave to
   `DE5 [1-11.2]`, matching the historical Step 2 procedure. Record the full
   programmer output and image hashes. No power cycle or cable change is
   planned.
5. Run the candidate's read-only JTAG runtime capture after programming:
   one snapshot plus a 30-second time-series. Save raw output and analyze only
   accepted, internally consistent frames; retain rejected/retried frames as
   evidence rather than counting them as accepted samples.

## Step 2 acceptance

Both boards must retain Step 1 link health, released CPU, no firmware fault,
and their expected endpoint identities. During the 30-second accepted sample
window:

**Master (`DE5 [1-11.1]`):**

- `MODE=2`, `PTP=6` (`PPS_MASTER`).
- MAC `02:00:22:33:44:01`.
- MiniNIC and PPSI PTP RX/TX activity counters advance.

**Slave (`DE5 [1-11.2]`):**

- `MODE=3`, `PTP=9` (`PPS_SLAVE`).
- MAC `02:00:22:33:44:02`.
- Foreign-master metadata decodes as `foreign_count=1`, `best_index=0`.
- MiniNIC and PPSI PTP RX/TX activity counters advance.

`time_valid`, `PSTAT.locked`, WR handshake, SoftPLL, and global time are not
Step 2 gates. A successful compile or program alone is not a PASS. If any
acceptance item fails, preserve evidence, identify the first failing boundary,
and keep Step 2 unpassed; do not start Step 3 or substitute a later-Step image.

## Evidence layout and promotion rule

All build, program, and observation outputs go under this experiment's
`raw/build/`, `raw/program/`, and `raw/observe/`. The final report and
`SHA256SUMS` will inventory the evidence. The candidate becomes
`artifacts/milestones/step2_endpoint_ptp/source/` only after a fresh clean
build, successful programming of both boards, and the full runtime acceptance
above all pass.

Until then:

```text
STEP2_MILESTONE = CANDIDATE_NOT_VALIDATED
```

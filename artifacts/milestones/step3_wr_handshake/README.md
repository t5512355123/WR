# Step 3 — WR parent / signaling handshake

**Verdict: `NOT_YET_VALIDATED`**

This is the single active Step 3 frozen-source candidate. It must not be called
a completed milestone until both boards are clean-built and programmed from
this package and the Step 3 runtime acceptance passes.

## Provenance

- Historical Step 3 experiment: `EXP-WRPC-STEP3-FRESH-HEAD-20260819`.
- Historical source commit: `fb8c926cfe37b82e86300117181a6ac01e1889e2`.
- Frozen build-input snapshot origin: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`;
  the only differences to the historical Step 3 commit are three
  non-build documentation files. The source package records the path
  relocations needed for independent builds.
- Historical Master/Slave SOF hashes are recorded in the reproduction report;
  they are not being represented as the images produced by this rebuild.

## Reproduction status

| Gate | Status |
|---|---|
| Frozen source manifest | Pending verification after push/pull |
| Clean Master / Slave build | Pending |
| Program Master / Slave | Pending |
| Step 1 + Step 2 regressions | Pending |
| Step 3 WR parent/signaling acceptance | Pending |

## Acceptance interpretation

The live WR extension state is encoded in `WR_LOCAL state`; the source enum
defines `WRS_S_LOCK=2`. `fail_state` is populated only when
`wr_handshake_fail()` records the state where a prior attempt failed. It is
not a current-state field and will not be used to claim that the slave is
currently in `WRS_S_LOCK`.

`wr_lock_enable_count > 0` is the source-backed witness that the state-entry
hook called `wrpc_spll_locking_enable()`. Step 3 does not require the SoftPLL
to lock; that is a later milestone.

## Evidence

- Plan and acceptance contract:
  `experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/PLAN.md`
- New raw evidence and final verdict will be stored in that experiment.

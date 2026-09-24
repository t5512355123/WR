# Step 3 — WR parent / signaling handshake

**Verdict: `STEP3_MILESTONE = PASS`**

This is the independently clean-built and programmed Step 3 checkpoint. It
passed the Step 1/2 regression prerequisites and the Step 3 WR parent/signaling
acceptance on both DE5a boards. The verdict proves the WR handshake and the
source-backed SoftPLL lock-entry hook only; it does not claim SoftPLL lock,
Step 4 startup completion, Step 5 lock, or valid global time.

## Provenance

- Historical Step 3 experiment: `EXP-WRPC-STEP3-FRESH-HEAD-20260819`.
- Historical source commit: `fb8c926cfe37b82e86300117181a6ac01e1889e2`.
- Frozen build-input snapshot origin: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`;
  the only differences to the historical Step 3 commit are three
  non-build documentation files. The source package records the path
  relocations needed for independent builds.
- Historical Master/Slave SOF hashes are recorded in the reproduction report;
  they are not being represented as the images produced by this rebuild.
- Frozen candidate package commit: `f235b557ad09d9b37adff2c2b11b36f615f66e9e`.
- Pain source-manifest verification: 3,142 entries; all SHA-256 checks passed.
- Frozen manifest file SHA-256:
  `76245e8d53306a1cd2c0c7abd40145c6c4926b131568ed65dedec42594ac7207`.

## Reproduction status

| Gate | Result |
|---|---|
| Frozen source manifest | PASS — 3,142 entries verified on Pain |
| Clean Master / Slave build | PASS — 0 errors each |
| Program Master / Slave | PASS — both JTAG configuration operations succeeded |
| Step 1 + Step 2 regressions | PASS — stable 30/30 accepted frames per board |
| Step 3 WR parent/signaling acceptance | PASS — 30/30 accepted Slave frames |

## Acceptance interpretation

The live WR extension state is encoded in `WR_LOCAL state`; the source enum
defines `WRS_S_LOCK=2`. `fail_state` is populated only when
`wr_handshake_fail()` records the state where a prior attempt failed. It is
not a current-state field and will not be used to claim that the slave is
currently in `WRS_S_LOCK`.

`wr_lock_enable_count > 0` is the source-backed witness that the state-entry
hook called `wrpc_spll_locking_enable()`. Step 3 does not require the SoftPLL
to lock; that is a later milestone.

The snapshot reader's `WDIAGS_RESTART` label reads address `0x0010096C`, which
the time-series reader identifies as `wr_fail_debug`; it is not a reset
generation counter. The `CPU_RESET` readback at `0x00100B00` is not used as a
reset level because its readable status semantics are not source-validated.
Reset checks use the actual `CPU_RESET_n` status-probe bit, CPU debug
reset/fault indicators, firmware marker, and unchanged system reset register
snapshots. No source-backed reset-generation counter is exposed, so the report
does not claim an unsampled transient reset is impossible.

## Evidence

- Plan and acceptance contract:
  `experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/PLAN.md`
- Full build/program/raw-observation evidence, offline analyzers, verdict, and
  checksums are stored in that experiment.
- Exact programmed artifacts are `master.sof` and `slave.sof` in this
  directory; hashes are listed in `SHA256SUMS`.

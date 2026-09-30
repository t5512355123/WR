# EXP-S6-OBSERVER-PUBLICATION-TIMESTAMP-VALIDATION-20261001

## Verdict

```text
OFFLINE_SOURCE_FIELD_AUDIT       = PASS
PYTHON_TCL_SHARED_FIXTURE_TESTS  = PASS (24 tests)
LEGACY_FIVE_FRAME_REPLAY         = PASS (5 candidates; 0 trusted phase frames)
PUBLICATION_ORDER_PROOF          = NOT_ESTABLISHED
LIVE_OBSERVER_AUTHORIZED         = NO
BUILD_PROGRAM_RESET_POWER_CYCLE  = NONE
STEP6_STABLE_OFFSET              = NOT_ESTABLISHED
SERVO_OFFSET_VERDICT             = NOT_ESTABLISHED
```

The audit/test artifact is complete for its bounded offline scope. The
publication protocol itself is **not** validated, so no live observer or
firmware/Quartus build/program is authorized. This says nothing adverse about
servo hardware performance: the existing telemetry cannot yet certify a
coherent phase frame.

## Baseline and scope

- Repository: <https://github.com/t5512355123/WR>
- Branch: `feat/file_cleanup`
- Baseline HEAD: `8bd7c5ee87dfa04875eb88446aa6064a02e2202b`
- Experiment: `EXP-S6-OBSERVER-PUBLICATION-TIMESTAMP-VALIDATION-20261001`
- Changes are confined to this new experiment directory.
- No hardware/JTAG/WB reads, build, program, reset, power-cycle, production
  source edit, RTL edit, or SOF change occurred.
- The protected `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.

## Source audit and resulting data boundary

The per-field writer/caller/address/alias/owner/protection table is in
[`analysis/SOURCE_FIELD_CONTRACT.md`](analysis/SOURCE_FIELD_CONTRACT.md). The
important correction is to audit each field before treating it as a frame:

- `STATE/RX/TX/A8C` and `CKO/SETP/UCNT` are only candidate groups. The audit
  does not treat endpoint DATA_VALID values or a shared old marker as proof of
  a coherent group.
- `SSTAT` and `A6C` remain separate timestamped raw status reads. Immediate
  extension-disable writes can update them outside the periodic diagnostics
  call; they are never joined to a data frame or to each other.
- The `0x134/0x138` mapping self-test pair aliases the Helper PI frozen-bank
  commit/overwrite words after a request. It is written at
  `task-diags.c:365`, before phase fields at `:573-580`; it is not a phase
  commit sequence.
- `wdiag_set_valid()` at `dev/wdiags.c:319-323` performs a read/modify/write
  and readback. `writel()` is volatile-only in `include/hw/rawmem.h`; the
  periodic task has no explicit fence bracketing valid-low, all payload
  writes, and valid-high. Thus CPU→DPRAM→JTAG ordering and generation coverage
  are not established.
- The nominal 100 ms refresh interval does not by itself prove no marker
  ABA/wrap within 60 seconds: `wrc_task_not_yet()` advances by one period per
  invocation and the source audit does not establish a catch-up upper bound.

Accordingly, the actual source audit fixture marks writer/address coverage
complete, but keeps `publication_protocol_proven`, `sequence_owner_proven`,
and `aba_excluded_for_60s` false. The analyzer must block trusted-frame claims
for that fixture, regardless of DATA_VALID endpoint values.

## Replay of the latest five raw frames

The archived raw log was read-only and its SHA-256 still matches
`FADEA77FF4CB3C435DC581D131DDC763C3BD4D6B7BA63E056D00F05CD5E9AE7B`. Its five
phase candidates were replayed from
[`analysis/legacy_raw_replay.json`](analysis/legacy_raw_replay.json) through
both the Python analyzer and Tcl frame policy:

```text
attempted phase candidates                   = 5
mapping/generation changed during each read  = 5/5
Python/Tcl rejection agreement               = 5/5
trusted phase frames                          = 0
300-second stable window                      = NOT STARTED
servo/offset verdict                          = NOT_ESTABLISHED
```

Every raw attempt had DATA_VALID high at both recorded endpoints and
DATA_SNAPSHOT clear, but the full mapping word advanced by two during the
roughly 200–220 ms frame read. The old marker owner was not recorded, and the
CKO/SETP/UCNT fields did not have individual host read intervals in that log.
The old raw CKO value therefore is not a trusted offset sample and is not used
to say the servo passed or failed. The old raw is unchanged; the normalized
replay is a separate new-experiment artifact.

The prior observer also had a timestamp-key mismatch: it stored
`WR_STATE_RAW_READ_*`, `WR_RX_RAW_READ_*`, and `WR_TX_RAW_READ_*`, then consumed
`WR_STATE_READ_*`, `WR_RX_READ_*`, and `WR_TX_READ_*`. The new offline Tcl and
Python helpers normalize those aliases to canonical `STATE_READ_*`,
`RX_READ_*`, and `TX_READ_*`. Shared fixtures verify the mapping; the old
observer/raw were not edited.

## Offline tests

Python `unittest` ran 24 tests successfully using the bundled Python runtime;
the shared Tcl 8.6.12 interpreter executed the candidate policy in the same
tests. The tests cover:

- synthetic valid control and identical Tcl/Python decisions on shared frame
  vectors, including publication crossing, DATA_VALID/snapshot guards,
  generation inverse/commit parity, owner/overlay, exact field membership, and
  payload validity/time ordering;
- the five legacy frames, where both policies reject each changed-generation
  candidate and trusted PHASE count remains zero;
- SSTAT/A6C independence, first-disable bit 11, status timestamp monotonicity,
  repeated UCNT payload conflict, UCNT rollback/reset, timeout, frozen
  generation, and strict `-60 < CKO < 60` boundaries (both exactly -60 and +60
  fail);
- failure-closed behavior when source ordering/owner/ABA proof is missing.

The positive fixture is synthetic and only proves policy behavior. It does not
change `PUBLICATION_ORDER_PROOF` or authorize a live capture.

## Candidate protocol boundary (not implemented or deployed)

A later, separately authorized source change would need a dedicated
non-aliased publication generation whose owner and address are proven, with
all candidate payload writes bracketed by a commit protocol and explicit
ordering barriers. A simple fence is insufficient because a complete update
can occur between two host reads. The current mapping marker cannot be reused
as that generation, and no replacement address is selected in this report.

No next hardware step follows from this offline PASS. The Step 6 sampled
milestone still requires new trusted phase frames, stable locks/time-valid
conditions, and a continuous 300-second observation window with strict
`-60 < CKO < 60 ps` and no accepted sample gap over one second.

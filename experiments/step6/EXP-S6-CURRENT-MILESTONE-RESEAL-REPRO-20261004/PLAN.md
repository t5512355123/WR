# Current-code Step6 milestone reseal and independent reproduction

User requested: archive the currently successful main program into
`artifacts/milestones/step6_global_time`, then build, compile, program and
independently verify sampled TIME_VALID for at least 300 seconds.

## Entry evidence and scope

Committed main inputs at c60f75e9 have the qualified 3117-input manifest
418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a.
Laptop has uncommitted RXTS diagnostic changes which have NOT been compiled
or deployed. Preserve but exclude those changes from this qualified snapshot.

2026-10-04 10:59:40–10:59:50 preflight: Master TIME_VALID=1, Slave
TIME_VALID=0 / WAIT_OFFSET_STABLE / CKO=-926 ps, five Slave locks=1.
This contradicts a claim of current live qualification. Do not relabel it
PASS or overwrite the qualified archive with unverified images.

## Procedure

1. Laptop publishes this plan and a bounded packaging/reproduction wrapper;
   Pain pulls exactly that commit. No production changes.
2. Verify committed inputs, retained SOFs and JTAG ownership. Save another
   preflight before programming. Recoverably move the existing extracted
   source outside the canonical package, retaining its qualified archive.
3. Extract only committed main sources/scripts/build products into a new
   independent `step6_global_time/source` Git repository. No compiler caches,
   unrelated milestones, uncommitted diagnostics or failed experiments.
4. Execute the existing build_current.sh, compile_current.sh and
   program_current.sh from that independent source. Verify all 3117 inputs
   and pinned firmware hashes before and after. One Slave→Master program.
5. Use the unchanged verifier: maximum 600 s acquisition wait, then 303 s
   sequential observation per board, requested 250 ms sample interval.
   Require every sample TIME_VALID=1, >=300000 ms actual sample span,
   <=1000 ms gaps, both expected boards and complete DONE records.
6. Save logs, build/program identities, result, final dashboard and checksums
   to this experiment. Recompute on Laptop and publish the report.
7. Only after PASS, seal newly compiled SOFs, full reproducible source and
   verification records as the sole operational milestone. If not PASS,
   move the whole candidate repository outside the canonical package and
   restore the previous extracted qualified source. Preserve failure evidence.

## Acceptance limits

No PI/gain/60–120 ps threshold/control/calibration/RTL/SDC/PHY/reset changes,
forced validity, power cycle or automatic programming retry. TIME_VALID-only
sampled retention is not precision-offset, simultaneous sampling, absolute
TAI/UTC, physical PPS skew, timing closure or deterministic startup proof.

`/home/b10504072/04_WR_archive_step6_pass/` remains strictly untouched.

# Live TIME_VALID/CKO observation and documentation promotion

Date: 2026-10-05, Asia/Taipei. Authoritative source: current Pain
`/home/b10504072/04_WR`, branch `feat/file_cleanup`, checkout `9b8a231c`.
Laptop first fast-forwarded to this Pain/GitHub revision; Pain's existing
README, STATUS and MILESTONES content is the documentation baseline.

## Scope

Read the already running boards. No firmware/FPGA build, programming, reset,
power-cycle, gain/threshold change or consultant interaction. No changes to
operational scripts, frozen milestones or `/home/b10504072/04_WR_archive_step6_pass/`.
Retained root products record source `bcb84305`; the historical no-correction
directory/configuration label is not an on-chip image identifier. Real main-root
control has acquisition `/2` and tracking `/12`, with 60/120ps thresholds.

Update only root documentation and this observation record, then push
`feat/file_cleanup` and fast-forward merge it into `main` if the remote remains
an ancestor. Do not force-push or overwrite unrelated local changes.

## Observation and unchanged acceptance

1. Verify no other Quartus reader/programmer owns JTAG; preserve all user processes.
2. Save one read-only dashboard preflight. This is not a 300s qualification.
3. Observe Slave with `read_step6_servo_interleaved_offset.tcl 303000 500 1-11.2 2`.
   Phase context is independently guarded and joined by UCNT; duplicate updates
   and untrusted phase frames are excluded from CKO statistics.
4. Analyze Slave STATUS_TIME_VALID with the existing 300s verifier. If this
   capture meets the original <=1000ms sample-gap and >=301-row requirements,
   retain it as Slave's independent 300s window. Do not relax coverage limits.
5. Observe Master with `read_step6_global_time_observability.tcl 303000 250 1-11.1`.
   Analyze with the same unchanged verifier and Master-only board identity.
6. If Slave's phase capture lacks TIME_VALID coverage, obtain a separate Slave
   Global-Time window instead. Do not manufacture a combined raw capture.
7. Save postflight, raw captures and analyzer results. Report each board/window
   independently; sequential JTAG reads do not prove simultaneous physical timing.

Required Step6 gate is exported STATUS_TIME_VALID=1 in every sample over an
actual >=300000ms span, complete numbered capture and matching DONE count,
>=301 samples, <=1000ms gaps, exact board identity and no capture error.
Both independent board verdicts must pass. CKO, snapshot/PPS, TAI/cycles, link,
PLL locks and timing closure remain diagnostic, not replacement acceptance gates.

Read failures, competing reader/programmer, reset-signature change or repeated
untrusted phase frames stop the affected observation. Save the evidence and
report NOT_ESTABLISHED rather than restart hardware or tune controls.

## Important distinctions

TIME_VALID retention is not strict offset stability. Existing historical WR
behavior can retain enabled timing output during fine-phase reacquisition.
Even a successful 300s live window does not prove deterministic cold startup,
physical PPS/SMA skew, civil UTC accuracy or hardware oscillator jitter.
The sealed Step6 package's previous failed fresh standalone acquisition remains
historical evidence and is not erased by this successful live-root check.

Laptop sync encountered 76 untracked historical files newly tracked by the
Pain revision. They were moved intact to
`experiments/local_preserved/20261005-sync-untracked-conflicts/` before the
fast-forward, not deleted or included in this new evidence commit.

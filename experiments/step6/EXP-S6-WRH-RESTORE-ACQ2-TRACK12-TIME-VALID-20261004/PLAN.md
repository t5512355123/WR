# Restore the previously qualified acquire/2 + track/12 baseline

User requested restoration after the negative /24+/24 experiment. Restore
ONLY the two WR CKO division constants: SYNC_PHASE `/2`, TRACK_PHASE `/12`.
The3110 historical qualified production inputs must match0bb02c6f, plus the
7 inert declarations already present in the root. Master bootstrap2048/
account64/reverse1, Slave MainKp300/Ki1/physicalstep16, thresholds60/120ps,
wait retries, legacy timing validity, calibration/SoftPLL/DAC/RTL/SDC/PHY/reset
remain unchanged. Preserve all /24 negative records and user stashes.

This baseline passed fresh main-root300s sampled TIME_VALID on both boards in
EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003 and
EXP-S6-IDENTICAL-IMAGE-STARTUP-ACQUISITION-ATTRIBUTION-20261004. Identical
configurations also failed acquisition on other boots; historical success
does not establish deterministic startup or qualify this new boot.

Workflow: Laptop edit/tests/push → Pain exactpull/native actual-C tests →
main-root existing one-command firmware/fullcompile/Slave→Master program/
one-shot dashboard → unchanged TIME_VALID300s verifier in SAME boot → raw
and products backLaptop → independent analysis/report/push → Pain exactsync.
Do not use stale root /24 SOFs for the new experiment; full compile/export
must succeed first. Editable main pipeline remains without fixed SHA gates.

Use `POST_PROGRAM_WAIT_S=60 ONCE=1 CLEAR_SCREEN=0 bash scripts/run_current.sh`:
the short passive post-program settling avoids treating immediate CPU startup
as the final outcome. Then permit at most900s read-only acquisition with
`TIME_VALID_ACQUISITION_TIMEOUT_S=900 bash scripts/monitor/verify_time_valid_300s.sh`.
On valid entry, the existing verifier samples each expected board sequentially
for303s, requires>=300000ms observed span, every sample TIME_VALID1, complete
DONE/index records and<=1000ms gaps. No relaxed gate or forced validity.

One programming pair only. On compile/program failure, competing JTAG reader,
transport/reader failure, acquisition timeout or invalid formal observation,
save evidence and stop; do not reprogram or change another parameter.
Final dashboard is observational, not a substitute for300s qualification.
TIME_VALID-only success would not prove±120ps precision, physical PPS skew,
absolute TAI/UTC, full timing closure or deterministic startup. No consultant,
power cycle or automatic milestone promotion. Protected archive and frozen
milestones remain untouched.

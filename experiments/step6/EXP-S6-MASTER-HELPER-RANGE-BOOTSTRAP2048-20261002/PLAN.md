# Master Helper range recovery candidate

Baseline: diagnostic compile source 9fe20c3e; observer afab6ec5.
Master is wait-helper, HL=0, HY=65531, phase tracker not ready. Independently
sampled L2 Helper starts/completions remain 1929, failed completions zero.
Slave PLL locks are healthy but PTP TIME_VALID remains zero. Master time-valid
alone does not guarantee its fine timestamp phase is usable.

## Single intervention: Master coarse physical origin

Enable a boot-lifetime 2048-step FINC bootstrap on Master only. Explicit
ENABLE_STEP5_ACTUATOR_IDENTIFICATION=1 / REVERSE=1 uses the existing proven
forced-direction branch, so varying normal target direction cannot flip it.
Normal tracker remains enabled, default fine code step stays 34. Slave top,
all firmware control/gains/thresholds, static tables, reset, PHY, arbitration,
timing constraints and dashboard are unchanged.

This is an empirical range bracket, not a proven fix. The old fine range
admits about (65531-5)/34 = 1927 physical steps from its origin. Moving the
origin by 2048 makes a different, higher physical range available; it does
not overlap the old unbootstrapped range. This candidate can overshoot and
must be rejected if it merely moves saturation to the other rail.
Historical same-controller Slave evidence measured positive frequency-error
movement with FINC, but its slope is not claimed transferable to Master.
No validity bit is forced and no offset threshold is relaxed.

## Workflow and checks

Laptop exact diff/tests/push -> Pain pull -> existing build_current.sh and
compile_current.sh -> program_current.sh (Slave then Master) -> single reader.
Retain and identify old diagnostic products before overwriting new products.
Do not access or modify the protected archive. New compile identities and
SHA256s must be exported to output; stale files are not new candidate evidence.

After program, check both links/reset generations, Slave locks and Master
`pll stat`/RXTS_DIAG. Observe Master Helper output and phase tracker readiness.
Allow at most 180 seconds for this prerequisite smoke. Abort on invalid
transport, reset/generation change, lost link, or persistent Master rail / no
phase tracker readiness at the deadline. Do not tune gain, retry programming,
or force timing output within this run. Preserve/report failure.

If Master Helper and ptracker become ready and both TIME_VALID bits are 1,
run the existing guarded 300-second verifier. Every sampled row must qualify;
a single-board success or instantaneous lock is not a pass. If readiness never
arrives within the existing bounded verifier window, retain failure evidence.
Publish logs, SOFs, build metadata and checksums on Laptop and sync via GitHub.

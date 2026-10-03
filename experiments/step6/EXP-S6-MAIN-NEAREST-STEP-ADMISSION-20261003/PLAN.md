# Slave Main nearest-step admission

Baseline bf0651769e9abe373d220d9444dc79ce91edc814. Actual preceding capture:
60 coherent rows,59/59 Main progress intervals,+641 completed transactions,
maximum logical latency1.22882ms,59/60 residuals<16(-12..+13), one-17 in flight.
CKO-201..+227ps; strict acquisition/postflight holds604/0ms. Not300s PASS.

One production variable: Slave Main admission rounds to the nearest reachable
16-code grid point. Increment residual>=8, decrement residual>=9; exact
midpoint chooses the upper point consistently, avoiding symmetric>=8 chatter.
Physical Main step/account completion remains16. Helper64, Master admission,
arbiter/ACK/order/bootstrap/timeout/reset/PHY, all firmware(Kp600/Ki1 etc),
WR /2 acquire /12 track, full64 strict60-entry/inclusive120-hold and existing
strict observer remain unchanged. Both load-side pending and idle admission
use the same rule. Default0 preserves previous behavior, enabled only Slave.
The reused observer header control_changed=0 describes observer actions, NOT
absence of the above production intervention. This experiment changes control
admission and must never be reported as an observer-only hardware candidate.

This is a causal candidate, not a diagnosed root cause or physical readback.
Before full compile/program: source isolation, all65536 targets under offline
integer model, actual default-controller equivalence plus actual I2C pin
tests enabled1: residue/tie stability, latest target during transaction,
upper/lower unsigned bounds, unchanged full-step accounting and Helper service
under Main contention; known NACK behavior preserved and not called safe.
Native C/Tcl/strict/history tests, unchanged role MIF hashes must all pass.

Laptoppush ->Pain exact pull/native/firmware builds ->full root compile ->one
Slave->Master programming pair.20s strict smoke ->one120s acquisition if link/
clock/reset upstream is intact. One60-row DCO correlation (first3 smoke, actual
max120s, single observer, independent groups); no new reader gain/calibration/
control injection.20s strict postflight; only fresh<60 entry +>=10s continuous
qualified/error-free data permits one360s actual strict300s attempt.

Stop/save partial on wrong image, schema/capture collision, NACK/timeout/error,
reset/generation/link/Helper/Main lock/Master validity loss, persistent invalid
data or actual capture deadline. Do not retry programming due to observation
timeout. No relaxed thresholds, data deletion or milestone promotion. Timing
not a gate. Return actual products/raw/checksums to Laptop, independent
analysis/REPORT/README/STATUS/push, Painffsync. No advisors/powercycle.
Protected /home/b10504072/04_WR_archive_step6_pass/ and all milestones untouched.

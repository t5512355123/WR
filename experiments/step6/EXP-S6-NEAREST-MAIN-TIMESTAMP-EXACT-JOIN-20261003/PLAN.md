# Exact Main/tracker and timestamp accepted-update joins

Baseline c8460b08a3d94d0285ee4bbcf21637ad5d57f691. The nearest-admission trial
had60 coherent rows,9526 completions,59/59 progress, residual-11..+11;
CKO-254..+143ps. Strict qualified holds3187/607ms, not300s. More transaction
activity did not establish stability. Ki1 and strict60/120 remain frozen.

Production input change NONE. Keep Slave nearest admission8/9 and physical
completion16, Kp600/Ki1, Helper64, /2 acquire /12 track, thresholds/control/
arbiter/bootstrap/timeout/PHY/reset/SDC/QSF/SDB exactly equal baseline.
Only new executable code is the paired observer/independent analyzer/tests.
Existing timestamp and phase-history hooks/readers remain unchanged.

Source audit: ts_record() in wr-servo.c calls wr_phase_history_record() after
the SAME actual accepted E2E WR update. TS4 is16 entries; PHIST32. Both counts
increment there once and shell/producer serialize in the foreground; ISR
produces the independently guarded Main/tracker frames, not either WR ring.
CKO/DMS full64 fields, state, pre/post SETP, phase-write count and SPLL init
must agree EXACTLY at each joined UCNT. Main copied after packet acceptance
is not packet-time atomic and last tracker tags are not all512 samples.
Preserve Main16ns/16384 units, tracker8ns doubled/modulo normalization and
actual update/sample_n progression, not publication count alone.

One observer freezes TS4 page0 FIRST, drains its reply completely, then
PHIST page0. Each fits1024-byte FIFO, both together do not. Because PHIST is
longer, skew<=20 accepted updates guarantees>=12 common updates. Verify actual
counter skew, generations and exact UCNT matches; host timestamps alone do
not establish pairing. No second page0, automatic retry, new firmware command
or PLL/gain/calibration/control writes. Existing shell commands copy diagnostic
RAM only; printing can perturb scheduling, but histories freeze before print.
32 replies=16TS4 pages+16PHIST pages;480s actual total ceiling is a new combined
protocol, not a relaxed old240s/360s single-reader gate. Old readers/gates stay
unchanged. Save each complete raw reply before parsing, partials on any failure.
First2page smoke then same immutable snapshots; full diagnostic requires
16TS4/32PHIST rows,>=12 exact joined consecutive updates and live health brackets.
Diagnostic DATA_ONLY, never300s PASS or physical causal proof.

Tests first: same source/control inputs, both individual payload validators,
exact joins/large signed timestamps/counter wraps/torn data/generation mismatch/
missing page/health/deadline/insufficient overlap; actual whole observer native
Quartus Tcl good/schema-failure/skew-failure with no hardware session.

Workflow: Laptopedit/test/push ->Pain exact pull/native/role firmware rebuilds
->fresh full root compile ->one Slave-to-Master programming pair.20s strict
startup smoke and one120s acquisition while upstream remains intact. One
paired immutable capture above, then20s strict postflight. Only fresh<60 entry
and>=10s continuous qualified/error-free data permits one360s300-goal attempt.
No relaxed reader gap1000ms/Master age1500ms/update age2000ms or strict60/120.
Stop/save partial on image mismatch, ambiguous board, shell/protocol failure,
incoherent source, reset/generation/link/clock/Helper/Main lock/Master validity
loss, insufficient overlap or actual deadline. Do not reprogram on timeout.

Afterward actual products/raw/checksums toLaptop experiments, independent
reanalysis, REPORT/README/STATUS/push, Painffsync. Do not promote milestone or
blame Ki from correlation. Protected Pain archive and milestones untouched.

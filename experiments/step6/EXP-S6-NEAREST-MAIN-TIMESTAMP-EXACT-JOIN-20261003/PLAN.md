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

Same-image follow-up after the completed paired history: that capture found
four action-free~4ns CKO/~8ns return steps. Before choosing any calibration
or controller change, use ONE existing paired-return capture in this same
still-live1ab27d25 programmed session. Do not reprogram solely to collect
Master RX data: boot phase is a relevant uncontrolled variable. This is an
additional observation of this experiment, not a new functional candidate.
Laptop reruns existing paired-return11/details3/strict-reader1 tests and
pushes this plan before Pain ff pull. No compile input or observer changed.
Verify existing output/SOURCE checksums, current HEAD and no JTAG owner.

Existing360s actual capture gate,32 Master RX/16 Slave TS4 records, exact
live peer identity/sequence/full64 timestamp matches and>=8 paired updates
stay unchanged. Shell commands are read-only MAC and passive ring pages.
One page-zero per board, no retry. Preserve complete/partial raw on stop;
no second capture if no overlap or no jump. If jump appears, decompose
coarse return, fine correction, ahead/selected edge/T24P and raw phase at
the exact accepted updates. A different time window is not the earlier
Main-history snapshot and cannot be joined by approximate host time.

An8ns jump must be distinguished from normal compensating ahead changes;
correctly reproduced linearizer arithmetic alone does not establish its
physical calibration. No fitted smoothing, packet drop rule, threshold
relaxation, validity forcing or live calibration. After capture,20s strict
postflight with original extension gate; record/upload/reanalyze on Laptop,
then sync Pain. Keep prior95-file transfer manifest immutable; follow-up
files receive a separate manifest. No claim300s without actual qualification.

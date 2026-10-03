# Main command-to-DCO virtual-account correlation

Goal unchanged: actual strict<60ps entry, then300s TIME_VALID continuously
within inclusive+/-120ps, with validity revoked above120ps. No timing gate.
Baseline eb12a587415fb0c55f620360ddb66c1066a0676b, MainKp600/Ki1.
Previous experiment narrowed Main error but CKO remained-301..+274ps;
qualified startup/postflight spans2109/901ms, not300s.

Source audit: dpll_target_position is the latest absolute Main DAC command.
dpll_applied_position starts32768 and advances by16 only after final four-write
completion. It is a VIRTUAL ACCOUNT, not SI5340 physical readback. Completion
may occur even after NACK; L2 failures must therefore invalidate interpretation.
Existing probe8 shows last target, not applied;52..61 show service telemetry.
Helper39/43 is NOT Main position. Main's full16-code residual admission remains
unchanged. Pending-based waits may omit/pre-date residual admission; maximum
logical transaction latency is a separate measurement (50MHz ticks).

Only change: independent private capture logic and Slave probes72/73/74;
Master interface addition tied0/open and should optimize away. Frozen payloads
are one50MHz-edge target/applied/start/success/meta copy, with synchronized
debug request and ACK/sequence. No value feeds functional logic. Meta schema1:
lowbit ACK,16:1 sequence,17 initialized,18 pending,19 TX active,20 TX owner Main,
21 ACK error,22 DCO error,23 timeout,26:24 RT state,27 direction,28 selectMain,
31:29 schema1,63:32 local50MHz ticks.73 applied:target,74 success:starts.
Independent WR/L2 groups are NOT atomic with that capture. All firmware,
PI/gain/thresholds, WR60/120, DCO admission/order/step16/bootstrap/arbiter,
PHY/reset/SDC/QSF/SDB and existing strict observer remain byte-identical.

Laptop source tests/analyzer/Tcl tests/push -> Pain exact pull; actual native
baseline/candidate RTL cycle-equivalence and pin-level liveness regression,
plus unchanged firmware builds/hash pins -> full root compile/program once
Slave->Master ->20s strict smoke, one120s acquisition if upstream stable ->
one single-reader60-sample capture (first3 smoke then same session, actual
max120s). Bracket both-board health every10 samples and at ends; no second
reader/PI-bank request. Stop on wrong image, capture collision, reset/link/
Helper/Main lock/Master-validity loss, NACK/timeout/error, persistent invalid
data or actual deadline. Save partials, never count completion as Step6 PASS.

Compare residual and Main transaction progress with CKO, preserve complete64
raw. Near-threshold residual with normal service can support evaluating
quantized admission; large sustained residual with service/latency deficit
supports studying delivery first. Neither is causal proof, or permission to
pretend a smaller virtual step than the measured physical16 codes. No automatic
gain sweep or Ki change. Strict20s postflight; only fresh entry+>=10s continuous
qualified data/errorsnone may extend with one360s actual strict300s attempt.

Return actual build/output/raw/checksums to Laptop, independent analysis,
REPORT/README/STATUS/push, Pain ff sync. Preserve all frozen milestones and
never touch /home/b10504072/04_WR_archive_step6_pass/. No advisors/powercycle.

Execution amendment: the first actual DCO observer stopped before sample0,
because image-instance discovery tried to open a second session after health
left the Slave session open. Both health groups passed. Preserve that failed
raw. Laptop fixes ONLY observer session ownership and adds an offline native
Tcl lifecycle/wrong-image test ->push ->Pain pull/native tests ->one bounded
retry on the same programmed pair. No control/source-image change, no compile
input change, no reprogram. Compiled source identity remains f0f0f7ef.

Second pre-sample stop: the reader incorrectly expected full HDL instance IDs.
Existing read_probe.tcl actual inventory proves Slave tuples72/73/74 are
{72 1 64 A_V1}, {73 1 64 N_V1}, {74 1 64 S_V1}; Master has none. Quartus17
returns four-character suffixes. No debug capture request/sample was issued.
Laptop narrows image check to those exact unique index/source/probe/ID tuples,
with five wrong-contract native tests; keep schema/init/sequence/failure guards.
Afterpush/Painpull/native tests, permit one bounded actual capture using the
same exact SOFs. Preserve both failed preflights and inventory. No reprogram,
no relaxed data guards, and do not confuse these reader preflights with
hardware failure or valid DCO data.

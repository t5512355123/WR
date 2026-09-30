# EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001

## Verdict

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
PRODUCTION_CONTROL_CHANGES = NONE
OFFLINE_TESTS = PASS (9 at original run; 10 after offline correction)
TCL_INFO_COMPLETE = PASS (Tcl 8.6.12)
TCL_MOCK_SOURCE_EVENT = PASS (state handoff with TX/context invalid)
TCL_MOCK_FAILURE_STOP_GUARD = PASS (new failure plus 3 trusted stop-class rows)
SHELL_WRAPPER_SYNTAX = PASS
PAIN_PULL = PASS (fa9a813274783e3974fbdf76b46130b18637a246)
SOF_HASH_PREFLIGHT = PASS
FRESH_PROGRAM_SLAVE_MASTER = PASS (no compile; exact pinned images)
HARDWARE_CAPTURE = FAILURE_RECORD_AND_STOP_POLICY_STATE_EXIT_BEFORE_EVENT
CAPTURE_DURATION = 250.779 s / 300 s maximum
CAPTURE_ROWS = 741
REQUIRED_ROWS_VALID = 741 / 741
SOURCE_BACKED_SUCCESS_EVENT = NONE
WR_STATE_COUNTS = WRS_IDLE: 28, WRS_S_LOCK: 710, WRS_PRESENT: 3
NEW_FAILURE_COUNT = 0 -> 1 at sample 738
POST_FAILURE_WRS_PRESENT_ROWS = 3
SOURCE_BACKED_FAILURE_REASON = WR_S_LOCK_TIMEOUT (offline decode)
STEP6_STABLE_OFFSET = NOT_ESTABLISHED
~~~

## Baseline and programming

- Pain fast-forwarded to `fa9a813274783e3974fbdf76b46130b18637a246`.
- Wrapper syntax and all nine Python regression tests passed on Pain.
- No compile was performed; both exact pinned SOFs were freshly programmed
  Slave then Master.
- Slave SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
  (Quartus checksum `0x30B1E229`, programmer PASS).
- Master SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`
  (Quartus checksum `0x30B18F28`, programmer PASS).
- Programmer listed both expected cables: `DE5 [1-11.1]` and
  `DE5 [1-11.2]`.
- One read-only Slave observer ran immediately after programming. No dashboard
  or second JTAG reader was opened.

## Hardware observation

- 741 rows; `READ_VALID`, `EVENT_EVIDENCE_VALID`, `REQUIRED_ROW_VALID`,
  `CONTEXT_READ_VALID`, and `COUNTER_READ_VALID` were each valid for 741/741
  rows. There were no invalid rows or Wishbone timeout/invalid reads.
- Step 1 remained established. Boot generation and CPU/WR-core/SI reset
  signatures did not change.
- State counts: 710 `WRS_S_LOCK`, 28 `WRS_IDLE`, and 3 `WRS_PRESENT` rows.
  No `WRS_S_LOCK → WRS_LOCKED` handoff, `WRS_LOCKED` state, or successful
  local TX `LOCKED` (`0x1002`) message was observed.
- At sample 738 (`249.767 s`), the low-eight-bit failure counter changed from
  the trusted baseline `0` to `1`. The original Tcl's reported
  `WR_FAILURE_REASON=0` was incorrectly decoded from the A6C failure/disable
  word; it is withdrawn. The corrected A8C decode is documented below.
- Samples 738–740 showed `WRS_PRESENT`. The observer emitted its historical
  stop reason `NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT` at `250.779 s`.
  This means the observer's failure-plus-state-exit stop rule fired; it does
  not prove that the WR extension was disabled. The 300-second no-event timeout
  was therefore not reached.
- The same-row/sequential poll counters and S_LOCK tail remained context only;
  neither triggered the event window nor the stop.

This is one observed failure record and post-failure transition before any
source-backed success event. It is not a repeatability result, not proof of a
terminal extension disable, and not a diagnosis of the underlying lock failure.
Step 6 stable offset was not evaluated.

## Post-run source/raw correction

The offline source/raw audit is recorded in
`../EXP-S6-WR-FAILURE-RECORD-SOURCE-RAW-AUDIT-20261001/REPORT.md`.
It verified the existing raw log SHA-256 and decoded the two separate words
using the frozen source mapping:

| Sample | A6C failure/disable word | A8C lock-result word | Correct interpretation |
|---:|---|---|---|
| 737 | `0x00000000` | `0x00000001` | Failure count 0; no attributed failure yet |
| 738 | `0x02020001` | `0xB9190601` | Count 0→1; last role 2 (Slave), WR state 2 (S_LOCK); reason 3 (`WR_S_LOCK_TIMEOUT`); failure tics low16 `0xB919` |
| 739–740 | `0x02020001` | `0xB9190601` | Same failure record remains visible; current WR state is `WRS_PRESENT` |

In A6C, disable-valid is 0. Its zero cause/PTP-state bits are not valid
disable metadata; in particular, PTP state at the failure call was not
captured. A8C's reason and low-16 timer value are in the same raw word. The
observer did not emit a dedicated A8C read timestamp; for sample 738 its read
is bounded by the recorded reject-read end (`1790797508692`) and the following
poll-read begin (`1790797508703`), an 11 ms interval. A6C and A8C are separate
reads, not an atomic cross-register snapshot.

Frozen-source call-path review shows reason 3 is emitted by the S_LOCK timeout
branch. `wr_handshake_fail_reason()` records the failure before checking the
narrow Slave auto-rearm predicate; the auto-rearm branch returns before the
extension-disable writer. The captured Slave role/S_LOCK record, parent-WR
context, subsequent `WRS_PRESENT` rows, and disable-valid 0 support an
S_LOCK-timeout/re-arm interpretation. However, PTP state at the exact call
and an atomic cross-register event snapshot are absent, so the re-arm path is
supported/consistent, not proven. No sticky extension-disable record was
observed. The low-16 timer value is not converted to host elapsed time.

The programmed SOF hashes are tied by the saved build-info records to the
candidate build at repository commit
`9c9afa345c1de03760ec9ee07eb742888c3fa8fe`, with frozen source origin
`74dc28862653d306e0450cf437ba6d3a230d979d`; the subsequent observer checkout
was `fa9a813274783e3974fbdf76b46130b18637a246` and performed no compile. The
hashes match the build and programmer logs. They are not the different
`master.sof`/`slave.sof` files currently checked into the Step 6 milestone
directory.

## Offline validation and raw evidence

The Tcl 8.6.12 syntax check and two mocked runs passed. The mocks verified that
a source-valid state handoff can trigger even when unrelated TX/context data
is invalid, and that a new failure remains latched until three trusted rows in
the observer's configured state-exit class. This class includes WRS_PRESENT
and does not mean the WR extension was disabled. The original nine Python
tests include the previous capture's raw log; the offline correction added a
tenth test to prevent the observer stop token from being promoted to an
extension-disable claim. The two positive non-atomic counter differences
remain context and do not become events.

Pain and Laptop observer-log SHA-256 matched:

~~~text
9fc2da70c44d005e351a721057f26b2f9506e441d752b354fde8338b56197580
~~~

All preflight, programming, observer, and checksum artifacts are retained under
`raw/`; per-file SHA-256 values for all seven transferred artifacts also match
between Pain and Laptop. The analyzer independently reproduced 741 valid rows,
no source event, and no reset-signature change. Its corrected classification
describes completion of the observer stop policy without claiming extension
disable or terminal failure.

## Next-step gate

This hardware capture and its source/offline audit are complete. Do not start
another hardware capture or change production controls until a later advisor
recommendation.
`STEP6_STABLE_OFFSET` remains `NOT_ESTABLISHED`.

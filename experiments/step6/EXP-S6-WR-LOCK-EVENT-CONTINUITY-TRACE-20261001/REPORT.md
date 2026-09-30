# EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001

## Verdict

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
PRODUCTION_CONTROL_CHANGES = NONE
OFFLINE_TESTS = PASS (9 tests)
TCL_INFO_COMPLETE = PASS (Tcl 8.6.12)
TCL_MOCK_SOURCE_EVENT = PASS (state handoff with TX/context invalid)
TCL_MOCK_TERMINAL_FAILURE_GUARD = PASS (new failure plus 3 trusted inactive rows)
SHELL_WRAPPER_SYNTAX = PASS
PAIN_PULL = PASS (fa9a813274783e3974fbdf76b46130b18637a246)
SOF_HASH_PREFLIGHT = PASS
FRESH_PROGRAM_SLAVE_MASTER = PASS (no compile; exact pinned images)
HARDWARE_CAPTURE = NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT_BEFORE_EVENT
CAPTURE_DURATION = 250.779 s / 300 s maximum
CAPTURE_ROWS = 741
REQUIRED_ROWS_VALID = 741 / 741
SOURCE_BACKED_SUCCESS_EVENT = NONE
WR_STATE_COUNTS = WRS_IDLE: 28, WRS_S_LOCK: 710, WRS_PRESENT: 3
NEW_FAILURE_COUNT = 0 -> 1 at sample 738
TERMINAL_INACTIVE_ROWS = 3
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
  the trusted baseline `0` to `1`; the packed failure-reason field was valid
  and read as `0`. This does not identify a specific cause.
- Three following trusted rows showed `WRS_PRESENT`; the observer correctly
  stopped at `250.779 s` with
  `NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT`. The 300-second no-event timeout
  was therefore not reached.
- The same-row/sequential poll counters and S_LOCK tail remained context only;
  neither triggered the event window nor the stop.

The result is a reproducible terminal WR admission exit before any source-backed
success event, not a Step 6 pass and not proof of the failure's root cause.
Step 6 stable offset was not evaluated.

## Offline validation and raw evidence

The Tcl 8.6.12 syntax check and two mocked runs passed. The mocks verified that
a source-valid state handoff can trigger even when unrelated TX/context data
is invalid, and that a new failure remains latched until three trusted
inactive-state rows. The nine Python tests include the previous capture's raw
log; its two positive non-atomic counter differences remain context and do not
become events.

Pain and Laptop observer-log SHA-256 matched:

~~~text
9fc2da70c44d005e351a721057f26b2f9506e441d752b354fde8338b56197580
~~~

All preflight, programming, observer, and checksum artifacts are retained under
`raw/`; per-file SHA-256 values for all seven transferred artifacts also match
between Pain and Laptop. The analyzer independently reproduced 741 valid rows,
no source event, no reset signature change, and the terminal failure stop.

## Next-step gate

This experiment is complete. Do not start another hardware capture or change
production controls until the advisor reviews this result and supplies the
next recommendation. `STEP6_STABLE_OFFSET` remains `NOT_ESTABLISHED`.

# EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001

## Current status

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
PRODUCTION_CONTROL_CHANGES = NONE
OFFLINE_TESTS = PASS (9 tests)
TCL_INFO_COMPLETE = PASS (Tcl 8.6.12)
TCL_MOCK_SOURCE_EVENT = PASS (state handoff with TX/context invalid)
TCL_MOCK_TERMINAL_FAILURE_GUARD = PASS (new failure plus 3 trusted inactive rows)
SHELL_WRAPPER_SYNTAX = NOT_RUN
PAIN_PULL = NOT_RUN
SOF_HASH_PREFLIGHT = NOT_RUN
FRESH_PROGRAM_SLAVE_MASTER = NOT_RUN
HARDWARE_CAPTURE = NOT_RUN
STEP6_STABLE_OFFSET = NOT_ESTABLISHED
~~~

No hardware capture has been performed for this experiment. The previous
counter-derived observer was rejected as an event trigger because its
published diagnostic counters are sequential, non-atomic reads. See the
previous experiment's addendum for the interpretation of its `+18` and `+16`
post-hoc intervals.

The offline Tcl smoke ran against mocked JTAG/Wishbone reads, not hardware. It
verified the output format, event timing fields, and post-event stop path when
the S_LOCK handoff word was valid while TX and optional context data were
invalid. A separate mock supplied a new failure count while WR remained active
and verified that the observer retained the failure evidence until three
trusted inactive-state rows. Nine Python tests passed, including the actual
previous raw log fixture: its two positive non-atomic interval differences do
not become source events.

## Planned evidence

After offline validation and the single authorized capture, record exact
source commit and SOF hashes, programming logs, preflight, raw observer log,
matching checksum, analyzer output, all validity counts, source event/read
brackets, reset/Step 1 continuity, stop reason, and any counter/tail context.
Do not infer a Step 6 pass from this experiment.

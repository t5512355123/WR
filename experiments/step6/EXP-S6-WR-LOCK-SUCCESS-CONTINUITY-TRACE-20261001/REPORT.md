# EXP-S6-WR-LOCK-SUCCESS-CONTINUITY-TRACE-20261001

## Current status

~~~text
VERDICT = PENDING_HARDWARE_CAPTURE
IMPLEMENTATION = OFFLINE_VALIDATED
SOURCE_MAP_AUDIT = PASS
OFFLINE_TESTS = PASS (8 tests)
TCL_PARSE = PASS (Tcl 8.6.12)
TCL_MOCK_FLOW = PASS (candidate -> confirmation -> 5-second post-confirm stop)
FIRST_PROGRAMMING = PASS (exact pinned Slave and Master images)
FIRST_OBSERVER_START = FAILED_BEFORE_HARDWARE_READ
FIRST_CAPTURE_ROWS = 0
HARDWARE_CAPTURE = RETRY_PENDING_CLOCK_COMPATIBILITY_FIX
FIRST_SUCCESSFUL_LOCK_POLL = NOT DETERMINED
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

The local Tcl smoke used mocked JTAG/Wishbone access only. On Pain, both exact
SOFs programmed successfully, with Quartus checksums `0x30B1E229` (Slave) and
`0x30B18F28` (Master). The observer then exited during elapsed-clock
initialization, before `start_insystem_source_probe` or any board-register read:
the embedded Quartus Tcl's `clock clicks -milliseconds` value did not satisfy
the original integer check. This attempt has zero samples and is not a hardware
result. The observer now accepts numeric click values and has a Linux
`/proc/uptime` monotonic fallback. After pushing this compatibility fix, the
exact same images must be freshly programmed again before the actual trace.
See [`PLAN.md`](PLAN.md) for the pinned baseline, read-only scope, and stop
criteria.

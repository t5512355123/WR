# F4D Attempt 1 — observer runtime validation

日期：2026-09-15（Asia/Taipei）  
Observer/source commit：`7cc73976e7fb6400cc8b905f506d841906355fd8`  
Functional image source：`5ba40f84cc4275f9a707bd847ac9809b267f7637`

## Result

```text
BUILD = PASS (Master + Slave)
PROGRAM = PASS (Master + Slave)
OBSERVER_START = PASS (both targets discovered)
OBSERVER_CAPTURE = ABORTED_BY_OBSERVER_ERROR
F4D_RESULT = NOT_APPLICABLE
STEP5 = NOT_COMPLETE
```

The F4D reader aborted on the first board sample because its newly added Tcl
indirect-array access used an expression form that Quartus Tcl parsed as an
invalid operator. The error was:

```text
missing operator at _@_
... ${reset_array}($role) != $reset_value
```

This is an observer implementation defect, not a hardware gate result. No
F4D sample was accepted and no claim is made about the WR session, Step4B, or
Step5 from this attempt.

## Hardware actions

The fixed user workflow was followed with the observer-only commit:

```text
Pain exact source commit = 7cc73976e7fb6400cc8b905f506d841906355fd8
Master build = PASS, timing_closed=NO
Slave build = PASS, timing_closed=NO
DE5 [1-11.1] Master = Configuration succeeded
DE5 [1-11.2] Slave = Configuration succeeded
```

The timeline started immediately after Slave programming and discovered both
boards. It stopped before a valid sample was emitted, so this attempt does
not satisfy the F4D capture requirements.

## Corrective action

The indirect reset-array lookup will be replaced by a safe read-then-compare
form that does not put a dynamically constructed variable name inside an
`expr`. The corrected observer must be committed and pushed before the next
Pain build/program cycle. The failed raw is retained as part of the F4D audit.

## Raw evidence

```text
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-syntax-7cc73976.log
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-master-build-7cc73976.log
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-slave-build-7cc73976.log
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-master-program-7cc73976.log
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-slave-program-7cc73976.log
raw/attempt-7cc73976-observer-runtime-error/wr-step5-f4d-timeline-7cc73976.log
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-7cc73976-observer-error.tgz
```

Transfer archive SHA256:

```text
9c01f1ffdbd6d0e7b3a9fed1eb70f86b6ff863c8c9fc8cb8531a93d1eb9eea87
```

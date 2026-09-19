# EXP-S5-F4J-OBSERVER-FRESHNESS-OFFLINE-20260920

## Verdict

```text
OBSERVER_ONLY_DIFF                 = PASS
PRODUCTION_CONTROL_DIFF            = NONE
FPGA_IMAGE_DIFF                    = NONE
F4J_TERMINAL_FRESHNESS_MODE        = SESSION_EDGE
F4J_STICKY_BASELINE_TEST           = PASS
F4J_FRESH_0_TO_1_TEST              = PASS
F4J_STREAK_STOP_TEST               = PASS
F4L_F4S_REGRESSION                  = PASS (offline model)
F4G_F4M_REGRESSION                  = PASS (offline model)
OFFLINE_TESTS                      = PASS (16/16)
F4J_OBSERVER_FRESHNESS_FIX         = OFFLINE_PASS
FPGA_BUILD_PROGRAM                 = NOT RUN
F4J_30S_PRODUCER_AUDIT             = STILL_NOT_RUN
STEP5_RESULT                       = NO
STOP_REASON                        = OFFLINE_TESTS_COMPLETE
```

The observer-only fix prevents a sticky historical WR failure from becoming a new F4J terminal on the first sample. A real `0→1` candidate transition still produces a fresh edge, and the existing two-sample streak stop remains intact. No FPGA image was rebuilt or programmed.

## Provenance

```text
experiment                         EXP-S5-F4J-OBSERVER-FRESHNESS-OFFLINE-20260920
branch                             exp/step5-softpll-lock
observer/test commit               b4ca04ac
FPGA image source commit           63bf952a3ea46dd0231f12d6d3e9b86d816ed953
observer file                      scripts/jtag/read_step5_main_frequency_prelock_observability.tcl
offline model/test                 scripts/tests/test_step5_terminal_freshness.py
existing regression adjusted       scripts/tests/test_step5_f4l.py
test runtime                       workspace-bundled Python
hardware/JTAG                      not used
```

The source commit contains only the Tcl observer role extension plus offline-test updates. The DE5A identity headers, SoftPLL production code, RTL, SDB, thresholds, PI/gain, timeout, mailbox, detector, and FPGA artifacts were not changed.

## Exact observer behavior

The combined `terminal_candidate` calculation is unchanged. Only the role classification changed:

```text
f4l / f4s / f4j  -> SESSION_EDGE
f4g / f4m        -> LEGACY
```

For F4J:

```text
first candidate=1       -> baseline previous=1, fresh_edge=0, terminal=0
candidate 1 -> 1         -> fresh_edge=0, terminal=0
candidate 1 -> 0         -> state_changed=1, terminal=0
candidate 0 -> 1         -> fresh_edge=1, terminal=1
fresh 0 -> 1 -> 1       -> streak=2, WR_SESSION_ENDED
```

The F4G/F4M legacy branch remains unchanged so explicit health/first-loss audits retain their prior semantics.

## Offline test execution

The test runner loaded and called every `test_*` function in:

```text
scripts/tests/test_step5_terminal_freshness.py
scripts/tests/test_step5_f4l.py
scripts/tests/test_step5_f4m.py
```

Result:

```text
PASS 16 tests: terminal freshness + F4L/F4M offline regression
```

This is an observer correctness result only. It does not authorize or imply a hardware F4J run, and it is not a Step5 pass.

# EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-THEN-TOGGLE-COMMIT-500X-20260901

## Scope

This experiment validates the request-side two-phase JTAG/Wishbone mailbox
protocol proposed by branch5 after the stable-completion audit found stable
but incorrect responses. It changes only the Tcl reader protocol. No RTL,
firmware, PI, control parameters, build output, or programming image was
changed in this run.

Baseline branch:

```text
exp/step5-softpll-lock
```

Baseline HEAD used on pain:

```text
48a48149db86a90229835c0dc0261e41079c9747
```

Hardware:

```text
DE5 [1-11.2]
QSFPA lane = 2
```

The raw console log was captured on pain at:

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-PRELOAD-THEN-TOGGLE-COMMIT-500X-20260901.log
```

## Protocol under test

For each logical Wishbone read, the Tcl reader performs:

1. PRELOAD: write the new address/data/sel/we with the currently completed
   toggle and wait 2 ms. This must not launch a transaction.
2. COMMIT: write the identical bundle with only the toggle inverted.
3. Wait for completion and idle.
4. Read the complete 64-bit completion probe three times with 1 ms gaps and
   accept only P1 = P2 = P3 with the expected completion toggle and idle bit.

The workload is unchanged from the previous audit:

```text
ITERATIONS = 500
LOGICAL REQUESTS = 10000
STATIC_A = 0x00100124 expected 0x02000200
STATIC_B = 0x00100128 expected 0x22334402
DMTD_REF = 0x00100298
DMTD_FB  = 0x0010029C
```

## Result

```text
ITERATIONS = 500
TOTAL_WB_REQUESTS = 10000
TOTAL_PROBE_READS = 50001

PRELOAD_COUNT = 10000
COMMIT_COUNT = 10000
PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0

PROBE_2WAY_MATCH_COUNT = 10000
PROBE_3WAY_MATCH_COUNT = 10000
STABLE_TRANSACTION_COUNT = 10000
UNSTABLE_TRANSACTION_COUNT = 0

STATIC_SIGNATURE_MISMATCH = 0
BOARD_ID_MISMATCH = 0
STALE_A5A5_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0

DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
DMTD_REF_TRIPLE_VALID = 500
DMTD_FB_TRIPLE_VALID = 500

INITIAL_COMPLETION_UNSTABLE_COUNT = 0
INITIAL_DATA_WRONG_BUT_STABILIZED_CORRECT_COUNT = 0
STABLE_RESPONSE_WRONG_COUNT = 0
PROBE_STABILIZATION_TIMEOUT_COUNT = 0
STATIC_SEQUENCE_VALID = 500
ADDRESS_SEQUENCE_VALID = 500
FIRST_ERROR = NONE
```

The Tcl audit classified the run as:

```text
PRELOAD_THEN_TOGGLE_COMMIT = PASS
REQUEST_BUNDLE_CAPTURE_RACE = CONFIRMED
JTAG_WB_READ_PATH_WITH_PRELOAD_PROTOCOL = PASS
```

## Interpretation

The same 500-iteration workload that previously produced stable wrong
responses is clean when address/data are preloaded before the toggle commit.
This is strong A/B evidence for the request-side bundled CDC/commit race:
the address/data bundle was not given a separate settling interval before the
request toggle was observed by the mailbox.

This result validates the Tcl mitigation and the generic JTAG/Wishbone read
path under this protocol. It does not by itself prove SoftPLL closed-loop
lock, frequency convergence, phase convergence, or long-duration stability.

## Milestone and merge status

```text
STEP4B_COMPLETE = YES (existing branch5 determination; not revalidated by this read-path-only audit)
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

No merge is permitted. The next controlled action is to apply the same
preload/commit discipline to the Step4B/V4 observer, then re-run the required
runtime validation before any Step5 or merge decision.

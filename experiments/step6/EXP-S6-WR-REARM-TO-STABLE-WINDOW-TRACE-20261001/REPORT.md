# EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001

## Verdict

~~~text
IMPLEMENTATION = OFFLINE_VALIDATED
PRODUCTION_CONTROL_CHANGES = NONE
TCL_POLICY_TESTS = PASS (341 assertions; Tcl 8.6.12)
TCL_OBSERVER_SYNTAX = PASS (info complete; Tcl 8.6.12)
PYTHON_ANALYZER_TESTS = PASS (6 tests)
WRAPPER_BASH_SYNTAX = PASS
LOCAL_GIT_DIFF_CHECK = PASS
PAIN_SOURCE_SYNC = PASS (Pain HEAD 8ac0141279c0209411f7d85c67143c360a3dc55f; branch feat/file_cleanup)
PINNED_SOF_HASH_PREFLIGHT = PASS (both expected SOF SHA-256 values matched)
PROGRAMMING = PASS (one Slave then Master programming sequence; no compile)
HARDWARE_CAPTURE = STOPPED_AFTER_FIVE_INVALID_REQUIRED_FRAMES
RECOVERY_ADMISSION_SUPPORTED = NOT_ESTABLISHED
PASS_300S_SAMPLED_STABLE_OFFSET = NOT_ESTABLISHED
STEP6_STABLE_OFFSET = NOT_ESTABLISHED
~~~

## Baseline

- Repository: <https://github.com/t5512355123/WR>
- Branch: `feat/file_cleanup`
- Source audit baseline: `00d1a6a5154238700bbcd674e2638a0e6f15932e`
- Candidate build source: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Expected Slave SOF SHA-256:
  `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19`
- Expected Master SOF SHA-256:
  `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a`

## Implementation and scope

This iteration adds a single Slave passive observer, a source-independent
policy module, mock tests, a conservative analyzer, and a bounded Pain wrapper.
The observer brackets each WDIAGS publication and Global-Time snapshot
separately, records individual A6C/A8C and event-word read times, and counts
only unique UCNT publications in a qualifying 300-second window.

No production control, firmware, RTL, build source, or SOF content is changed.
No compile is part of this experiment. The exact pinned SOFs must be verified
before the single authorized Slave-then-Master programming sequence.

## Validation and hardware evidence

Laptop offline checks passed: 341 Tcl policy assertions cover failure-word
decode, initial S_LOCK → timeout → PRESENT → S_LOCK → success admission,
valid sticky-disable stopping, invalid-frame streaks, same-UCNT payload
conflict, cached-publication rejection, unique-UCNT progression, strict ±60 ps,
and the 300-second window. The complete observer is Tcl-syntactically complete
under Tcl 8.6.12; six Python analyzer tests and the Bash wrapper syntax check
also pass. No production or build-source file was changed.

Pain was fast-forwarded to this experiment commit `8ac0141279c0209411f7d85c67143c360a3dc55f` on `feat/file_cleanup`. The pinned image hashes matched the plan:

~~~text
Slave SHA-256 13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19
Master SHA-256 697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a
~~~

The source/image provenance and actual SHA-256 values are preserved in
`raw/preflight/20260930T213359Z-image-provenance.txt`. The exact Slave image was
programmed once to `DE5 [1-11.2]`, followed by the
exact Master image once to `DE5 [1-11.1]`. Quartus reported successful
operations and 0 errors / 0 warnings for each. No compile was run. One
read-only Slave observer session then ran on 2026-10-01 05:36:35 UTC; no reset,
power-cycle, dashboard, or second reader was used.

The observer stopped itself after five consecutive invalid required frames
at `elapsed_ms=2208` (`samples=5`, `raw_valid=0`). The analyzer result is
`NOT_ESTABLISHED`, with `recovery_admission_supported=false` and
`stable_window_started=false`. It did not reach the recovery-admission event
or start the 300-second qualification window. This is an observer/data-validity
stop, not a Step 6 hardware failure or pass.

Across those five rows, the Step 1 gate stayed asserted and the observed reset
signature did not change. For every attempted WDIAGS frame, `DATA_VALID=1`,
`DATA_SNAPSHOT=0`, and the mapping word/inverse remained complementary, but
the mapping epoch changed during the read: `613→615`, `617→619`, `621→623`,
`625→627`, and `629→631`. The WDIAGS frame requires the full mapping word to
remain unchanged, so these payloads were correctly rejected. Read spans were
about 200–220 ms while the observed mapping publication advanced during each
span. This is consistent with an observer/read-duration versus publication-rate
mismatch; the short capture does not establish the source cadence or prove
that as the only cause. Global-Time frames were separately valid in some rows,
but WDIAGS and Global-Time are not atomic across groups and cannot be joined
into a trusted phase/lock verdict.

The capture also exposed an observer timestamp-key defect: timed reads store
`WR_STATE_RAW_READ_*`, `WR_RX_RAW_READ_*`, and `WR_TX_RAW_READ_*`, while the row
consumer expects `WR_STATE_READ_*`, `WR_RX_READ_*`, and `WR_TX_READ_*`. The log
therefore reports `STATE_READ_VALID=1` but `STATE_READ_BEGIN_MS=-1` (and likewise
for RX/TX). Treat those state/event timing fields as invalid; they cannot be
used for event ordering. This is separate from the mapping-epoch rejection.

All Pain raw evidence was copied to Laptop and the five files in the Pain
evidence hash manifest were verified byte-for-byte by SHA-256. The observer log
checksum also matches its sidecar. Analyzer output is retained under
`analysis/20260930T213635Z-analysis.json`. No second capture is authorized in
this experiment; await the advisor's next-step recommendation before further
hardware observation or code changes.

## Interpretation

This capture established neither recovery admission nor a stable-offset
result because all five required WDIAGS frames were rejected. It does not
establish a hardware failure. Even a future sampled 300-second pass would not
prove continuous behavior between samples or measure SMA physical edge skew.

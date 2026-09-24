# EXP-S5-BUMPLESS-FREQ-PHASE-PRELOAD-20260916

## Verdict

```text
TREATMENT_RESULT = INVALID_SESSION_START
DIAGNOSTIC_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

This was the first hardware run of the Main frequency-to-phase bumpless
integrator preload treatment. The run cannot evaluate the treatment because
the WR session terminated at startup, before a usable handoff window was
captured.

## Scope and source

```text
branch = exp/step5-softpll-lock
source_commit = 6fa075bdbd5bfaba5fd7e53c9bad026ee217097
observer = scripts/jtag/read_step5_main_frequency_prelock_observability.tcl
run_role = f4m
target_duration_ms = 120000
hard_duration_ms = 130000
timeout_wrapper_ms = 180000
```

The only production change was the Main frequency-to-phase preload. It is
gated to `dac_index == 0` and the actual frequency-detector lock transition,
and accounts for the same-sample `Ki*x` proposal and fixed-point bias/shift so
the first phase output should reproduce the preceding frequency-branch output.

The following remained frozen: Main `Kp=+300`, `Ki=+1`, frequency prelock gain
boost 20; Helper `Kp=-2250`, `Ki=-2`; Slave bootstrap 3388; all thresholds,
lock/delock samples, S_LOCK timeout, anti-windup, DAC ordering and polarity,
arbiter/mailbox, PHY, reset, RTL and SDB behavior.

## Offline validation

```text
test_step5_bumpless_preload: PASS
F4L regression: PASS
F4M regression: PASS
git diff --check: PASS
```

The fixed-point unit test proves that the preload preserves the first phase PI
output in the normal unclamped case and is not a plain integrator copy.

## Pain build and programming

Both images were pulled from the source commit and compiled successfully on
Pain. Timing was not closed, as in the preceding baseline:

```text
Master full compilation = successful
Master SOF checksum     = 0x30B89B19
Master WNS              = -0.047 ns
Slave full compilation  = successful
Slave SOF checksum      = 0x30B84088
Slave WNS               = -0.268 ns
TIMING_CLOSED           = NO
```

Programming succeeded on `DE5 [1-11.1]` and `DE5 [1-11.2]`. The mapping
preflight also passed for both boards (`begin_valid=1`, `end_valid=1`).

## F4M capture

The observer stopped after approximately 1.386 seconds:

```text
Master: WR_CORE_VALID=1 PHY_LINK_USABLE=1 PSTAT_LINK=1
        CURRENT_WR_STATE=3 TERMINAL=1 PSTAT_LOCKED=0
        WR_FAILURE_RAW=0x00006A00 WR_DISABLE_VALID=1 WR_FAILURE_REASON=0
Slave:  one F4M frame only, PSTAT_LOCKED=0
DONE:   smoke_ok=0 diag_valid=1 diag_unique=1
        run_end_reason=STOP_WR_SESSION_ENDED
```

The packed `WR_FAILURE_RAW=0x00006A00` must not be called a failure code.
Under the reader's field definition, its failure-state byte is zero and its
low 16-bit count field is `0x6A00` (27136). The terminal predicate in this
sample was instead `WR_DISABLE_VALID=1`; `WR_FAILURE_REASON=0` did not identify
a numbered lock failure.

Only one Slave frame was obtained (page 2). No before/after handoff pair was
captured, and this observer does not expose a preload-application counter.
Therefore this run provides no causal evidence that the preload caused the
session termination, and it cannot establish any Step5 criterion.

## Follow-up

The run was classified as a session-level startup-terminal artifact. The
required follow-up is recorded separately in
`EXP-S5-BUMPLESS-FREQ-PHASE-PRELOAD-COLD-REPLAY-20260916`: complete physical
power cycle, reprogram the same images, require a clean entry gate, and only
then repeat the exact F4M capture. No control parameter or preload code was
changed for that replay.

## Artifacts

```text
raw/observer-f4m.log
raw/wdiags-preflight.log
raw/build/build_info_jtag_master.txt
raw/build/build_info_jtag_slave.txt
raw/build/quartus_jtag_master_compile.log
raw/build/quartus_jtag_slave_compile.log
analysis/f4m-verdict.json
```

SHA-256:

```text
observer-f4m.log     167A49632BBC21E81292CFAC0A0F9D438E8C5DDCDD935079569969EB333869A3
wdiags-preflight.log 80F2147A8831EFAA7612ED95C8C2B987117C45DF366714D42784743A5B8C1674
```

# EXP-S5-WR-FAILURE-REASON-AUDIT-61B9AA8-VALID-MIF-20260913

## Verdict

```text
EXPERIMENT_CLASSIFICATION = VALID_WR_S_LOCK_TIMEOUT_NO_STEP5
STEP1_PHY_LINK            = PASS_AT_STARTUP_ONLY
STEP2_ENDPOINT_PTP        = PARTIAL
STEP3_WR_HANDSHAKE        = FAIL_WR_S_LOCK_TIMEOUT
STEP4_SOFTPLL_STARTUP     = PARTIAL_ONLY_NOT_PASS
STEP5_CLOSED_LOOP_LOCK    = NOT_COMPLETE
STEP6_GLOBAL_TIME         = NA
MERGE_TO_MAIN             = NOT_ALLOWED
```

This is a valid diagnostic run because the firmware MIFs were rebuilt from
commit `61b9aa8` before Quartus compilation. It does not prove Step5.

## Objective

Attribute the first WR handshake failure to a concrete state-machine path,
without changing PI, DMTD, DAC, PHY, reset, arbiter, or WR control behavior.
The added telemetry records a sticky failure reason and timer low word in the
existing `WDIAGS WR_LOCK_RESULT` shadow.

## Source and build identity

```text
branch = exp/step5-softpll-lock
commit = 61b9aa8c2a374ec5f400b0a143b12b2ba0bbec25
host   = pain
Quartus = Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition
```

The required build order was completed:

1. `firmware/scripts/build_master_firmware.sh`
2. `firmware/scripts/build_slave_firmware.sh`
3. `scripts/build/build_jtag_master.sh`
4. `scripts/build/build_jtag_slave.sh`

```text
Master MIF SHA256 = 327af856fd846f8fdafa3bf836a25cfdb358e9d40ffded8682a3d4e07d7a8229
Slave  MIF SHA256 = 75104c32c2b724263f4c12dc10504ee458e6cc450cd1ef1e1bf3661d034607a1
Master SOF SHA256 = 1177fcbcfd2777e923d98074a346dfe77f2de2dc60322a147ca161faab2190ac
Slave  SOF SHA256 = 33d86ba277ce2998f0f6408a182518a519bef7bae8bb383621148ac67caaba61
Master WNS       = -0.058 ns
Slave  WNS       = +0.015 ns
TIMING_CLOSED    = NO (both images)
```

Both boards were programmed successfully with zero errors and zero warnings:

```text
Master cable = DE5 [1-11.1]
Slave  cable = DE5 [1-11.2]
```

## Observation

The read-only startup observer ran for 600000 ms and completed successfully:

```text
observer_status = 0
elapsed_ms      = 602000
samples         = 285
sample_errors   = 0
```

The first-event summary was:

```text
FIRST_CORE_TM_LINK_UP_MS       = 463
FIRST_CORE_LINK_OK_MS          = 463
FIRST_PTP_RX_ACTIVITY_MS       = 463
FIRST_PTP_TX_ACTIVITY_MS       = 463
FIRST_DMTD_ACCEPT_MS           = 463
FIRST_PTP_SLAVE_MS             = 193187
FIRST_PDSTATE_PDETECTED_MS     = 463
FIRST_PDSTATE_FAILURE_MS       = 193187
FIRST_EXTSTATE_ACTIVE_MS       = 463
FIRST_EXTSTATE_PTP_MS          = 193187
FIRST_PARENT_WR_CALIBRATED_MS  = 463
FIRST_LOCK_ENABLE_MS           = 463
FIRST_HELPER_LOCKED_MS         = 25661
FIRST_MAIN_ENABLED_MS          = 280599
FIRST_MAIN_FREQ_LOCKED_MS      = NEVER
FIRST_MAIN_PHASE_LOCKED_MS     = NEVER
FIRST_MAIN_LOCKED_MS           = NEVER
FIRST_SPLL_INIT_MS             = 463
FIRST_TAG_VALID_MS             = 463
FIRST_TRR_WRITE_MS             = 463
FIRST_TRR_POP_MS               = 463
FIRST_IRQ_MS                   = 463
FIRST_HELPER_UPDATE_MS         = 463
FIRST_PSTAT_LOCKED_MS          = 366907
FIRST_INACTIVE_BOUNDARY        = WR_EXTENSION_FAILURE
UNCLASSIFIED                   = 0
```

The decisive late sample was:

```text
timestamp_ms=599997
core_tm_link_up=1
core_link_ok=1
PTP_STATE=9(SLAVE)
PPSI_PDSTATE=4(FAILURE)
PPSI_EXTSTATE=2(PTP)
WR_STATE=WRS_IDLE
WR_FAILURE=02020001
WR_LOCK_RESULT=DA030601(code=1,check_lock=0,fail_reason=3(WR_S_LOCK_TIMEOUT),fail_tics_low16=55811)
SPLL_SEQ_STATE=6(SEQ_WAIT_MAIN)
SPLL_HELPER_STATE=03E80001(locked=1)
SPLL_MAIN_STATE=00000001(enabled=1,freq_locked=0,phase_locked=0,locked=0)
PSTAT_LOCKED=0
```

`WR_FAILURE=02020001` means WR slave role, last WR state `WRS_S_LOCK`,
failure count 1. The sticky `WR_LOCK_RESULT` reason code 3 independently
identifies the failing call site as the `WRS_S_LOCK` timeout path. It is not
the suspected `NO_WR_PARENT` path.

The helper lock and Main enable events show that the internal SoftPLL is
running, but the WR extension has already fallen back to ordinary PTP before
the Main frequency/phase/overall lock criteria are met. Therefore the later
internal counters cannot be promoted to a valid system Step5 pass.

## Important build-process correction

An earlier preliminary run in the sibling folder
`EXP-S5-WR-FAILURE-REASON-AUDIT-61B9AA8-20260913` ran Quartus without first
rebuilding firmware. Its MIF hashes were unchanged from the prior experiment,
so its `fail_reason=NEVER` result is explicitly invalid and is not used here.
This corrected run rebuilt both MIFs before Quartus and is the authoritative
result.

## Interpretation

The low-perturbation telemetry answered the immediate diagnostic question:

```text
WR extension failure = WRS_S_LOCK timeout
NO_WR_PARENT         = not observed as the first decisive failure
core link            = still up at the 600 s final sample
helper lock          = reached
main frequency lock  = never reached
valid Step5 lock     = not reached
```

The next investigation must stay at the S_LOCK boundary. In particular,
audit the complete `locking_poll()` acceptance path and correlate its return
value with the `WR_S_LOCK_TIMEOUT_MS` timer and retry counter. The source has
`WR_STATE_RETRY=3` and arms the S_LOCK timer using
`WR_S_LOCK_TIMEOUT_MS*(WR_STATE_RETRY+1)`, while the observed failure is about
193 s after startup in this run. That discrepancy must be explained before
another timeout or PI change is attempted.

## Next experiment

Make one additional read-only telemetry change only:

1. Record S_LOCK entry timestamp, retry value, configured timeout, and every
   `locking_poll()` return/lock-detector result.
2. Record each retry transition and the exact failure timestamp.
3. Keep the 15/60 s timeout constants, SoftPLL parameters, and all control
   behavior unchanged.
4. Rebuild firmware first, then Quartus, program both boards, and repeat the
   600 s observer.

The next functional change should be selected only after this evidence shows
whether S_LOCK is timing out because no accepted lock event is produced, the
timer is armed/reset unexpectedly, or the state machine is receiving a
different transition than expected.


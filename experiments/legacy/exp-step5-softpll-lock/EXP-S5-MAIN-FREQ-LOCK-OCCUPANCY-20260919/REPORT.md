# EXP-S5-MAIN-FREQ-LOCK-OCCUPANCY-20260919

## Verdict

```text
SLAVE_TRACE_VALID                    = PASS (20/20 accepted)
MAIN_FREQ_LOCK_ACCEPTANCE_MARGIN     = SUPPORTED
MAIN_FREQ_LOCK_HYSTERESIS_RETENTION  = NOT_SUPPORTED_BY_THIS_TRACE
MAIN_FREQUENCY_BRANCH_REENTRY        = NOT_OBSERVED
MAIN_PHASE_LOCK_OBSERVED             = NO (0/20)
STEP5_RESULT                          = NO
STOP_REASON                           = SAMPLE_20_COMPLETE
```

The trace supports the acceptance-margin boundary: Main remained `freq=1` for all 20 valid Slave samples, while the frequency counter was saturated at `50/50` in 18 samples and only briefly dipped to 49 and 48 before returning to 50. No Main frequency-branch re-entry was observed. This identifies the next causal boundary but is not a Step5 pass and does not by itself prove the residual error value in each sample.

## Provenance

```text
experiment                         EXP-S5-MAIN-FREQ-LOCK-OCCUPANCY-20260919
source commit                      db7e0be12fcf1268059b916be6a21437da286fdd
prior formal report commit         63883c92
session                            same freshly programmed Ki=0 session
Slave SOF SHA256                   fa5de2430152190f61eb54c63506103a7ce7f676b0e0945f02a1957baa65ae60
Master SOF SHA256                  7e5ef99bc74d9f8e65d147a68d28a2c47985800d7422e84eb224632034b32dee
command                            read_wb_timeseries_session.tcl 20 500 3
valid invocation                   /mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp
raw SHA256                         959440F9DE6BEDAE90BE6F9B81FD0E4D97345D0F6F04ADAEB37CBDDE496C8191
raw capture                        raw/freq_lock_occupancy_20x500_20260919.log
```

The command was run once in the existing Pain session. No firmware or hardware image was changed before or after the trace.

## Slave occupancy evidence

All 20 Slave samples were accepted by the session reader:

```text
SESSION_SAMPLE_RESULT accepted     = 20/20
HELPER locked                      = 20/20
HELPER lock count                  = 1000/1000 in all 20 samples
MAIN enabled                       = 20/20
MAIN freq                          = 1 in 20/20
MAIN phase                         = 0 in 20/20
PSTAT_locked                       = 0 in 20/20
WR delock_count                    = 0 in 20/20
```

The Main frequency counter occupancy was:

```text
sample  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
freq_cnt 50 50 50 49 50 50 50 50 50 48 50 50 50 50 50 50 50 50 50 50
```

```text
freq_cnt = 50/50       18/20 samples
freq_cnt < 50           2/20 samples (49 at sample 4; 48 at sample 10)
minimum / maximum       48 / 50
MAIN freq = 0           0/20 samples
```

The trace also kept `MAIN enabled=1` and `seq_state=6 (SEQ_WAIT_MAIN)` throughout the valid Slave samples. The historical WR failure shadow remains present in the raw lock word, but it did not prevent the 20 samples from being accepted and is not used here as a fresh-terminal event.

## Interpretation

This is consistent with:

```text
residual frequency error remains
        ↓
frequency detector stays inside/near its acceptance window
        ↓
freq_cnt remains near saturation (48–50/50)
        ↓
MAIN freq remains locked
        ↓
controller remains in phase branch
        ↓
phase continues to ramp without phase lock
```

Therefore:

```text
MAIN_FREQ_LOCK_ACCEPTANCE_MARGIN     = SUPPORTED
MAIN_FREQ_LOCK_HYSTERESIS_RETENTION  = NOT_SUPPORTED_BY_THIS_TRACE
MAIN_FREQUENCY_BRANCH_REENTRY        = NOT_OBSERVED
```

The trace does not directly sample the residual frequency error, so it does not justify changing the threshold or claiming that a threshold change is the fix. It only closes the requested occupancy question.

## Safety boundary

```text
reprogramming                       = NONE
F4L                                  = NOT_RUN
Ki/Kp/gain/threshold/timeout changes = NONE
STEP5                                = NO
```

## Next action gate

Send this result to the phase-lock advisor and wait at least 10 minutes for the next reply. Do not change the frequency threshold, delock floor, PI parameters, or run F4L until that reply is read.

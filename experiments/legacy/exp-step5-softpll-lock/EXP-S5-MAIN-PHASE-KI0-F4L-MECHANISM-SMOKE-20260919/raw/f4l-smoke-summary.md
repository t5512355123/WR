# F4L mechanism smoke summary

One valid invocation, same Ki=0 session:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l
```

Final observer summary:

```text
STEP5_F4L_SMOKE result=PASS valid=11 unique=6 page0=4 page1=3 page2=4
STEP5_F4L_DONE session_elapsed_ms=10214 target_duration_ms=10000 hard_duration_ms=130000
slave_cycles=11 master_samples=3 smoke_ok=1 run_end_reason=TARGET_REACHED stop_reason=NONE
schedule_valid=0 schedule_invalid=0
step5_complete=NO step5_pass=NO
```

Visible valid page-1 mechanism fields included:

```text
PHASE_UPDATES > 0
phase_actual_i_sum = 0
phase_ki_x_sum = 0
frequency_actual_i_sum = frequency_ki_x_sum
clamp=0 anti_windup=0 actual_delta_mismatch=0
```

The smoke observed no fresh terminal edge and no reset or link regression. The advisor then authorized a same-session 120-second formal capture without reprogramming.

## Formal 120-second capture

Command:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 120000 130000 f4l
```

Raw log:

```text
f4l_formal_ki0_120s_20260919.log
SHA256=571A1795535967AE74B546A57A0E5B3AFB793D344FA33BC327338182B85A966E
```

Final observer summary:

```text
STEP5_F4L_DONE session_elapsed_ms=120501 target_duration_ms=120000 hard_duration_ms=130000
valid=127 unique=64 page0=43 page1=42 page2=42
main_progress_intervals=63 valid_time_bins_10s=13
run_end_reason=TARGET_REACHED stop_reason=NONE
```

Formal mechanism deltas:

```text
phase_updates_delta=433712
phase_actual_i_sum_delta=0
phase_ki_x_sum_delta=0
frequency_updates_delta=0
frequency_actual_i_sum_delta=0
frequency_ki_x_sum_delta=0
clamp_event_count_delta=0
anti_windup_event_count_delta=0
actual_delta_mismatch_delta=0
```

Formal runtime checks:

```text
helper_unlocked_with_main_valid=0
semantic_problems=[]
fresh_terminal_edges=0
reset_changed=0
transport_failure=0
PSTAT_LOCKED=1 observed count=0
```

Normalized comparison against the frozen baseline:

```text
mean phase freq error       43.9898 -> 43.0381   improved 2.16%
mean phase drift magnitude   43.9854 -> 43.0342   improved 2.16%
boundary crossing rate        0.26850% -> 0.26263% improved 2.19%
phase in-band ratio          13.4393% -> 13.4219% decreased 0.0174 pp
```

Classification:

```text
PHASE_KI0_IMPLEMENTATION    = PASS
PHASE_KI0_DIRECTION         = MIXED_NEAR_BASELINE
PHASE_KI0_CAUSAL_HYPOTHESIS = INCONCLUSIVE
STEP5                       = NO
```

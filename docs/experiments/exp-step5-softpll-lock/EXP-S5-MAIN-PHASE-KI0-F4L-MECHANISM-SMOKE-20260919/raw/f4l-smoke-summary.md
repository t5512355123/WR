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

The smoke observed no fresh terminal edge and no reset or link regression. No formal 120-second run followed.

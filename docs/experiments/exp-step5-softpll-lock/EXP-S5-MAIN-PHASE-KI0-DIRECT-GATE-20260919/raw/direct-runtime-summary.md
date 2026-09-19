# Direct runtime summary

One valid invocation was executed in the existing Pain session:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

Key Slave fields from the terminal transcript:

```text
Step1=PASS
Step2=PASS
Step3=PASS
STEP4B_ALLOWED=YES
STEP4B_RESULT=PASS
SPLL_SEQ_STATE=6 (SEQ_WAIT_MAIN)
SPLL_HELPER_STATE=03E80001 (locked=1, count=1000/1000)
SPLL_MAIN_STATE=09803205 (enabled=1, freq_locked=1, phase_locked=0)
MAIN_PHASE_COUNT=152/1000
PSTAT_LOCKED=0
BOOT_GENERATION delta=0
CPU_RESET_COUNT delta=0
WR_CORE_RESET_COUNT delta=0
SI_CONFIG_DROP_COUNT delta=0
RXERR delta=0
WR_FAILURE_DEBUG=TIMEOUT last_fail_state=WRS_S_LOCK failure_count=35329
LOCK_RESULT=6D500601
WR_FAILURE_REASON=(LOCK_RESULT bits 9..15)=3=WR_S_LOCK_TIMEOUT
F4L=NOT_RUN
```

The Master was healthy and its Step4A chain passed; Step5 is Slave-only. The runtime script completed with zero Quartus errors.

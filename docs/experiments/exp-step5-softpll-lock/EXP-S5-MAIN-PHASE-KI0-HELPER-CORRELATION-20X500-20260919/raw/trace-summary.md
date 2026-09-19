# Trace summary

This file records the one valid Pain invocation. It is a summary of the interactive terminal transcript, not a replacement for a redirected raw log.

```text
command=/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 500
config=samples=20 gap_ms=500
result=HPLL_HELPER_CORRELATION_DONE
quartus_errors=0

board=DE5 [1-11.2] Slave
later_consecutive_samples=005..020
HELPER_STATE=03E80001 (locked, lock_count=1000)
HELPER_ERROR approximately -230..+348 in the visible consecutive records
STEP_DELTA approximately 557..580, non-zero
STEP_EVENT=1
ERROR=0
classification=HELPER_LOCK_ACQUIRED_AND_HELD / DCO_SERVICE_ACTIVE

board=DE5 [1-11.1] Master
HELPER_STATE=00060100
STEP_DELTA=0
classification=not used for Slave acquisition gate
```

No second hardware trace was run.

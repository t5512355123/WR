# EXP-REPRO-BUILD-TIMING-20260815

## Goal

Verify the final build identity and collect timing evidence after adding the
reproducibility metadata fields to the Quartus build wrappers.

## Change

Only build/documentation changes were made. The WR functional source,
pre-emphasis, QSFP lane, clock constraints, Master/Slave role and probe mapping
were not changed.

## Build evidence

- Git commit: `0a8f44afa5b26111a1103903968bf173e210ee92`
- Host: `pain`
- Quartus: Prime 17.0 Build 595
- Master firmware: PASS
- Slave firmware: PASS
- Master Quartus: `Full Compilation was successful`, 0 errors
- Slave Quartus: `Full Compilation was successful`, 0 errors
- Master SOF: `9a779de65eb0df89de28194e869bbda99b26ba6603ec4af2c539f8e805248d1b`
- Slave SOF: `1849a8a1a446df738be2b6b258c387bc6141d5c8b9f1ea9d2d199b98c5a002a5`

## Timing evidence

| Revision | Setup | Hold | Recovery | Removal | Timing closed |
|---|---:|---:|---:|---:|---|
| Master | -3.812 ns | 0.039 ns | -1.975 ns | 0.298 ns | NO |
| Slave | -3.103 ns | 0.030 ns | -1.839 ns | 0.326 ns | NO |

The negative setup and recovery slack is recorded as an existing technical
condition. It is not silently reclassified as a successful timing closure.

## Conclusion

The build workflow now emits enough identity data to trace a SOF back to its
Git commit, MIF, QSF, SDC, Quartus version and timing report. This experiment
does not claim that a new bitstream was programmed or that WR time
synchronization is complete.

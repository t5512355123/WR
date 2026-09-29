# Post-change Pain capture summary

Console excerpts and exact build/program identities for
`EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929`. The coherent servo observer's
complete verbose stdout was not redirected to a file; the summary below is
transcribed from its terminal output.

## Build identity

- Repository commit: `edd525a2104a7bc68c6db13fcaa1a1368c117095`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Quartus: 17.0.0 Build 595, Standard Edition
- Master MIF SHA-256: `5497f5d88037162bf622f8bf1619cd20a2ceb35684d08ae07f66c16118d9a471`
- Slave MIF SHA-256: `30b39dd04b9d087fb90c24ab87e89f9ff78b1fd342775e192817c618a69a6d3e`
- Master SOF SHA-256: `83548dffe0350827ad9e314f03220175c47d6821f1c0a0f15a3b865be87cdb6a`
- Slave SOF SHA-256: `9e972ed4a858f3d21b105fc429a033f1267132ca0b4746d7430e78781f2bec0a`
- Full Quartus compilation: PASS for both boards; `TIMING_CLOSED=NO` for both.

## Programming

- Slave cable `DE5 [1-11.2]`, 2026-09-29 14:08:20–14:08:39 +08:00:
  successful; device checksum `0x30B1E229`; one device configured; 0 errors,
  0 warnings.
- Master cable `DE5 [1-11.1]`, 2026-09-29 14:08:52–14:09:10 +08:00:
  successful; device checksum `0x30B18F28`; one device configured; 0 errors,
  0 warnings.

## Dashboard and servo observer

At 14:09:46, Master was Global-Time valid. Slave showed Link/TM=1 but
`WR_SERVO_STATE=SYNC_TAI`, Step 2/4/5 not ready, and `TIME_VALID=0`.

The one-shot Global-Time readiness wait expired at 180 seconds (final poll at
189 seconds). At 14:13:17, Master remained valid; Slave still showed:

```text
Step2=INFO  Step3=PASS  Step4=INFO  Step5=INFO/UPSTREAM_NOT_READY
WR_SERVO_STATE=SYNC_TAI
WR phase offset diagnostic=1501442945 ps (signed 32-bit projection)
TIME_VALID=0  PPS_VALID=0  SNAPSHOT_VALID=0  SNAPSHOT_STABLE=1
```

A subsequent 30-second read-only coherent trace reported:

```text
duration_ms=30000  sample_ms=1000  READ_ONLY=1
coherent_rows=21  adjacent_update_pairs=13
same_counter_payload_conflicts=0  reset_stop=0
servo update counter: 0x22 -> 0x3E (with some skipped observations)
PTP_STATE=8  SERVO_STATE=SYNC_TAI  SETP_PS=0 throughout
TIME_VALID=0  RESET_CHANGED=0 throughout
CKO_PS at first coherent row=1597906945
CKO_PS at last coherent row=1641486945
```

Dashboard and observer read diagnostic groups at different times; do not
combine their PPS status bits into an atomic sample. The decisive observation
is that the servo stayed in `SYNC_TAI` and never exercised the changed
`WRH_SYNC_PHASE` branch. No PTP command, WB write, reset, or additional
programming occurred during observation.

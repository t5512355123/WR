# EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-SIXTEENTH-20260930

## Verdict

- Candidate build: PASS.
- Slave then Master programming: PASS.
- Startup/readiness gate within the planned dashboard window: FAIL; Slave Global Time never became valid.
- Offset smoke: NOT RUN (entry gate not met).
- Strict offset target below 60 ps: NOT EVALUATED.
- STABLE_OFFSET_300S: NOT RUN; this experiment is not a Step 6 pass.

The run provides no valid CKO-offset evidence for or against the /16 tracking hypothesis. It must not be interpreted as a servo-offset failure or success.

## Candidate and provenance

The only functional change relative to the previously programmed /2 acquisition + /8 tracking candidate was changing WRH_TRACK_PHASE correction from offset_ps / 8 to offset_ps / 16. WRH_SYNC_PHASE acquisition remained offset_ps / 2. The strict 60 ps threshold and all other control, PPS/TAI, timeout, reset, RTL, SDB, and timing-constraint behavior remained unchanged.

- Repository branch and Pain HEAD: feat/file_cleanup, 1b976088f72b052ddcc79757b51d88f4313dc457.
- Frozen source origin commit: 74dc28862653d306e0450cf437ba6d3a230d979d.
- Focused offline candidate tests and patch checks: PASS (3 tests; patch applies; diff check clean).
- Temporary source patch was reversed after build/program. The 3,219-entry source manifest and 4-entry milestone artifact manifest were verified restored; the saved manifest output reports all files OK.

## Build and programming

Both full Quartus compilations succeeded with zero errors. Master reported 297 warnings; Slave reported 299 warnings. Timing was not closed (Master worst setup slack +0.262 ns; Slave -0.659 ns); timing closure was not used as the functional acceptance gate.

- Slave SOF SHA-256: 2e9b0506ee56aac7ee2b7ab2e95f6fd02b214b9a2e7f5621af41eb778630d639.
- Master SOF SHA-256: 266249600456dcdbeee5955dc830e7aa980e25b097a30471681a6fe971e9ad57.
- Slave DE5 [1-11.2] programming completed 11:42:40 +08:00: 1 device configured, JTAG ID 0x02E660DD, zero errors/warnings.
- Master DE5 [1-11.1] programming completed 11:42:58 +08:00: 1 device configured, JTAG ID 0x02E660DD, zero errors/warnings.

## Read-only startup observation

The dashboard sampled every 10 seconds from 11:44:17 through 12:13:07 +08:00: 174 frames over 28 minutes 50 seconds. The 30-minute observation window elapsed without the Slave readiness gate.

In all 174 frames:

- Master link and Global Time remained valid.
- Slave Step 1/link and dashboard Steps 2–4 remained PASS; Link/TM/RX/TX showed 1.
- The five displayed Slave Step 5 signals (Helper, Main frequency, Main phase, Main lock, PSTAT) showed 1, but the dashboard verdict remained LOCK_ACQUIRED_NOT_STABLE.
- Slave Step 6 remained WAITING: TIME_VALID=0, PPS_VALID=0, snapshot=0, stable=1, count=0; TAI/CYCLES were unavailable.

Because Slave Global Time never became valid, the experiment's readiness gate was not met. No interleaved offset smoke or 300-second capture was started. Consequently there are no accepted CKO samples, no measured in-band percentage, and no 300-second stability claim.

## Evidence integrity

All 51 raw files copied from Pain were SHA-256 compared against the source files on Pain; every digest matched. The checksums are recorded in raw/SHA256SUMS. The dashboard capture is raw/observe/dashboard-20260930T1143.log.

## Next-step implication

This run isolates a startup/readiness failure, not an offset result. The /16 tracking response hypothesis remains unresolved. The next experiment must first restore a valid Slave Global Time readiness gate before collecting any offset data; it must retain the strict <60 ps and continuous 300-second acceptance criteria.

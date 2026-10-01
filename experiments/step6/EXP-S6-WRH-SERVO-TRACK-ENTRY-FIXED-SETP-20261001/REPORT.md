# EXP-S6-WRH-SERVO-TRACK-ENTRY-FIXED-SETP-20261001 — Report

## Verdict

```text
SOURCE_TESTS                         = PASS (5 source + 3 analyzer + 6 dashboard tests)
SOURCE_COMMIT                        = a62c264dbbfc15b31c316188dd7f851d28ec2a6d
PAIN_BUILD_PROGRAM                   = PASS (both boards)
TRACK_ENTRY                          = NOT_REACHED (600 s readiness timeout)
FIXED_SETP_LATCH_EXERCISED           = NO
FIXED_SETP_SMOKE                     = NOT_RUN
STEP6_STRICT_OFFSET_300S_STABILITY  = NOT_ESTABLISHED
```

This is a diagnostic candidate. No Step 6 pass is claimed until a fully
qualified 300-second capture meets every gate in `PLAN.md`.

## Candidate

The candidate adds a boot-lifetime one-shot SETP latch at the first successful
`WAIT_OFFSET_STABLE → TRACK_PHASE` transition. After latching, servo init,
`SYNC_PHASE`, and `TRACK_PHASE` cannot alter the phase setpoint or call
`adjust_phase()`. Coarse time correction and unrelated controls remain
unchanged. The latch is independent of the existing IPC tracking-enable flag.

The parent in-band-hold candidate reached `TRACK_PHASE`, valid Global Time,
and all five Step 5 lock signals, but its two short captures had coherent CKO
samples outside ±60 ps. This candidate was intended to test whether those
excursions continue with SETP fixed. The current run did not reacquire TRACK,
so the latch was never exercised; it is inconclusive about fixed-SETP behavior.

## Build and programming

Pain built both complete firmware/Quartus images from the exact candidate
commit. Both full compilations and fitter runs succeeded. Timing closure was
not a functional gate for this experiment.

| Board | Cable | SOF SHA-256 | Programmer result | Timing metadata |
|---|---|---|---|---|
| Slave | `DE5 [1-11.2]` | `5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018` | One device configured; zero errors/warnings; checksum `0x30B1E229` | `TIMING_CLOSED=NO`, worst setup slack `−0.659 ns` |
| Master | `DE5 [1-11.1]` | `9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5` | One device configured; zero errors/warnings; checksum `0x30B18F28` | `TIMING_CLOSED=NO`, worst setup slack `+0.262 ns` |

The Pain build-info records bind both SOFs to source commit
`a62c264dbbfc15b31c316188dd7f851d28ec2a6d` and Quartus 17.0.0 Build 595.
The complete build metadata and logs are retained under
[`raw/pain-a62c264d/build/`](raw/pain-a62c264d/build/).

## Readiness observation

The single read-only dashboard produced 88 complete paired observations from
`2026-10-01T11:12:51+08:00` through `11:23:04+08:00`. Master Step 1/link and
Global Time remained valid in all 88 observations. Slave Step 1/link and WR
handshake remained valid in all 88, but:

```text
Slave WR PTP servo state = SYNC_TAI              88/88
Slave Step 4              = INFO                 88/88
Slave Step 5              = INFO                 88/88
Slave Step 6              = WAITING              88/88
Slave TIME_VALID/PPS_VALID= 0/0                  88/88
Slave Helper/Main locks   = 0                    88/88
Slave TRACK_PHASE         = not observed
```

The dashboard's displayed `WR phase offset` ranged from
`−377,803,999 ps` to `+444,476,001 ps`. These are readiness-dashboard servo
offset values, not qualified CKO measurements. No interleaved CKO/DMS/SETP
capture was run. Since the strict `<60 ps` WAIT→TRACK transition never
occurred, `FIXED_SETP_LATCH_EXERCISED=NO`; no conclusion about the latch or
whether CKO excursions persist under fixed SETP is possible.

The prescribed 600-second readiness limit was exceeded: Master programming
completed at `11:12:15+08:00`, and the final dashboard frame was at
`11:23:04+08:00` (about 649 seconds after programming, approximately 49
seconds beyond the planned deadline). The dashboard was then interrupted; no
board reset or power cycle occurred. This protocol deviation is retained as
part of the result.

Per the plan's stop condition, there was no smoke and no 300-second capture:

```text
FIXED_SETP_SMOKE                     = NOT_RUN (TRACK not reached)
STEP6_STRICT_OFFSET_300S_STABILITY  = NOT_ESTABLISHED
```

The run is classified `INCONCLUSIVE_BASELINE_NOT_REACQUIRED`: it says nothing
about CKO motion with a frozen SETP because the required first TRACK entry
never occurred. The dashboard's `WR phase offset` is not substituted for CKO.

## Raw evidence and integrity

Pain-to-Laptop byte identity was verified for the readiness log. SHA-256:

```text
raw/pain-a62c264d/observe/readiness.log
  8730d616931d2987d216c303023bf758129c3a4f2a24dd2399f5a01fb4de5e02
raw/pain-a62c264d/evidence.tar.gz
  e15669cdf1efcdd724898579ff625ea504218bf70fd1afe5f9d3465e14cc800d
```

The archive contains the original readiness log, both build wrapper logs,
both build-info records, and both complete Quartus compile logs. The latch
was not reached, so this run neither supports nor refutes the fixed-SETP
causal hypothesis. The stable-offset Step 6 extension remains
`NOT_ESTABLISHED`.

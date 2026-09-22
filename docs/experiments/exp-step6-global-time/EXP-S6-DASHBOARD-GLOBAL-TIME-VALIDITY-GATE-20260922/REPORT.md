# EXP-S6-DASHBOARD-GLOBAL-TIME-VALIDITY-GATE-20260922

日期：2026-09-22（Asia/Taipei）

## Verdict

```text
DASHBOARD_GLOBAL_TIME_GATE       = PASS
MASTER_TIME_VALID                = PASS
MASTER_PPS_VALID                 = PASS
SLAVE_TIME_VALID                 = PASS
SLAVE_PPS_VALID                  = PASS
MASTER_TAI_CYCLES                = 117 / 124999999
SLAVE_TAI_CYCLES                 = 121 / 124999999
BOUNDED_WAIT                     = PASS (within 120 seconds)
POWER_CYCLE                      = NO
```

這輪已確認：重新編譯、燒錄後，即使立即讀取時兩板尚未完成 Global-Time
snapshot，也可以在不斷電、不 reset 的情況下由 dashboard 等待到可信狀態，
再顯示兩板的 TAI/CYCLE。面板端沒有捏造數值；只有所有有效性條件成立時才
結束等待並顯示 `VALID`。

## Source and image provenance

```text
branch                         = exp/step6-Global-Time-Testing
source commit                  = 7b22b5c716e99e273ac6bbcd58077fc814e0b2e1
dashboard change               = bounded read-only Global-Time wait
Quartus                        = 17.0.0 Build 595
Slave SOF SHA256               = 676ef0be0b091128b6e61e82ce462d2c4075bb469d78c68c00dd6e6e1abb7e50
Master SOF SHA256              = ebabf631b3d0727e9305fd4643565623626444e98e3e4ecf75aa1e45c34bbb44
```

Compile completed with zero Quartus errors. Timing warnings/closure are kept as
implementation metadata and are not a Global-Time dashboard gate.

## Required workflow

1. Laptop modified only `scripts/monitor/step1_6_dashboard.sh` and added this
   experiment plan, then pushed commit `7b22b5c7`.
2. Pain pulled that exact commit into a clean worktree. The previous Pain
   worktree containing uncommitted raw evidence was preserved untouched.
3. Pain compiled both existing fitted Step6 Master/Slave designs and
   programmed Slave first, then Master. Both Programmer operations reported
   one configured device and zero errors.
4. The dashboard was run read-only with:

   ```text
   ONCE=1 CLEAR_SCREEN=0 OBS_GAP_MS=2000 INTERVAL_SECONDS=10
   WAIT_FOR_GLOBAL_TIME_SECONDS=120 WAIT_FOR_GLOBAL_TIME_POLL_SECONDS=5
   ./scripts/monitor/step1_6_dashboard.sh
   ```

5. The raw evidence was copied back to Laptop for this report.

No Wishbone, ARM, VUART, PTP, reset, PHY, PPS, or SoftPLL control write was
performed by the dashboard gate.

## Dashboard evidence

The first seven read attempts reported that both visible boards were still
waiting for valid snapshots at elapsed times 9, 23, 37, 51, 65, 79, and 93
seconds. The next read completed successfully at `2026-09-22T14:23:49+08:00`.

Final board summaries:

```text
MASTER  DE5_1-11.1
  Step 6 Global Time = VALID
  TIME_VALID=1, PPS_VALID=1
  SNAPSHOT_VALID=1, SNAPSHOT_STABLE=1, SNAPSHOT_COUNT=118
  TAI=117, CYCLES=124999999

SLAVE   DE5_1-11.2
  Step 6 Global Time = VALID
  TIME_VALID=1, PPS_VALID=1
  SNAPSHOT_VALID=1, SNAPSHOT_STABLE=1, SNAPSHOT_COUNT=5
  TAI=121, CYCLES=124999999
```

The TAI values were read through separate JTAG transactions, so their numerical
difference is not a same-cycle skew measurement. Both values are independently
valid Global-Time observations; same-PPS equality is covered by the existing
Step6A-2 milestone.

The Slave also showed the expected direct Step5 lock fields:

```text
HelperLock=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
```

The dashboard's legacy `Step5Result=UPSTREAM_NOT_READY` remains a separate
Step3 sideband classification issue; it does not invalidate the Global-Time
display gate or the direct Step5 lock fields.

## Raw evidence

```text
raw/build/build.log
raw/program/program.log
raw/observe/dashboard-gated.log
```

SHA-256:

```text
D170C89D09F15161764E3C58298D5BE38D89ABE2048E565F656A574781396285  raw/build/build.log
17BEE2B9343929D9234DFECE52DD6AD494AAEA0980D753101A8E368F82ED6CD7  raw/program/program.log
28A9BC457BFC966F0C5C5ED1E01D92CE9E00BEF8156B6D373C30C6939A71FDF9  raw/observe/dashboard-gated.log
```

## Conclusion

The dashboard can now reliably reach and show valid Global Time after a fresh
program without physical power cycling. The next small presentation change is
to print the two validity bits explicitly inside each board panel, while
preserving the current bounded-wait behavior.

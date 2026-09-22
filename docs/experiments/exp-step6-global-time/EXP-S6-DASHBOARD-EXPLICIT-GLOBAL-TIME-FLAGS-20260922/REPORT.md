# EXP-S6-DASHBOARD-EXPLICIT-GLOBAL-TIME-FLAGS-20260922

日期：2026-09-22（Asia/Taipei）

## Verdict

```text
DASHBOARD_EXPLICIT_VALIDITY_FIELDS = PASS
MASTER_STEP6                    = VALID
SLAVE_STEP6                     = VALID
MASTER_TIME_VALID               = 1
MASTER_PPS_VALID                = 1
SLAVE_TIME_VALID                = 1
SLAVE_PPS_VALID                 = 1
MASTER_TAI_CYCLES               = 77 / 124999999
SLAVE_TAI_CYCLES                = 81 / 124999999
BOUNDED_WAIT                    = PASS (valid before 120 seconds)
POWER_CYCLE                     = NO
```

本輪確認新版人類可讀面板會在每張板子的區塊內明確列出：

```text
Global-Time validity         TIME_VALID=1 PPS_VALID=1
TAI=<number> CYCLES=<number> VALID
```

兩板均在 bounded read-only wait 期限內取得 coherent、stable 的 Global-Time
snapshot。這輪沒有修改 SoftPLL、PI、gain、threshold、timeout、PPS、PHY、reset
或 RTL 控制行為。

## Source and image provenance

```text
branch                         = exp/step6-Global-Time-Testing
source commit                  = b5aa2d154f53043df049fb5c3ba445854933b7ce
change                         = dashboard-only explicit TIME_VALID/PPS_VALID output
Quartus                        = 17.0.0 Build 595
Slave SOF SHA256               = 3126c41b544eaa26d6a62bbf88bd287abd778a1c225981841d20cf160d149264
Master SOF SHA256              = 6f1e45e260b01ced3043bc855057a1ca84703731b7a21fce920699b043f9709d
```

Slave and Master compilation both completed with zero Quartus errors. The build
reported 299 warnings for Slave and 297 warnings for Master; timing closure is
retained as implementation metadata and is not a Global-Time or Step5 functional
gate.

## Required workflow completed

1. Laptop committed and pushed the dashboard-only presentation change.
2. Pain pulled the exact commit into a clean detached worktree.
3. Pain compiled both fitted designs and programmed Slave first, then Master.
4. A single read-only dashboard session was run without physical power cycling.
5. Raw build, programming, and observation evidence was copied back to Laptop.

Programming reported one configured device for each board and zero programmer
errors. No physical power-cycle or reset was used.

## Observation command

```text
ONCE=1 CLEAR_SCREEN=0 OBS_GAP_MS=2000 INTERVAL_SECONDS=10
WAIT_FOR_GLOBAL_TIME_SECONDS=120 WAIT_FOR_GLOBAL_TIME_POLL_SECONDS=5
./scripts/monitor/step1_6_dashboard.sh
```

The dashboard first reported both boards waiting for valid snapshots at elapsed
10, 24, 37, and 51 seconds. It then completed at
`2026-09-22T14:46:41+08:00`, before the 120-second deadline.

## Final dashboard evidence

```text
MASTER  DE5_1-11.1
  Step 6 Global Time          VALID
  Global-Time reason          PPS snapshot valid and stable
  Global-Time validity        TIME_VALID=1 PPS_VALID=1
  Snapshot                    snapshot=1 stable=1 count=78
  TAI=77                     CYCLES=124999999    VALID

SLAVE   DE5_1-11.2
  Step 6 Global Time          VALID
  Global-Time reason          PPS snapshot valid and stable
  Global-Time validity        TIME_VALID=1 PPS_VALID=1
  Snapshot                    snapshot=1 stable=1 count=11
  TAI=81                     CYCLES=124999999    VALID
```

The TAI values were obtained by separate JTAG reads, so their numerical
difference is not a same-cycle skew measurement. Both values are independently
valid Global-Time observations; same-PPS equality is covered by the existing
Step6A-2 same-PPS milestone.

The same capture also showed the direct Step5 lock fields on the Slave:

```text
Helper=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
```

This confirms that the phase-lock path was active in this programmed session.
The dashboard's legacy `Step5 result = UPSTREAM_NOT_READY` is a separate Step3
sideband classification and does not override the direct lock fields.

## Raw evidence

```text
raw/build/build.log
raw/program/program.log
raw/observe/dashboard-explicit-flags.log
```

SHA-256:

```text
70EF51A5B4B3EB693C7FCA7861F35E9D47522725751B30075337517028E0AF8E  raw/build/build.log
C9BC48ED4816613BB9C27BAFD5E9C48085991738E74BB0F910C7DC4886D594B7  raw/program/program.log
F49EA34C82A442F3887E18E19BAC78E7B9CE984B6037F4680C117B0A30E65D99  raw/observe/dashboard-explicit-flags.log
```

## Conclusion

`DASHBOARD_EXPLICIT_VALIDITY_FIELDS` is PASS. The panel now visibly exposes the
two validity bits and numeric TAI/CYCLE only after the coherent snapshot gate is
valid and stable. The same run also observed `MainPhase=1` and `PSTAT=1` on the
Slave, so the restored-link session reached the requested phase-lock state.

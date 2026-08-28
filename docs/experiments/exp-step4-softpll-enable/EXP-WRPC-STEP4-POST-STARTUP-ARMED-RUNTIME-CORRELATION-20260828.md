# EXP-WRPC-STEP4-POST-STARTUP-ARMED-RUNTIME-CORRELATION-20260828

## 結論

本輪依分支3建議，先以 startup provenance 與 5 ms stable window 完成 post-startup arm，再執行一次 Master-only `mode master\n`。兩片 DE5a 均在 post-startup baseline 成功 armed；Master 的單次指令之後捕捉到完整的 runtime-only timestamp chain，且 `T_SYSTEM_START=0`。依預先定義的停損規則，正式判定：

```text
RUNTIME_FALSE_RESTART_FROM_RUNTIME_BUSDONE = PROVEN
RUNTIME_CAUSAL_CHAIN = CASE_A
FUNCTIONAL_FIX_THIS_ROUND = NONE
NEXT_ACTION = STOP_AND_REPORT_TO_BRANCH3
```

這一輪證明的是：在 startup transaction 已被隔離並清除 runtime-only recorder 之後，Master 的 runtime transaction 仍會造成 `bus_done`、static controller transition、SI config drop、WR reset 與 CPU reset 的連續關聯，而同一筆 post-arm trace 中沒有新的 `system_start`。本輪沒有修改任何 runtime/static FSM 功能行為。

## Source-backed instrumentation

Source commit：`382d30cd23e5f0580b7348d2c7812fdce95617ec`。

本輪增量只做 non-functional observability：

- 在 `CLK_50_B2J` domain 保存 startup `system_start`、startup static-complete 與 post-startup arm timestamp。
- 只有在 `STATIC_STATE=0`、`STATIC_CONTROLLER_READY=1`、`SI_CONFIG_DONE=1`、`WR_CORE_RESET_N=1`、`CPU_RESET=0`、`BUS_STATE=0`、`RUNTIME_STATE=000` 連續穩定 5 ms 後才設定 `POST_ARMED=1`。
- arm transition 只清除 runtime-only timestamps 與 static before/after；startup provenance 與 post-arm timestamp 不清除。
- 新增 correlation probes 34–35；既有功能控制、reset、runtime FSM、static FSM 均未改動。
- reader 唯一寫入是 Master 在 armed 後一次性的 VUART `mode master\n`；Slave 沒有 stimulus。

## Build and programming provenance

- Git branch：`exp/step4-softpll-enable`
- Source/reader commit：`382d30c`
- Raw record commit：`52df3c5`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.419 ns`
- Slave full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.389 ns`
- Master MIF SHA-256：`ad86b926f85445c772f21c05a231c0a1721fa45feaa46ab1db3c8019b46fa6c6`
- Slave MIF SHA-256：`6abf1d7436f85d9fef5abad9ee9a2c82f06bd35c448d2d49cfe18f448cab8d48`
- Master SOF SHA-256：`8657d918a4ec996b1dfdaa988ff99de21148704b3f49200d594895147a4a0136`
- Slave SOF SHA-256：`62d71f6849e09b7a6b41d9fab6d9557bf9433536b8aec46e60ba4e3db272b30e`
- Master program：cable `DE5 [1-11.1]`，checksum `0x30AF826D`，JTAG ID `0x02E660DD`，configuration succeeded。
- Slave program：cable `DE5 [1-11.2]`，checksum `0x30B26152`，JTAG ID `0x02E660DD`，configuration succeeded。

## Capture protocol

- Reader：`scripts/jtag/read_post_startup_armed_runtime_correlation.tcl`
- Samples：200 per board；interval 200 ms；每板約 43.4 s。
- Reader 在 sample 20 觀察到 Master `POST_ARMED=1` 後才注入一次 `mode master\n`，共 12 bytes。
- Slave 完全沒有 stimulus；reader 明確輸出 `POST_RUNTIME_INJECT_SKIPPED ... reason=not_master_cable`。
- 觀測涵蓋 DCO probe 8、reset probe 27、correlation probes 28–35、既有 status probes，以及 persistent command/mode/lock/SPLL stage。
- 沒有 CPU hold/release、reset write、WR/PHY/SoftPLL control write。

## Post-startup baseline

Master 與 Slave 在刺激前的 sample 20 都一致符合 arm 條件：

```text
POST_STARTUP_ARMED=1
STATIC_CURRENT=00
SI_CONFIG_DONE=1
WR_CORE_RESET_N=1
CPU_RESET=0
RUNTIME_STATE_LIVE=00
BUS_STATE_LIVE=0
LIVE_RUNTIME_START=0
LIVE_BUS_DONE=0
LIVE_STATIC_DONE_PULSE=0
T_DAC_LOAD=00000000
T_RUNTIME_START=00000000
T_BUS_DONE=00000000
T_STATIC_DONE_PULSE=00000000
T_STATIC_STATE_LEAVE_ZERO=00000000
T_STATIC_READY_DROP=00000000
T_SI_CONFIG_DROP=00000000
T_WR_CORE_RESET_ASSERT=00000000
T_CPU_RESET_ASSERT=00000000
T_SYSTEM_START=00000000
```

兩板 startup provenance 也被保留：

```text
STARTUP_SYSTEM_START_SEEN    = 001FFFFF
STARTUP_STATIC_COMPLETE_SEEN = 003B6C10
T_POST_STARTUP_ARM           = 003F3CA0
STARTUP_READY_FINAL          = 1
POST_ARMED                   = 1
```

## Master post-arm result

Master 在 sample 20 完成 baseline 後，reader 只注入一次 `mode master\n`。sample 21 起 correlation probes 28–32 的 raw values 固定為：

```text
CORR0_RAW=B4A24853B4A22D93
CORR1_RAW=B4A28342B4A28141
CORR2_RAW=B4A28344B4A28343
CORR3_RAW=B4A28344B4A28344
CORR4_RAW=00000000B4A28344
```

以每個 probe 的 low/high 32-bit halves 解碼後：

```text
T_DAC_LOAD              = B4A22D93
T_RUNTIME_START         = B4A24853
T_BUS_DONE              = B4A28141
T_STATIC_DONE_PULSE     = B4A28342
T_STATIC_STATE_LEAVE_ZERO = B4A28343
T_STATIC_READY_DROP     = B4A28344
T_SI_CONFIG_DROP        = B4A28344
T_WR_CORE_RESET_ASSERT  = B4A28344
T_CPU_RESET_ASSERT      = B4A28344
T_SYSTEM_START          = 00000000
```

因此時間順序是：

```text
T_DAC_LOAD < T_RUNTIME_START < T_BUS_DONE < T_STATIC_DONE_PULSE
            < T_STATIC_STATE_LEAVE_ZERO < T_STATIC_READY_DROP
            <= T_SI_CONFIG_DROP <= T_WR_CORE_RESET_ASSERT
            <= T_CPU_RESET_ASSERT
```

`CORR5_RAW` 在 post-arm 後顯示 `STATIC_BEFORE=00`、`STATIC_AFTER=01`，capture 結束時 `STATIC_CURRENT=00`；也就是 first-event latch 捕捉到 static state 的 `0 -> 1` transition，而 live state 後來已回到 0。Master reset/persistent evidence 也同步前進：sample 20 的 CPU/WR/SI drop counts 為 `02/02/02`、boot generation 為 `02`；sample 21 之後為 `03/03/03`、boot generation 為 `03`，並保留 `PERSIST_MODE_MASTER_STAGE=4`、`PERSIST_LOCK_WAIT_SUBSTAGE=1`、`PERSIST_CMD_STAGE=9`。

reader 的 Quartus Tcl 64-bit signed conversion 對 high-bit raw timestamp 會將欄位顯示為 `INVALID`；判定使用的是 raw `CORR0_RAW`–`CORR4_RAW` 的 32-bit halves，完整原始輸出已保存，未以 signed 顯示欄位替代證據。

## Slave control result

Slave 沒有收到任何 VUART stimulus。從 sample 20 到 sample 200，以下 post-arm runtime-only timestamps 保持全 0：

```text
T_DAC_LOAD=00000000
T_RUNTIME_START=00000000
T_BUS_DONE=00000000
T_STATIC_DONE_PULSE=00000000
T_STATIC_STATE_LEAVE_ZERO=00000000
T_STATIC_READY_DROP=00000000
T_SI_CONFIG_DROP=00000000
T_WR_CORE_RESET_ASSERT=00000000
T_CPU_RESET_ASSERT=00000000
T_SYSTEM_START=00000000
```

Slave 的 `POST_ARMED=1`、static/config/reset live baseline 持續正常，reset counts 維持 `02/02/02`，boot generation 維持 `02`，persistent mode/lock/command stages 維持 0。這提供了同板 firmware、無 stimulus 的 negative control。

## Decision

依分支3的 Case A 規則：

1. post-startup arm 成功，且 pre-command runtime-only recorder 全為 0。
2. Master-only 單次 `mode master\n` 後，出現完整 timestamp chain。
3. `T_SYSTEM_START=0`，所以這不是新的 startup `system_start` transaction。
4. Slave 無 stimulus 且全程沒有同樣 chain。
5. 因此 runtime false restart 已證明；本輪停止，不做同一輪 functional fix。

## Raw evidence

完整 raw capture、兩片 build info/log、programming/config record、source snapshots、source diff 與 reader source 保存在：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-POST-STARTUP-ARMED-RUNTIME-CORRELATION-20260828/`

Raw record commit：`52df3c5`。

# EXP-WRPC-STEP4-STATIC-FSM-IDLE-COMPLETION-GATE-FIX-20260828

## 結論

本輪只加入一個最小 functional gate：static SI5340 controller 在 idle `i2c_reg_state=0` 時，不再消費 shared `i2c_controller_config_done`。兩片 DE5a 均 fresh compile、fresh program，並完成 Master-only 單次 `mode master\n` protocol。

實驗結果顯示：修補後沒有再觀察到 static state `0 -> 1`、SI config drop、WR-core reset 或 CPU reset；但 Master 的 command evidence 只到 VUART newline stage 4，沒有進入 mode-master handler，因而也沒有觀察到 runtime DCO `DAC_LOAD/RUNTIME_START/BUS_DONE`。所以本輪可以確認 idle gate 沒有回歸造成 false restart/reset，但不能把「runtime bus_done 後仍維持 static idle」宣稱為完整 primary PASS，因為 runtime transaction 根本未到達。

正式分類：

```text
STATIC_IDLE_COMPLETION_GATE_REGRESSION = NOT_OBSERVED
STATIC_FSM_FALSE_RESTART_FIX = INCONCLUSIVE_RUNTIME_NOT_REACHED
CPU_RESET_CHAIN_FROM_RUNTIME_BUSDONE = NOT_OBSERVED
NEXT_BOUNDARY = PERSISTENT_COMMAND_STAGE_4_TO_MODE_DISPATCH
FUNCTIONAL_FIX_THIS_ROUND = ONE_LINE_ONLY
```

本輪不再加入第二個 functional fix，保留目前 evidence 供分支3決定下一步。

## Functional change

Baseline commit：`7230cd7`。

Source commit：`209145d276c9ce67fbfc717553538be7ff1bed40`。

唯一 source diff 位於 `quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v`：

```verilog
else if (i2c_controller_config_done && (i2c_reg_state > 0))
    i2c_reg_state <= i2c_reg_state+1;
```

這一行限制 static FSM 只有在 static transaction active 時才消費 completion。既有 post-startup probes 28–35 與所有 DCO、reset、persistent observability 均保留；沒有修改 runtime DCO FSM、bus_done semantics、initial_config/system_start、SoftPLL、DMTD、IRQ、reset tree、VUART parser 或 PTP/PHY。

## Build and programming provenance

- Git branch：`exp/step4-softpll-enable`
- Raw record commit：`b929fbd`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.177 ns`
- Slave full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.272 ns`
- Master MIF SHA-256：`8edafca73ce8ee0f555e7f0cac57eb2e16dbf47f7e238da3e412704358477b02`
- Slave MIF SHA-256：`c7ffa58573104562f95ea3acd02d2f7b1e6f5c6b6e01ac3eac68e1e39d309591`
- Master SOF SHA-256：`27af006e292b384732edbf8d41103413fc0f7b850191d49725468222a925ff24`
- Slave SOF SHA-256：`0b9a6f051124ed941b13da80ca518235ca78b394bb70a6d30979cb030ad011e7`
- Master program：cable `DE5 [1-11.1]`，checksum `0x30B00EC4`，JTAG ID `0x02E660DD`，configuration succeeded。
- Slave program：cable `DE5 [1-11.2]`，checksum `0x30B7AD8B`，JTAG ID `0x02E660DD`，configuration succeeded。

## Capture protocol

- Reader：`scripts/jtag/read_post_startup_armed_runtime_correlation.tcl`
- Samples：200 per board；interval 200 ms；每板約 43.4 s。
- 兩片均先達到 `POST_ARMED=1`，再由 reader 在 Master sample 20 注入一次 `mode master\n`，共 12 bytes。
- Slave 沒有 stimulus；reader 輸出 `POST_RUNTIME_INJECT_SKIPPED ... reason=not_master_cable`。
- Master 的 12 個 VUART Wishbone write 都完成 handshake；persistent command stage 證實已收到 newline，但未再進入 shell dispatch stage。
- 沒有 CPU hold/release、reset write、reprogram 或第二次 mode command。

## Post-startup baseline

Master 與 Slave sample 20 的 baseline 均符合：

```text
POST_ARMED=1
STATIC_CURRENT=00
SI_CONFIG_DONE=1
WR_CORE_RESET_N=1
CPU_RESET=0
RUNTIME_STATE_LIVE=00
BUS_STATE_LIVE=0
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

兩板 startup provenance 保持一致：

```text
STARTUP_SYSTEM_START_SEEN    = 001FFFFF
STARTUP_STATIC_COMPLETE_SEEN = 003B6C10
T_POST_STARTUP_ARM           = 003F3CA0
STARTUP_READY_FINAL          = 1
POST_ARMED                   = 1
```

## Master result

Master sample 20 baseline 之後執行唯一一次 `mode master\n`。從 sample 21 到 sample 200，correlation probes 28–32 均保持：

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

live/static/reset 狀態也保持正常：

```text
STATIC_CURRENT=00
SI_CONFIG_DONE=1
WR_CORE_RESET_N=1
CPU_RESET=0
LIVE_RUNTIME_START=0
LIVE_BUS_DONE=0
LIVE_STATIC_DONE_PULSE=0
```

Master persistent evidence 在 sample 21 之後為：

```text
PERSIST_CMD_STAGE=00000004
PERSIST_MODE_MASTER_STAGE=00000000
PERSIST_LOCK_WAIT_SUBSTAGE=00000000
PERSIST_SPLL_CHECK_LOCK_STAGE=00000000
BOOT_GENERATION=00000001
CPU_RESET_COUNT=01
WR_CORE_RESET_COUNT=01
SI_CONFIG_DROP_COUNT=01
```

`PERSIST_CMD_STAGE=4` 是收到 newline 後的 command RX stage；沒有進入 shell line-ready、mode lookup、mode handler 或 mode-master stage。因此這次 run 沒有產生可用來驗證「runtime bus_done 仍然存在」的 runtime event。

## Slave negative control

Slave 全程沒有 stimulus。sample 20 到 sample 200 的 correlation probes 28–32、static/live/reset 狀態均維持 baseline；persistent command/mode/lock/SPLL stages 維持 0，boot generation 維持 1，reset counts 維持 `01/01/01`。

## Decision

依分支3指定的判讀邊界：

1. 本輪確實只改 idle completion gate 一行。
2. 修補後沒有再看到 static state `0 -> 1` 或其後的 SI config/WR/CPU reset chain。
3. 但 Master 沒有到達 runtime DCO，因此無法檢驗預期的 `T_DAC_LOAD != 0`、`T_RUNTIME_START != 0`、`T_BUS_DONE != 0` preservation criterion。
4. 不把「沒有事件」誤寫成 runtime path 已通，也不在同輪加入第二個修補。
5. 下一個 boundary 是 `PERSIST_CMD_STAGE=4` 到 mode dispatch 的進展；這由分支3決定後續單一步驟。

## Raw evidence

完整 post-fix raw capture、build info/log、programming/config record、fixed source snapshots、one-line diff 與 reader source 保存在：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-STATIC-FSM-IDLE-COMPLETION-GATE-FIX-20260828/`

Raw record commit：`b929fbd`。

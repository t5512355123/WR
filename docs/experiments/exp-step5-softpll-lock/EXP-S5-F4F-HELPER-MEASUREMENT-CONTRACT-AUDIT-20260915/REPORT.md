# EXP-S5-F4F-HELPER-MEASUREMENT-CONTRACT-AUDIT-20260915

## Attempt 1 report — observer wiring failure

日期：2026-09-15（Asia/Taipei）  
Laptop/Pain source commit：`29535064d54d5046be9299e8f3375591de965df8`  
分支：`exp/step5-softpll-lock`

## Purpose

本輪依 `ai_advice/Step5/08_Astra.md` 執行 F4F：在單一 Tcl observer 中交替讀取
Helper 的 FULL 與 CORE epoch profile，保存每次 retry 的 raw、reason、host timing，
並以低頻 background 讀取 Main/position/L2 作為背景資料。這一輪只允許修改
observer/analyzer/tests，不修改 production C/RTL、PI、timeout 或控制參數。

## Laptop → Pain → program

- Laptop 已完成 offline tests、source audit，並 push `29535064`。
- Pain 已 fast-forward 到完全相同 commit。
- Master Quartus build：PASS，`timing_closed=NO`（既有 timing caveat）。
- Slave Quartus build：PASS，`timing_closed=NO`（既有 timing caveat）。
- Master program：PASS，Quartus checksum `0x30B89B19`，`Configuration succeeded`。
- Slave program：PASS，Quartus checksum `0x30B84088`，`Configuration succeeded`。
- Master SOF SHA-256：`9B50B519AA230444F179B81BE25614691E79956B352326FB23A2E114F357B918`。
- Slave SOF SHA-256：`4CB5B9C361EFE1B5B51AC367A5E85E68E806EEE39B9CFE5DACD42630ECF87400`。

## Observer result

執行條件：

```text
samples=300
slave profile cadence=500 ms
target=120000 ms
hard deadline=130000 ms
one Tcl process / one reader
```

結果：

```text
observer_rc=0
session_elapsed_ms=2577
cycles=6
FULL cycles=3, accepted=0
CORE cycles=3, accepted=0
helper attempts=48
background samples: Master=1, Slave=1
run_end_reason=STOP_TRANSPORT_FAILURE
stop_reason=TRANSPORT_FAILURE
```

所有 FULL/CORE profile attempts 的 raw epoch 與 payload 都是 `TIMEOUT`；但兩筆
background 都是 `valid=1 transport_error=0 parse_error=0`，Slave background 讀到
`status_raw=00000001`、`wr_state_raw=A041135C`，且 `reset_changed=0`。

離線 analyzer verdict：

```text
classification=TRANSPORT_LIMITED
diagnostic_pass=true
step5_complete=false
step5_pass=false
merge_approved=false
```

此 `diagnostic_pass` 僅表示「已定位到 observer 量測失敗類型」，不是 F4F source
contract 通過，也不是 Step5 通過。

## Root cause

F4F 的 `f4f_capture_profile` 直接呼叫 `wb_read`，卻漏掉既有流程必需的
`start_insystem_source_probe`、`set wb_toggle` 與 `wb_sync_toggle`。因此 profile
讀取發生在 inactive source-probe context；同一程式後續的 `f4f_emit_background`
有正確啟動 probe，故 background mailbox 讀取正常。這是 observer implementation
error，不能拿本輪 profile timeout 推論 Helper publisher、epoch seqlock 或 WR
控制器故障。

## Source-contract audit retained

`vendor/wrpc-sw/include/hw/wrc_diags_regs.h` 與
`vendor/wrpc-sw/dev/wdiags.c` 確認：

- epoch：`0x00100B00`
- Helper error：`0x00100B14`
- update count：`0x00100B18`
- Helper output：`0x00100B1C`
- FULL 其餘 payload：`0x00100B04..0x00100B24`
- writer 先發佈 odd epoch、寫入同一組十個 payload，再以 even epoch commit。

因此 CORE profile 的 source basis 仍成立，但本次沒有取得任何可用 CORE sample，
不能分類為 `COMPACT_HELPER_CORE_OBSERVABLE`。

## Next action

本失敗 attempt 的 raw、build/program logs、observer log、archive hash 與離線
replay 已保留。下一個 source-only 修正是讓 F4F profile capture 在同一 Tcl
process 內建立並關閉 active source-probe context，且保留每個 profile 的 retry
上限 8，不改 production control。修正後必須重新 Laptop push、Pain build/program，
再執行新的 F4F capture。

## Raw / replay integrity

- observer raw：`raw/attempt-29535064-jtag-runtime/tmp/observer.log`
- observer raw SHA-256：`7D84A82023183C677CFB72A8F99FC9C8413052D9C31AC47F99B7FBEC3BF603E8`
- bundled raw archive：`raw/f4f-failed-observer.tgz`
- archive SHA-256：`1568F026C4B4882FA25A4FD27392A9545A642533FF61B98EE751FC03EC783A17`
- replay：`analysis/replay-29535064-failed-observer/verdict.json`

本輪結論：`F4F_OBSERVER_IMPLEMENTATION_ERROR`。Step5 尚未完成，禁止 merge。

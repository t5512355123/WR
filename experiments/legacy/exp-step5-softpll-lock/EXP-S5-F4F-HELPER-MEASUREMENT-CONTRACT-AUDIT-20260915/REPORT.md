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

Attempt 1 結論：`F4F_OBSERVER_IMPLEMENTATION_ERROR`。Step5 尚未完成，禁止 merge。

## Attempt 2 report — corrected active-probe capture

修正 commit：`e550e57d11493b18ff30728e3a295b63dc87cfa4`
修正內容：只補上 F4F profile capture 的 active source-probe lifecycle；不修改
production C/RTL、PI、timeout、控制參數或 mailbox protocol。Pain 重新 pull、build、
program 後才進行本次 capture。

執行條件：

```text
samples=300
profile order=FULL,CORE, FULL,CORE, ...
profile cadence=500 ms
target=120000 ms
hard deadline=130000 ms
one Tcl process / one reader
```

Deploy：

- Master build：PASS，`timing_closed=NO`。
- Slave build：PASS，`timing_closed=NO`。
- Master program：PASS，checksum `0x30B89B19`，`Configuration succeeded`。
- Slave program：PASS，checksum `0x30B84088`，`Configuration succeeded`。
- Master SOF SHA-256：`75B0610CDB050F6D9BB52B2E2EC8F95A39B1F8F59FFCA8938BCB384F4B3B17B4`。
- Slave SOF SHA-256：`DE37675426A36399002BEEA5E20BA5445B19647874B5D623E71AEB092B8DFE53`。

Observer：

```text
observer_rc=0
session_elapsed_ms=120380
run_end_reason=TARGET_REACHED
stop_reason=NONE
cycles=103
profile_summary_rows=103
helper_attempt_lines=478
background_samples=Master 33 / Slave 26
reset_changed=0
terminal=0
```

### Profile evidence

| Profile | Attempts | Accepted | Epoch changed | Transport/parse error | Fresh | Stale | Ambiguous |
|---|---:|---:|---:|---:|---:|---:|---:|
| FULL | 416 | 0 | 416 | 0 / 0 | NOT_APPLICABLE | NOT_APPLICABLE | NOT_APPLICABLE |
| CORE | 62 | 51 | 11 | 0 / 0 | 50 | 0 | 0 |

CORE 的第一筆 accepted host time 是 `1789464167341`，最後一筆是
`1789464284250`，跨度 `116909 ms`；accepted update count 持續前進。FULL
被拒絕的主要原因是 `EPOCH_CHANGED`（416/416）；其中 81 次同時觀察到
`ARITHMETIC_MISMATCH`，但因 epoch 已變動，不能把這些混合視窗當成 source
arithmetic failure。沒有 transport 或 parse error，也沒有 odd/sentinel 或
output range error。

CORE 僅量測 epoch、Helper error、update count、Helper output；FULL-only 欄位在
CORE raw 中均為 `NOT_MEASURED`。離線檢查結果：

```text
payload_isolation_pass=true
alternating_profiles_pass=true
max_attempts_per_cycle=8
attempt_shape_errors=0
```

低頻 background 只作背景，不參與 profile acceptance：Slave 26 筆均為完整有效
背景；Master 的 33 筆有 position probe 的部分 timeout，但 reset/generation 未變，
且沒有影響 Core profile 的 coherent/fresh 判定。

## Final F4F verdict

```text
F4F_RESULT=COMPACT_HELPER_CORE_OBSERVABLE
F4F_DIAGNOSTIC_PASS=true
STEP5_COMPLETE=false
STEP5_PASS=false
MERGE_APPROVED=false
```

這個 verdict 的精確意義是：在同一個 active-probe、同一個 read-only observer
中，CORE 短讀取可以長時間取得一致且 fresh 的 Helper producer data，而 11-word
FULL read span 在 live publisher 下全部遇到 epoch change。這支持「FULL 讀取跨度／
publisher competition 是目前觀測契約的邊界」；它不證明 FULL contract 已通過，
也不證明 PI、arbiter 或 production controller 是根因。

因此本輪不調參、不修改 production、不宣告 Step5，也不 merge 到 main。下一輪
應由 Astra 依這份 raw 與 F4F verdict 決定是否要處理 FULL reader contract 或採用
更精準的 passive source-side publication evidence。

## Final raw / replay integrity

- Attempt 2 observer raw：`raw/attempt-e550e57d-f4f-jtag-runtime/tmp/observer.log`
- Attempt 2 observer raw SHA-256：`43282D7B79A2BC847F9F41D3CF45CDF438A1F0D87A587757BBC1F44B53B1637D`
- Attempt 2 bundled raw archive：`raw/f4f-successful-capture.tgz`
- Attempt 2 archive SHA-256：`D12C54FCA34FEE0A316BEE579CB446961C834ABCBF823E74ED42038AB166D52F`
- Attempt 2 replay verdict：`analysis/replay-e550e57d-f4f-jtag-runtime/verdict.json`
- Attempt 2 attempts CSV：`analysis/replay-e550e57d-f4f-jtag-runtime/attempts.csv`

# EXP-WRPC-STEP4-LOW-QUAL-ACTIVITY-20260825-6278548

## 1. 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-LOW-QUAL-ACTIVITY-20260825-6278548`
- 日期：2026-08-25（Asia/Taipei）
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`627854821bf3e1c4af0a016f45bdb28d2b10558e`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- 測試主機：`pain`
- JTAG boards：`DE5 [1-11.1]`（Master）、`DE5 [1-11.2]`（Slave）

本次實驗的目的，是在 Step 2/Step 3 regression barrier 通過後，使用唯讀 JTAG diagnostics 判斷現有 `LOW qualification abort` counter 是否持續活動，並觀察 SoftPLL 從 DMTD sampled/qualification 到 event、accept、tag、TRR、IRQ、helper 的第一個沒有活動節點。

## 2. 唯一變更

相較於前一個實驗，本次只修改：

```text
scripts/jtag/read_step4_startup_focused.tcl
```

commit `6278548` 將 low-qualification counter 的輸出改成明確分類：

- `ACTIVITY_PRESENT`
- `NO_ACTIVITY_IN_WINDOW`
- `MEASUREMENT_INVALID_RETEST`

並在 Tcl 進行數值比較前先排除 `TIMEOUT`、`DECREASED` 等特殊狀態。

本次沒有修改 FPGA RTL、firmware、MIF、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## 3. Fresh build provenance

兩片 SOF 都由 exact HEAD `627854821bf3e1c4af0a016f45bdb28d2b10558e` 在 pain 上重新 build 產生；沒有使用 historical SOF 完成這次驗證。

| 項目 | Master | Slave |
|---|---|---|
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| MIF SHA256 | `e1c43c9157eb42e443df87e62fcbf35461a1baa41b66412a9a3081ec8cf652ad` | `93e932236932ef5d67e216c8ea2459c55bb87df9b77f62c59d944ec5d38b0229` |
| SOF SHA256 | `5af95a0fa79640ccfd059a8bc7691b9f3bdb1325663a76a853f3cb9e1f78d5f9` | `5558ae0528910ba42ffd45a45270c945a4562d0fd85b9ae9c8221cada8e550ed` |
| Programmer checksum | `0x30B08F99` | `0x30B3A7D1` |

Quartus fitter 結果：兩片皆 `Full Compilation was successful`。本次 build 的 `TIMING_CLOSED=NO`；Master worst setup slack `-0.379 ns`，Slave `-0.206 ns`。這是 build timing 狀態，不能直接當作 runtime failure 證據。

## 4. 燒錄結果

Master 與 Slave 均由 fresh SOF 完成 programming：

- Master：`Configuration succeeded -- 1 device(s) configured`，`0 errors, 0 warnings`
- Slave：`Configuration succeeded -- 1 device(s) configured`，`0 errors, 0 warnings`

原始 programmer output：

- `raw/program-master.log`
- `raw/program-slave.log`

## 5. Step 2 / Step 3 regression barrier

使用：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

本次每片採 20 個 accepted samples，mailbox invalid sample 數為 0。

### Master

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- MiniNIC counters 有活動
- PTP RX/TX 有活動；`PTP_TX_DELTA=63`
- `RXERR=0`
- `STEP2_REGRESSION=PASS`

### Slave

- MAC：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- PTP 從 startup 的 `8` 進入穩態 `9`
- Foreign Master：`foreign=1`、`best_index=0`
- Parent metadata：`parent_is_wr=1`、`parent_calibrated=1`
- WR RX message：`0x1001 LOCK`
- WR TX message：`0x1000 SLAVE_PRESENT`
- `LOCK_ENABLE=4`
- `RXERR=0`
- PTP RX/TX 有活動；`PTP_TX_DELTA=29`
- `STEP2_REGRESSION=PASS`
- `STEP3_REGRESSION=PASS`

Slave 的 `STATE_EVIDENCE=READ_INCONSISTENT`，20 個 sample 中有 state transitional/idle variation；但 focused gate 的主要 Step 3 evidence（Foreign Master、parent flags、LOCK、SLAVE_PRESENT、LOCK_ENABLE）成立，因此本次不把單一 state variation 誤判成 Step 3 hardware failure。

原始 barrier output：`raw/handshake.log`。

## 6. LOW qualification counter 實驗

使用：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 20 500 low_abort
```

結果：

```text
Master: ref_delta=0 ref_activity=NO_ACTIVITY_IN_WINDOW
        fb_delta=0  fb_activity=NO_ACTIVITY_IN_WINDOW
        ref_valid=20 fb_valid=20 result=VALID

Slave : ref_delta=0 ref_activity=NO_ACTIVITY_IN_WINDOW
        fb_delta=0  fb_activity=NO_ACTIVITY_IN_WINDOW
        ref_valid=20 fb_valid=20 result=VALID
```

這代表目前讀到的既有 low-abort counter 在 20 個 sample、每 500 ms 的觀察窗口內沒有增加，且這些 read 都是有效讀值。它不代表整個 qualification path 沒有 abort，因為目前這條 readback 只涵蓋既有 low-abort mapping；不能由 `delta=0` 推論 high-abort count 也是 0。

原始 output：`raw/low-abort.log`。

## 7. 完整 Step 4 focused observation

使用：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 20 500 all
```

### 7.1 已觀察到的活動

- Master/Slave 的 native DMTD frequency read 都是有效值，約為 125 MHz。
- `DMTD_REF_SAMPLED` 有明顯增加。
- Slave `DMTD_FB_SAMPLED` 有明顯增加。
- Master/Slave 的 D0 stable-hit、D0 transition/sample counters 有活動。
- Step 2/3 的 PTP、MiniNIC、WR handshake activity 仍存在。

### 7.2 尚未觀察到的下游活動

在 20 個 sample、每 500 ms 的窗口內：

- `DMTD_REF_EVENTS` delta = 0
- `DMTD_FB_EVENTS` delta = 0
- `DMTD_REF_ACCEPT` delta = 0
- `DMTD_FB_ACCEPT` delta = 0
- `TAG_VALID_COUNT` delta = 0
- `TRR_WRITE_COUNT` delta = 0
- `IRQ` delta = 0
- `HELPER_UPDATE_COUNT` delta = 0
- `TRR_POP`、state transition、pending/grant 也沒有活動

兩片 `SPLL_DMTD_STATE` 都讀到 `state=GOT_EDGE`，且 sticky evidence 顯示 `high_abort_seen=1`、`got_edge_seen=1`。完整 focused script 將邊界分類為：

```text
QUALIFICATION_ABORT_AFTER_GOT_EDGE
GOT_EDGE_HIGH_ABORT(clk_sampled=0)
```

這是目前最接近第一個 blocker 的 source-backed boundary：

```text
DMTD sampled
  -> qualification / GOT_EDGE
  -> high qualification abort evidence
  -> 沒有產生 accept/event
  -> 沒有進入 tag/TRR/IRQ/helper
```

但 `SPLL_DMTD_STATE` 的 high-abort bit 是 sticky evidence，不是完整 high-abort counter；本次尚未量到 high-abort 的頻率、次數或觸發原因，因此不能把它寫成已證明的最終 root cause。

原始 output：`raw/step4-all.log`。

## 8. 回歸判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED     = YES
STEP4_RESULT      = NOT_ACHIEVED
```

判定解讀：

- Step 1：fresh SOF 燒錄後 PHY/link evidence 正常。
- Step 2：20 個有效 samples 證明 MAC、role、PTP/MiniNIC activity 與 RXERR 條件成立。
- Step 3：20 個有效 samples 證明 Foreign Master、parent metadata、LOCK、SLAVE_PRESENT、LOCK_ENABLE 條件成立；state variation 標示為 read inconsistency/transitional evidence，不單獨判 fail。
- Step 4：SoftPLL startup 的下游 event chain 尚未通過，因此不能宣稱 Step 4 PASS。

目前分類：

```text
HARDWARE/FIRMWARE_FAILURE = NOT_PROVEN
JTAG_MEASUREMENT_INVALID   = NOT_PROVEN_FOR_THESE_READS
STEP4_BLOCKER               = GOT_EDGE/high-qualification boundary remains active
```

低資格 counter 的讀值本身有效，但其觀測範圍不足以排除 high qualification abort。這次結果比較支持「DMTD sampled 有活動、但沒有跨過 GOT_EDGE 後的 qualification/accept 邊界」，不支持「JTAG mailbox 讀值失效」或「Step 2/3 硬體已壞掉」。

## 9. 下一步

下一個實驗仍應維持 read-only、單一變因：先做 source-backed 的 high qualification abort observability audit，確認既有 `dbg_high_qual_abort_count` 是否能在不破壞任何已使用 register read/write mapping 的前提下被完整觀測，並與 `DMTD_HIGH_QUAL_MAX_STAB`、`SPLL_DMTD_STATE`、`GOT_EDGE` 與 `accept/event` counters 做同一窗口的 correlation。

在這項 evidence 完成以前：

- 不修改 high qualification threshold。
- 不修改 SoftPLL FSM、PI gain、lock threshold、DDMTD polarity、DCO 或 SI5340。
- 不把 `GOT_EDGE_HIGH_ABORT` sticky bit 直接當成最終根因。
- 保持 Step 2/3 regression barrier 通過後，才允許任何後續 Step 4 investigation。

## 10. 原始證據與 SHA256

所有檔案位於本實驗資料夾的 `raw/`：

| 檔案 | SHA256 |
|---|---|
| `build_info_jtag_master.txt` | `a8ca1d8e9c6abe75014b4746ace46c6c9340897890c916cd87103600d697ac36` |
| `build_info_jtag_slave.txt` | `c3af9059a855d8fb8a12d384d4083308d2bbd85b5a7ac85aa984579dcbe076ee` |
| `program-master.log` | `d1e6759dbd869d386f4c048983999a2234a10616759eeeb8eab7ec951bf68a8aa` |
| `program-slave.log` | `62616f94119cc04d013e17ba43e26219ee362ad35c0e494c12234aec3060e43` |
| `handshake.log` | `ba97d6b9ee9bcf0b29f60fba902e303252a75b6c4c05b87be0a0b8ba3ceea07fc` |
| `low-abort.log` | `82aea34c6c125967cf7d214981622fc3242dd629a90e1718f54bd47270fb8d27` |
| `step4-all.log` | `41c2bff529f3c6c1e2749906fa136064ac4596057287fc49912b079961850b6b` |
| `quartus_jtag_master_compile.log` | `52715c2d5aec4543cbf2960313f043039445d3ee069c8499b41427780f9fc9db` |
| `quartus_jtag_slave_compile.log` | `3bd3f318528dc84763e8cfb72c9c675c7a914d9ffd11e3e84486f538b10faeb1` |

## 11. 結論

本次 exact HEAD `627854821bf3e1c4af0a016f45bdb28d2b10558e` 已完成 fresh build、雙板 fresh SOF programming，以及 Step 2/3 repeated read-only regression。Step 2 與 Step 3 可以通過 regression barrier，因此 `STEP4_ALLOWED=YES`。

Step 4 尚未通過。現有證據把問題定位在 `GOT_EDGE` 之後、`accept/event` 之前的 high qualification boundary；目前仍不足以區分真正的硬體/韌體功能問題、輸入 qualification 條件問題，或 observability 尚未覆蓋完整 high-abort count。下一步必須先補足唯讀證據，再決定是否需要任何功能實驗。

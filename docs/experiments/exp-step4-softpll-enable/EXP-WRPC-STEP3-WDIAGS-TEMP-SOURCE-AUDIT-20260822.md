# EXP-WRPC-STEP3-WDIAGS-TEMP-SOURCE-AUDIT-20260822

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP3-WDIAGS-TEMP-SOURCE-AUDIT-20260822`
- 日期：2026-08-22
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`fef14d06df52df3fb5000fc91f93ae5938ea87b6`
- 實驗類型：source audit / read-only interpretation
- Quartus compile：未執行
- FPGA program：未執行
- Merge main：未執行
- Functional variable：本輪沒有修改

## 目的

釐清 Step 3 回歸測試中同時出現的兩類證據：

1. 已看到 `LOCK`、`SLAVE_PRESENT`、`LOCK_ENABLE` 與 parent metadata，支持 WR handshake 已經發生。
2. `WDIAGS_TEMP` 解碼出的目前 WR state 長時間顯示 `WRS_IDLE`，看起來與歷史 handshake 證據衝突。

本輪只閱讀目前 HEAD 的 source，確認這些欄位的真正寫入者、更新時機與失敗復原行為；不以單一 mailbox snapshot 推論硬體故障，也不修改 WR signaling 或 SoftPLL 行為。

## 目前 read-only 回歸基準

前一輪已保存的 focused / long observation 顯示：

| 項目 | Master | Slave |
|---|---|---|
| Endpoint MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` |
| `WDIAGS_MODE` | `2` | `3` |
| `WDIAGS_PTP` | `6` | `9` |
| PTP / MiniNIC counters | 持續增加 | 持續增加 |
| `WDIAGS_RXERR` | `0` | `0` |
| Foreign Master | 不適用 | `0x03000001` |
| RX WR message | - | `0x1001` (`LOCK`) |
| TX WR message | - | `0x1000` (`SLAVE_PRESENT`) |
| `LOCK_ENABLE` | - | `4` |
| signaling samples | - | good `28/30`、bad `2/30` |
| `WDIAGS_TEMP` state shadow | - | idle `30/30`、good `0/30` |

因此目前採用的 gate 結論是：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS  (handshake gate；state shadow 另列為 READ_INCONSISTENT)
STEP4_ALLOWED    = YES
```

`WRS_IDLE` 仍然是必須追蹤的目前狀態證據，但不能覆蓋較長時間的 handshake 證據，也不能單獨被寫成 Step 3 硬體失敗。

## Source audit 結果

### 1. `WDIAGS_TEMP` 的寫入者與語意

檔案：`vendor/wrpc-sw/lib/task-diags.c`

- `wrc_wr_diags()` 從第 26 行開始執行週期性診斷工作。
- `WRC_DIAG_REFRESH_PERIOD` 在第 24 行定義為 `1 * TICS_PER_SECOND`，因此不是每個 state-machine cycle 都更新。
- 在第 127～140 行，當沒有 DE5a temperature sensor 時，程式組合 `wr_state_debug`，再呼叫 `wdiags_write_wr_state_debug()`。
- 組合內容包括：
  - bit 0：`wrp->wrModeOn`
  - bit 1：`wrp->parentWrModeOn`
  - bit 2：`wrp->calibrated`
  - bit 3：`wrp->parentIsWRnode`
  - bit 4：`wrp->parentCalibrated`
  - bit 5：`wrp->wrConfig`
  - bits 8～9：`wrp->parentWrConfig`
  - bits 11～14：`wrp->state`
  - bits 15～18：`wrp->next_state`
  - bits 19～20：`wrp->parentDetection`
  - bits 21～23：`wrp->wrMode`
  - bits 31～28：`0xA` tag

檔案：`vendor/wrpc-sw/dev/wdiags.c`

- 第 157～160 行的 `wdiags_write_temp()` 會寫入同一個 `WRC_DIAGS_WDIAG_TEMP` register。
- 第 162～166 行的 `wdiags_write_wr_state_debug()` 也寫入同一個 register。
- 第 164～166 行的 comment 明確說明：沒有 temperature sensor 的 DE5a build 使用這個欄位保存 WR state debug，並以 `0xA` tag 讓 stale 或 unsupported value 可被辨識。

結論：

```text
WDIAGS_TEMP_WRITER   = wrc_wr_diags() 的週期性診斷更新
WDIAGS_TEMP_SEMANTIC = wrp->state / wrp->next_state 加上 WR flags 的 shadow
UPDATE_POINT         = task-diags refresh；約每秒更新一次
```

`WDIAGS_TEMP` 不是 SoftPLL state、不是 DMTD event counter，也不是永遠代表「曾經到過的最高 WR state」。

### 2. 為什麼 handshake counter 有值但目前 state 可以是 `WRS_IDLE`

檔案：`vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c`

- `wr_s_lock()` 第 14 行開始處理 `WRS_S_LOCK`。
- 第 25～28 行持續呼叫 `WRH_OPER()->locking_poll(ppi)`；回傳 `WRH_SPLL_LOCKED` 才會把 `next_state` 設為 `WRS_LOCKED`。
- 第 32～37 行在 timeout 期間呼叫 `locking_disable()`；retry 次數耗盡後呼叫 `wr_handshake_fail()`。
- 第 46～47 行在需要重新啟動時呼叫 `locking_enable()`。

檔案：`vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c`

`wr_handshake_fail()` 第 29～43 行的實際行為為：

1. 增加 `wrpc_wr_handshake_fail_count`。
2. 保存失敗當時的 state 與 role。
3. 將 `wrp->next_state` 設為 `WRS_IDLE`。
4. 呼叫 `wr_reset_process(ppi, WR_ROLE_NONE)`。
5. 呼叫 `wr_servo_reset(ppi)`。
6. 呼叫 `pdstate_disable_extension(ppi)`。

檔案：`vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-state-machine.c`

state machine 會在 `wrp->state != wrp->next_state` 時提交下一狀態；因此 timeout/recovery 後，目前 state 回到 `WRS_IDLE` 是 source 定義的結果，不是單純的 JTAG 數值亂碼。

這解釋了下面看似矛盾、其實可同時成立的情況：

```text
歷史/窗口內：LOCK、SLAVE_PRESENT、LOCK_ENABLE、parent metadata 都有證據
目前 shadow：WRS_IDLE
```

目前最保守且有 source 支持的判斷是：

```text
WR_HANDSHAKE_FAIL_EFFECT = timeout 後進入 recovery，next_state=WRS_IDLE，並 reset/disable WR extension
LIVE_WRS_IDLE_EXPLAINED  = YES
```

這不表示 SoftPLL 已成功，也不表示 Step 4 已通過；它只說明 Step 3 的 handshake evidence 與後續 lock-stage recovery 可以在同一次執行中共存。

### 3. Step 3 相關 source 證據

檔案：`vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-present.c`

- `wr_present()` 在收到 `LOCK` 後安排進入 `WRS_S_LOCK`。
- 進入相應流程時會送出 `SLAVE_PRESENT`。

檔案：`vendor/wrpc-sw/lib/task-diags.c`

- 第 141～148 行將最後收到/送出的 WR signaling message、signaling counter、最後失敗 role/state 與 handshake fail counter 寫入 diagnostics registers。
- 這些 counter 是歷史累積證據，不等同於當下 state。

因此 `LOCK_ENABLE=4` 與 signaling counter 正值可以證明曾進入相關 handshake/lock 流程，但不能單獨證明當下仍停在 `WRS_S_LOCK` 或已經 SoftPLL lock。

## 實驗判定

### 已支持的結論

- Step 1 PHY / link：PASS。
- Step 2 Endpoint / MiniNIC / PTP：PASS；Master/Slave identity、PTP role、PTP activity 與 Foreign Master evidence 均有保存。
- Step 3 WR handshake：PASS；此處 PASS 僅代表 handshake gate 通過，不把 current `WRS_IDLE` shadow 忽略，而是另列為 state-evidence inconsistency。
- Step 4：允許進入，但尚未通過。

### 尚未支持的結論

- 不能宣稱 SoftPLL 已鎖定。
- 不能宣稱 `PSTAT.locked=1`。
- 不能宣稱 `time_valid=1`。
- 不能把 `WRS_IDLE` 直接宣稱成 PHY、PTP 或 firmware 硬體故障。

## 下一步

下一輪只做 Step 4 diagnostic-only DMTD 觀測，先找出第一個沒有 activity 的節點：

1. REF/FB `clk_sampled` transition。
2. REF/FB deglitch accept / `new_edge_p_dmtdclk`。
3. REF/FB post-CDC / `new_edge_p_sysclk`。
4. 若 post-CDC 有活動，再往 tag、TRR、IRQ、helper update 追蹤。

預定的觀測訊號只增加 read-only counters/status，不改變 DMTD polarity、divider、threshold、synchronizer、SoftPLL algorithm、PTP、WR signaling、role、DCO 或 SI5340 行為。若 fresh image 的 Step 1～Step 3 回歸失敗，必須先停止 Step 4 解讀。

本文件本身只記錄 source audit，沒有新的 compile、program 或硬體實驗；下一次真的燒錄後，必須另建包含 exact commit、MIF/SOF SHA256、Quartus 版本、programmer checksum 與 JTAG raw log 的硬體實驗紀錄。

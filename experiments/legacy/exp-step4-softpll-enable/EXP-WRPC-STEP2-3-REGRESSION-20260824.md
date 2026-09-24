# EXP-WRPC-STEP2-3-REGRESSION-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP2-3-REGRESSION-20260824`
- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- 本次診斷腳本 commit：`f4d47d777104d09dc5013d1a8cb28ea0ff56c150`
- 前一個 D0 mismatch 觀測 commit：`2ecd38d4e6d980907f227492ea09bf38835714d4`
- 實驗類型：Step 2 / Step 3 read-only regression barrier

## 想驗證什麼

在進入 Step 4 SoftPLL 研究前，重新確認目前兩張 DE5a 的 Step 1、Step 2、Step 3 證據是否可靠，並確認 mailbox invalid/stale read 或 Tcl state 統計錯誤不會被誤判成硬體失敗。

## 唯一修改

本輪唯一提交的功能性變更是 `scripts/jtag/read_step23_register_reliability.tcl` 的 read-only 統計修正：將 `WDIAGS_TEMP` 的 `state_idle`、`state_non_idle`、`state_transition` 改為區域計數後再保存到 series，避免重複取樣統計遺失而錯誤回報 `STEP3_INDEPENDENT=INVALID`。

沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 WRPC firmware functional behavior，也沒有寫入 Wishbone control register。

## 燒錄與建置界線

本次 regression gate **沒有 program FPGA**，因此不能把本次 branch commit 宣稱為板上 fresh SOF。JTAG 讀值來自本輪開始前已存在於兩片板上的 bitstream；本 session 沒有從 FPGA 讀回 SOF hash，故現行硬體 SOF provenance 在本紀錄中標示為 `UNKNOWN / unchanged from previous programming`。

建置 provenance 另外保存於 raw 目錄：在 read-only regression 前曾對 `2ecd38d4e6d980907f227492ea09bf38835714d4` 執行 Master/Slave firmware 與 Quartus clean compile；該 SOF 沒有燒錄到板上，不能用來代表本次 runtime hardware evidence。這些 build log 只作為未來 approved fresh-program experiment 的參考。

- Quartus：17.0.0 Build 595
- Master MIF SHA256：`b6f09e752738457e0f6321fc58754517733c289b1f161498ec4ee55574f6c04f`
- Slave MIF SHA256：`450f64e4e3ecf67379738350895d43e5ac7e8dfcc11645da9b1f036a01d9adf1`
- Master 未燒錄 SOF SHA256：`17057a4271a6f92db91b4dbb9a2c8ae59fc90a20e6890987df395bf738f2fc70`
- Slave 未燒錄 SOF SHA256：`390a3b2900d48a102deb1bfb1be0ba8e8ae45ab31808b1ea2edb7ac8e35d8ec9`
- Master/Slave compile：`Full Compilation was successful`
- Timing：兩份 build info 均為 `timing_closed=NO`
- Programmer：本輪未執行，無 programmer checksum

## Raw evidence

原始輸出位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP2-3-REGRESSION-20260824/`

- `step23_register_reliability_f4d47d7.log`：修正後 10 samples / 500 ms reliability script
- `t0_step23_parent.log`：既有 focused Step 2/parent 長時間讀取
- `t0_step3_handshake.log`：既有 focused Step 3 20 samples 讀取
- `f4d47d7_step3_handshake.log`：在 pain exact `f4d47d7` checkout 重新取得的 focused 20 samples
- `dashboard_current.log`：目前 dashboard 一次完整執行結果
- `f4d47d7_dashboard.log`：在 pain exact `f4d47d7` checkout 重新取得的 dashboard
- `step23_register_reliability.log`：修正前的 negative-control log，保留用來說明原本的 Tcl 統計誤判
- `build_jtag_master.log`、`build_jtag_slave.log`：未燒錄的 compile provenance，不能當作 runtime evidence
- `*_hashes.sha256`、`build_info_jtag_*.txt`：hash 與建置資訊

所有 Quartus STP 腳本均回報 `Evaluation of Tcl script ... was successful`、0 errors、0 warnings；raw log 的 return code 檔案均為 0。修正前 negative-control 仍保留，但不作本輪 PASS 判定。

## Step 1 / Step 2 / Step 3 結果

### Step 1：PHY / Link

focused 與 dashboard 均顯示兩片板 ready/link/RX/TX 正常、RX lock-to-data=1、encoding error=0，判定：

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

`read_wr_handshake_focused.tcl` 對兩片各取得 20/20 valid samples；在 pain exact `f4d47d7` checkout 的重跑結果仍為 20/20 valid、`invalid_samples=0`、`counter_decreased=0`。修正後 reliability script 再取得兩片各 10/10 valid samples，`invalid=0`、`decrease=0`。

- Master：MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`
- Slave：MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`
- Slave：`FOREIGN_META=03000001`，foreign count=1、best index=0
- PTP RX/TX 與 MiniNIC TX/RX 在 focused samples 中有活動
- RXERR 在所有重複 sample 為 0

判定：

```text
STEP2_REGRESSION = PASS
```

### Step 3：WR Parent / Signaling

Slave focused 20 samples 與修正後 reliability 10 samples 都保留以下證據：

- parent metadata：`parentIsWRnode=1`、`parentCalibrated=1`
- RX WR message：`0x1001 LOCK`
- TX WR message：`0x1000 SLAVE_PRESENT`
- `LOCK_ENABLE=4`
- `WR_FAILURE_DEBUG` 持續保留 `WRS_S_LOCK` evidence

exact `f4d47d7` focused log 的 Slave gate 為 `STEP3_REGRESSION=PASS`、`signal_good=19`、`signal_bad=1`、`state_idle=20`、`state_good=0`；這正是保留 `READ_INCONSISTENT` 而不直接宣稱硬體失敗的原因。reliability log 則明確輸出 `POST_STEP3_LOCK_STAGE=TIMEOUT` 後 `STEP3_INDEPENDENT=PASS`。

live current state 仍顯示 `WRS_IDLE`，因此 raw evidence 中保留 `STATE_EVIDENCE=READ_INCONSISTENT` / `POST_STEP3_LOCK_STAGE=TIMEOUT`。這與 handshake、lock-enable、failure shadow 的證據衝突，不能直接宣稱 Step 3 硬體失敗；修正後 reliability script 已將它分類為 post-Step3 timeout 並回報 PASS。

判定：

```text
STEP3_REGRESSION = PASS
```

## Invalid read 與 dashboard 判讀

本輪 repeated reliability samples 沒有出現 `TIMEOUT`、`INVALID` 或 `0xA5A5....` stale word 混入接受樣本。dashboard 能完整印出兩片 Step 1～Step 6，且 Tcl 沒有因單一欄位中止。

dashboard 的 Step 4 仍看到 DMTD/tag/TRR/IRQ/helper delta=0；這是目前 SoftPLL startup 的觀測結果，不是 Step 2/3 mailbox invalid read。Step 4 本輪只作旁證，沒有進行 functional experiment。

## Regression barrier 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_EVALUATED_IN_THIS_REGRESSION
HARDWARE/FIRMWARE_FAILURE = NOT_ESTABLISHED_FOR_STEP2_STEP3
JTAG/DASHBOARD_MEASUREMENT_FAILURE = PREVIOUS_STEP3_STATISTICS_BUG_FIXED
```

這代表可以進入下一個 Step 4 read-only source/runtime audit；不代表 SoftPLL 已 lock，也不代表 `time_valid=1`。

## Next Step

下一輪若要驗證本 branch 的 exact HEAD 對硬體影響，必須另開 approved experiment：先由 exact commit fresh build，再 clean compile、保存 hashes，明確 program 兩片，最後重新跑同一組 Step 2/3 gate。未完成 fresh program 前，不得把本次 read-only runtime 結果寫成 `f4d47d7` fresh SOF reproduction。

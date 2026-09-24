# EXP-WRPC-STEP4-RAW-EVENT-CHAIN-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-RAW-EVENT-CHAIN-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 本機文件 commit：`f0155ba8d541df8b559ed588c1453e1f0678493d`
- 觀測時所使用的 FPGA bitstream 來源 commit：`31f2b518ae45e7664f3307269a0d050fb5c1f630`
- 實驗類型：**唯讀 runtime event-chain audit**
- 實驗狀態：**NOT PASS；尚未足以判定 Step 4**

## 這次想驗證什麼

上一輪觀測顯示 Slave 已進入 `WRS_S_LOCK` 並執行 `locking_enable()`，但 helper 沒有 lock，且 sequence 觀察到 `SPLL_STATE=00030009`。本輪要沿著同一條資料路徑確認第一個沒有活動的節點：

```text
reference / DDMTD tag
    -> TAG_VALID / TRR write
    -> SoftPLL IRQ
    -> helper update
    -> helper correction / DAC request
```

這一輪不修改 RTL、firmware、PHY、PTP、WR signaling、SoftPLL 演算法或 DCO 控制，也沒有讀取會消費 tag FIFO 的 `TRR_R0`。

## 相較 baseline 唯一修改

沒有功能性修改。只在本機保存由 pain 執行的既有唯讀腳本輸出：

- `read_hpll_helper_correlation.tcl 30 1000`
- `read_wb_timeseries_session.tcl 8 1000 3`

本輪沒有重新編譯、沒有產生新 SOF、沒有燒錄，也沒有 reboot。

## 使用的來源與安全性說明

`vendor/wrpc-sw/include/hw/softpll_regs.h` 定義：

- `TRR_CSR`：tag FIFO 狀態，包含 empty bit。
- `TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`TAG_SOURCE_COUNT`、`TAG_REF_COUNT`、`TAG_FEEDBACK_COUNT`：唯讀計數器。
- `TRR_R0`：tag FIFO data output register。讀取它可能取出 FIFO 項目，因此本輪不讀取。

這個限制很重要：觀測工具不能為了取得一筆 tag 而改變正在驗證的 SoftPLL runtime。

## Runtime 原始結果

原始輸出已保存於本目錄：

- `jtag_hpll_helper_step4_current_20260820.log`
- `jtag_step4_clock_activity_20260820.log`

### Slave 的有效觀測

在可接受的 Slave frame 中可看到：

- `WDIAGS_MODE=3`、`WDIAGS_PTP=9`。
- `WDIAGS_FOREIGN_META=03000001`，foreign master 與 parent discovery 仍存在。
- `LOCK_ENABLE=4`、`LOCK_POLLS` 有數值，表示 `locking_enable()` 路徑曾被執行。
- `SPLL_STATE=00030009`；依 `softpll_export.h` 的 source-based decode，低 8 bit 是 `SEQ_CLEAR_DACS=9`，不能誤寫成 `SEQ_WAIT_HELPER=4`。
- `RCER=00000001`，reference channel enable 仍存在。
- `TRR_CSR=00020000`，empty bit 為 1，沒有可安全取出的 tag FIFO 項目。
- `TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`IRQ_COUNT`、shadow `REF/TAG`、`HELPER_UPDATE_COUNT` 在這次有效 sample 中沒有呈現增加。
- `DAC_HPLL`、`DAC_MAIN` 沒有形成新的 helper correction / DCO step 證據；helper 仍為 `locked=0`。
- `WR_CLOCK_ACTIVITY` 的 reference、DMTD、RX activity/toggle 有變化，表示來源時鐘與 PHY clock domain 並非完全停止。

### Master 的限制

部分 Master 讀取回報 `No In-System Sources and Probes instance was found`，另有非完整 frame 被 reject。這些列不能用來宣稱 Master 的 Step 1～3 或 Step 4 gate；Master 仍應以同一 exact bitstream 的一般 runtime script 與有效 frame 為準。

## Observation

目前最可靠的證據停在 SoftPLL event chain 的上游：

```text
clock / PHY activity = 有
TAG_VALID / TRR_WRITE = 沒有增加
IRQ = 沒有增加
helper_update = 沒有增加
DAC completed step = 沒有證據
```

因此目前不是「helper 已經產生 correction，但 DCO actuator 沒反應」的 B 類證據。比較符合 A 類：tag/reference event 沒有形成可供 `spll_irq_entry()` 消費的有效 TRR event；但因為 `SPLL_STATE=SEQ_CLEAR_DACS` 也可能反映 runtime re-init/reset context，本輪仍不能把根因寫死成單一硬體故障。

## Conclusion

本次唯讀觀測**不支持 Step 4 PASS**，也沒有做任何 functional change。證據只支持：

1. Slave 的 PTP parent、`WRS_S_LOCK`/`locking_enable()` 相關狀態仍可見。
2. reference/PHY clock activity 存在。
3. 在本次 session 觀測期間，沒有看到從 raw tag arbitration、TRR write、IRQ 到 helper update 的連續活動。
4. 因此目前第一個待釐清節點是 `TAG_VALID/TRR_WRITE` 之前或其附近的 runtime event 產生/消費上下文，而不是已證明的 DCO actuator 問題。

不能由本輪資料宣稱：

- SoftPLL 已 locked。
- `time_valid=1`。
- DCO/I2C 一定故障。
- DDMTD polarity、PI gain 或 lock threshold 是根因。

## Next Step

1. 先在同一份 exact bitstream 上重新做一次 read-only raw event-chain session，明確記錄 `SPLL_CSR/ECCR/OCCR`、`EIC_IDR/IER/IMR/ISR`、`TRR_CSR`、五個 raw counters、`SPLL_STATE` 與 `LOCK_ENABLE` 的前後差值。
2. 若 `TAG_VALID/TRR_WRITE` 仍為零，分類為 A1：先查 tagger/reference enable 與 runtime reset/sequence context；不先改演算法。
3. 若 raw counters 增加但 IRQ 不增加，分類為 A2：只查 IRQ enable/delivery。
4. 若 IRQ 增加但 helper update 不增加，分類為 A3：只查 software dequeue/source filtering。
5. 只有在上述分類完成後，才設計一個最小功能性 A/B；不修改 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。


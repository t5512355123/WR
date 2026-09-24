# EXP-WRPC-STEP4-D1-HIGH-RUN-20260823

## 實驗識別

- 日期：2026-08-23
- 實驗名稱：DMTD sampler `clk_i_d1` 高電位連續長度觀測
- Git branch：`exp/step4-softpll-enable`
- Git commit：`8cdb67bb974424c047e526c26e9aa3ad4e62e48f`
- pain checkout：detached exact commit（provenance 中 branch 欄位留白）
- 實驗類型：fresh build、fresh program、read-only runtime observation

## 目的與唯一變因

本輪要驗證 `dmtd_sampler` 內部 `clk_i_d1` 的高電位是否能形成足夠長的連續 sample，藉此區分前一輪已觀測到的 input LOW-run 與後續 DMTD deglitch boundary。唯一新增的是 read-only debug counter：以飽和計數方式保存 REF/FB `clk_i_d1` 的最大 HIGH-run；此訊號不接入 `clk_sampled_o`、deglitcher、FSM、SoftPLL 或任何控制路徑。

本輪沒有修改：Master/Slave role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 WRPC firmware functional behavior，也沒有寫入 Wishbone control register。

## Build 與 provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：Master/Slave 均為 `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`c0e69712d3eee632a0575423972e943f58b0fa65f83e4f76a871f52c652f182f`
- Slave MIF SHA256：`f016ace36c59e095234b1c5f138d4867dbb92bd8ac33427cce59cae991db994d`
- Master SOF SHA256：`5996c232a15c4d97f1b143083818d57eb121d7d044669a7fa02c69621cc1112f`
- Slave SOF SHA256：`791806022f701d55432d795a2c2d5e140069a5a537a13c1fe97dc52d970f3740`
- Master compile：`Full Compilation was successful`；`TIMING_CLOSED=NO`
- Slave compile：`Full Compilation was successful`；`TIMING_CLOSED=NO`

完整 build/provenance 證據：[`raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823)

## 燒錄結果

- Master programmer checksum：`0x30AA0BCA`
- Slave programmer checksum：`0x30AA1427`
- 兩片均回報 `Configuration succeeded -- 1 device(s) configured`
- Programmer 結果均為 0 errors、0 warnings

原始輸出：[`program_master.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/program_master.log)、[`program_slave.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/program_slave.log)

## Step 2/3 regression

使用既有 focused read-only scripts，先做 T0，再等待 60 秒做 T1。每個 script 都由 Quartus SignalTap/STP 完整執行並回報成功，沒有 Tcl exception。

| 時點 | 板卡 | 有效 samples | invalid | PTP TX delta | Step 2 | Step 3 | 狀態證據 |
|---|---|---:|---:|---:|---|---|---|
| T0 | Master | 20 | 0 | 64 | PASS | NA | STABLE |
| T0 | Slave | 20 | 0 | 29 | PASS | PASS | READ_INCONSISTENT |
| T1 | Master | 20 | 0 | 108 | PASS | NA | STABLE |
| T1 | Slave | 20 | 0 | 14 | PASS | PASS | READ_INCONSISTENT |

Slave 的 state shadow consistency 仍標記為 `READ_INCONSISTENT`，但 repeated focused evidence 中 parent、WR message、LOCK_ENABLE 與 Step 3 gate 成立，因此沒有把單一 state snapshot 直接改判成硬體失敗。

原始輸出：[`step3_t0.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/step3_t0.log)、[`step3_t1.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/step3_t1.log)。

## DMTD d1 觀測結果

新欄位以 32-bit packed value 讀回：低 16 bits 為 REF，高 16 bits 為 FB。數值是觀測期間的最大連續 HIGH sample 長度。

| 時點 | 板卡 | REF input LOW max | FB input LOW max | REF d1 HIGH max | FB d1 HIGH max | REF HIGH qualification max | FB HIGH qualification max |
|---|---|---:|---:|---:|---:|---:|---:|
| T0 | Master | 65535 | 513 | 65535 | 7 | 9 | 7 |
| T0 | Slave | 65535 | 61818 | 65535 | 88 | 86 | 88 |
| T1 | Master | 17 | 29440 | 65535 | 7 | 9 | 7 |
| T1 | Slave | 65535 | 61818 | 65535 | 90 | 86 | 90 |

Step 4 event chain 的結果：

- Master T0/T1：sampled transition 有觀測值，但 `accept=0`，DMTD event、tag、TRR、IRQ、helper update 均沒有 sustained activity。
- Slave T0/T1：sampled transition 有觀測值；T1 曾看到 `dmtd=1`，但 `accept=0`，pending/grant/tag/TRR/IRQ/state transition/helper update 沒有形成持續活動。
- T1 Master 的 sampled counter 顯示 `DECREASED_OR_RESET`；這次只標示為 counter reset/wrap 或非 atomic read 的觀測狀態，不把它當成硬體 failure。

原始輸出：[`step4_t0.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/step4_t0.log)、[`step4_t1.log`](raw/EXP-WRPC-STEP4-D1-HIGH-RUN-20260823/step4_t1.log)。

## 判讀

Slave FB 的 input LOW max 很大（61818），但對應的 `d1` HIGH max 只有 88/90，表示長 LOW-run 沒有在觀測到的 d1 訊號上形成同等長度的 HIGH-run。這使 unresolved region 優先落在 `clk_in -> clk_i_d0 -> en_i_d0 -> clk_i_d1` 的取樣/反相/enable 邊界，尚不能把根因定為某一個硬體元件、clock polarity 或 PHY 問題。

Master REF 的 d1 HIGH max 飽和為 65535，而 Slave FB 只有約 90；REF/FB 的差異也表示必須先做 source-backed channel/configuration audit，不能直接將單一通道的數值推廣成全系統結論。

這次 JTAG scripts 均完整結束，沒有在本輪觀測到會中止後續讀取的 measurement exception。因此 Step 4 未通過是因為 accepted DMTD 與下游 event chain 沒有 sustained activity，不是由單一 invalid mailbox sample 造成。

## Regression gate 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = NOT_OBSERVED_FOR_COMPLETE_RUN
```

`STEP4_ALLOWED=YES` 只表示 Step 2/3 regression barrier 已重新通過；不表示 Step 4 已完成。

## 下一步

先做 source-backed 的 REF/FB channel mapping 與 `clk_i_d1` 觀測語意 audit，下一輪仍只新增一個 read-only diagnostic variable。暫不修改 `g_reverse`、`g_divide_input_by_2`、deglitch threshold、FSM、SoftPLL、WR signaling、PI、DCO、SI5340 或 PHY。

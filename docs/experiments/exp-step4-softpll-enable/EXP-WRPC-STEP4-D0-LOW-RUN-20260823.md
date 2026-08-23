# EXP-WRPC-STEP4-D0-LOW-RUN-20260823

## 實驗識別

- 日期：2026-08-23
- 實驗名稱：DMTD sampler `clk_i_d0` 低電位連續長度觀測
- Git branch：`exp/step4-softpll-enable`
- source commit：`ec3f7cc19baec94afc3a98d2a162f9583ce67efd`
- pain checkout：detached exact commit
- 實驗類型：fresh firmware build、fresh Quartus compile、雙板 fresh program、read-only runtime observation

## 目的與唯一變因

前一輪已知 Slave FB 的 `clk_in` LOW max 很大，但 `clk_i_d1` HIGH max 只有約 90。本輪只新增 `clk_i_d0` LOW-run max，觀察 `clk_in` 與 `clk_i_d1` 之間的 source-defined sampler 節點，將 unresolved boundary 二分為：

```text
clk_in -> clk_i_d0
或
clk_i_d0 / en_i_d0 -> clk_i_d1
```

新 counter 是飽和的 read-only observability，經 synchronizer 後由 Wishbone `0x0010025C` 讀回；不接入 `clk_sampled_o`、deglitcher、FSM、SoftPLL 或任何控制路徑。

本輪沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 WRPC firmware functional behavior，也沒有寫入 Wishbone control register。

## Build 與 provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：Master/Slave 均為 `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`f143bfc74d85b42440b46030bfbeec291eb2563642dd5119cc030d1c9ec0a45d`
- Slave MIF SHA256：`661f37e5a70a6c3b19f7f6e1480655f7b69b2ae6cde1beb7270b78c0947b58b8`
- Master SOF SHA256：`232a347acbcb58a4f51fe51f425593c1fe2856919a3b37a9ea4e6de7a24e7a91`
- Slave SOF SHA256：`a95f5bb779de42a632f6da0f759f99cff046565563abf8e6a06d701c70f293dd`
- Master compile：`Full Compilation was successful`、`TIMING_CLOSED=NO`
- Slave compile：`Full Compilation was successful`、`TIMING_CLOSED=NO`

完整 provenance、build logs 與原始 JTAG logs：[`raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823)

## 燒錄結果

- Master programmer checksum：`0x30A8B5EC`
- Slave programmer checksum：`0x30AA1736`
- Master/Slave 均回報 `Configuration succeeded -- 1 device(s) configured`
- Programmer 均為 0 errors、0 warnings

原始輸出：[`program_master.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/program_master.log)、[`program_slave.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/program_slave.log)

## Step 2/3 regression

T0 為燒錄後等待 30 秒的 20 samples；T1 為再等待 60 秒後的 20 samples。兩個時間點的 focused scripts 都完整結束，return code 為 0。

| 時點 | 板卡 | valid/invalid | counter decreased | PTP TX delta | Step 2 | Step 3 | state evidence |
|---|---|---:|---:|---:|---|---|---|
| T0 | Master | 20/0 | 0 | 67 | PASS | NA | STABLE |
| T0 | Slave | 20/0 | 0 | 11 | PASS | PASS | READ_INCONSISTENT |
| T1 | Master | 20/0 | 0 | 105 | PASS | NA | STABLE |
| T1 | Slave | 20/0 | 0 | 15 | PASS | PASS | READ_INCONSISTENT |

Slave 的 `READ_INCONSISTENT` 仍保留為 state shadow consistency evidence；repeated parent、WR message、LOCK_ENABLE 與 Step 3 focused gate 仍成立，因此沒有把單一 state read 直接判為硬體失敗。

原始輸出：[`step3_t0.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/step3_t0.log)、[`step3_t1.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/step3_t1.log)。

## DMTD run-length 結果

所有欄位都是觀測期間最大連續 sample 長度；packed 32-bit word 的低 16 bits 是 REF，高 16 bits 是 FB。

| 時點 | 板卡 | input LOW max REF/FB | d0 LOW max REF/FB | d1 HIGH max REF/FB | HIGH qualification max REF/FB |
|---|---|---|---|---|---|
| T0 | Master | `65535/12865` | `65535/6` | `65535/6` | `15/0` |
| T1 | Master | `65535/12915` | `65535/6` | `65535/6` | `15/0` |
| T0 | Slave | `51/133` | `7/1` | `7/1` | `7/1` |
| T1 | Slave | `55/133` | `7/1` | `7/1` | `7/1` |

## Step 4 downstream結果

- Master T0：sampled transition 有活動，但 `accept_ref=0`、`accept_fb=0`，下游 DMTD event、tag、TRR、IRQ、helper 沒有持續活動。
- Master T1：`accept_ref=0`、`accept_fb=0`，下游 event chain 仍沒有 sustained activity。
- Slave T0/T1：sampled transition 有活動，但 `accept_ref=0`、`accept_fb=0`，pending/grant/tag/TRR/IRQ/state transition/helper 沒有形成持續活動。
- 個別 sampled counter 在某些讀取窗口顯示 `DECREASED_OR_RESET`，依既有規則只標示為 reset/wrap 或非 atomic read 可能性，不當成硬體 failure。

原始輸出：[`step4_t0.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/step4_t0.log)、[`step4_t1.log`](raw/EXP-WRPC-STEP4-D0-LOW-RUN-20260823/step4_t1.log)。

## 判讀

Slave FB 的 `input LOW max=133`，但 `d0 LOW max=1`，而 `d1 HIGH max=1`。這表示長 input LOW history 在進入 `clk_i_d0` 時就沒有以同樣長度被保留；相較於前一輪只知道 d1 約 88/90，本輪已把觀測上的第一個 mismatch 優先收斂到：

```text
clk_in -> clk_i_d0 sampling boundary
```

Slave REF 的 input LOW `51/55`、d0 LOW `7`、d1 HIGH `7`，也顯示 REF 通道具有不同的 sampling relationship。Master REF 的 input/d0/d1 都可達 `65535`，證明 d0/d1 counter 結構本身可以保存長 run；因此目前不能把問題泛化成全域 RTL pipeline 必然截短。

這些證據支持 channel-specific 的 `clk_in` 與 `clk_dmtd_i` 取樣關係是主要 unresolved region，但尚未證明實際根因是某個 clock、enable、polarity、PHY 或板級問題。Step 4 仍因 accepted DMTD 與 downstream chain 沒有 sustained activity 而未通過。

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

`STEP4_ALLOWED=YES` 只表示 Step 2/3 regression barrier 重新通過，不表示 Step 4 已完成。

## 下一步

先進行 source-backed 的 channel-specific `clk_in`/`clk_dmtd_i` 取樣關係 audit，並保持單一 read-only 變因。不要直接修改 `g_reverse`、`g_divide_input_by_2`、deglitch threshold、FSM、SoftPLL、WR signaling、PI、DCO、SI5340 或 PHY；必須先由 source 與現有 runtime evidence 判定下一個可辨識的觀測點。

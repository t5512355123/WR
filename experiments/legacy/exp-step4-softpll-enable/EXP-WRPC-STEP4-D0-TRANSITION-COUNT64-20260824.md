# EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Source commit：`63fd80ad080a951cc8e7ae9d4c7f35d0d3f558ef`
- 實驗狀態：已完成 fresh build、雙板燒錄、Step 1～3 barrier 與 Step 4 T0/T1 量測

## 驗證目標

上一輪已證明 DMTD、REF 與 FB 原生時鐘均持續運作，且 sampler 輸出的
`sampled_transition` 大量增加，但 deglitch accept 與後續 event 仍為零。
本輪只回答：既有第一級取樣暫存器 `clk_i_d0` 在相鄰 DMTD 週期之間實際
發生多少次轉換，以及此轉換率與 DMTD clock、既有 `sampled_transition`
之間的關係。

## 唯一修改變因

- REF 與 FB 各新增一個 64-bit、自然回繞的 `D0_TRANSITION_COUNT64`。
- counter 只比較既有 `clk_i_d0` 與前一個 DMTD sample，不另外取樣
  非同步 `clk_in_i`。
- binary counter 與 registered Gray encoder 位於 sampler clock domain；
  Gray bus 經兩級同步器進 `clk_sys_i` 後才轉回 binary。
- Wishbone 唯讀 alias：REF LO/HI=`0x00100250/0x00100254`，FB
  LO/HI=`0x00100260/0x00100264`；每筆以 `HI1 -> LO -> HI2` 一致性讀取。
- 沒有修改 PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock
  threshold、DCO、SI5340、PHY 或 WRPC firmware 功能行為。

## 建置來源與雜湊

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`9ab0111b92943a79f9b8fe0cfe9f7b24f169a69c2be39fac64426ebb7e3e9eb1`
- Slave MIF SHA256：`39c38e3083755ff726b9cf0eac268f021d935d1439f13f147429f4fff364b191`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`ab9287e13c0a2ea43910c2e4fba8b07f607bbdf8f5c2947d40353668806fb9ad`
- Slave SOF SHA256：`55963c71be3e374852744f61b21f9f8f6c50001b85fe4b35d2dc41ecc25ae405`

Master 與 Slave 均回報 `Full Compilation was successful`，但整體 timing
尚未 closed：Master setup/hold WNS 為 `-0.287/+0.038 ns`，Slave 為
`-0.177/+0.037 ns`。因此後續結果必須保留 timing caveat，不能單憑
counter 值宣稱根因已確定。

## 燒錄結果

- Master：2026-08-24 05:26～05:27（Asia/Taipei）燒錄成功；programmer
  checksum `0x30AF1037`；`Configuration succeeded -- 1 device(s)
  configured`；`0 errors, 0 warnings`。原始輸出保存於
  `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/program_master.log`。
- Slave：2026-08-24 05:27（Asia/Taipei）燒錄成功；programmer checksum
  `0x30AE4903`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`。原始輸出保存於
  `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/program_slave.log`。

## Runtime 原始結果

### Step 1～3 regression barrier

燒錄後執行 `read_wr_handshake_focused.tcl 30 1000`，結果如下：

| 板卡 | valid/invalid | PTP TX delta | Step 2 | Step 3 |
|---|---:|---:|---|---|
| Master `DE5 [1-11.1]` | 30/0 | 169 | PASS | N/A |
| Slave `DE5 [1-11.2]` | 30/0 | 23 | PASS | PASS |

Slave 的 30 筆 accepted samples 全部符合 foreign master、parent metadata、
`LOCK`、`SLAVE_PRESENT` 與 `LOCK_ENABLE` 條件，`signal_good=30`、
`signal_bad=0`。live WR state 仍是 30/30 `WRS_IDLE`，與其餘握手證據衝突，
因此沿用既有規則標記為 `STATE_EVIDENCE=READ_INCONSISTENT`，不將其誤判成
Step 3 regression。

### Step 4 T0/T1 focused sampling

每個視窗執行 `10 x 500 ms` read-only sampling，T0 與 T1 中間等待 10 秒。
以下列出主要的 Slave 證據：

| 指標 | T0 | T1 |
|---|---:|---:|
| DMTD native frequency | 124,979,376.699 Hz | 124,958,578.690 Hz |
| REF native frequency | 125,000,740.170 Hz | 125,006,522.888 Hz |
| FB native frequency | 125,005,286.284 Hz | 124,986,919.863 Hz |
| REF D0 transition delta | 684,216,580 | 685,378,722 |
| REF D0 / DMTD | 0.991961566 | 0.992193794 |
| REF sampled / D0 | 1.000010239 | 1.000004612 |
| FB D0 transition delta | 681,194,433 | 682,213,092 |
| FB D0 / DMTD | 0.987580126 | 0.987611045 |
| FB sampled / D0 | 0.999998119 | 0.999978595 |
| REF/FB accept delta | 0 / 0 | 0 / 0 |

Slave 的 D0、native 與本輪用來比較的 sampled 讀值在兩個視窗均得到有效
結果。T1 中舊的 32-bit `DMTD_REF_SAMPLED` / `DMTD_FB_SAMPLED` 跨越
`0xFFFFFFFF`，所以原始 time-series 顯示 `DECREASED_OR_RESET`；這是
32-bit counter 回繞，不影響同一輪以 64-bit D0 counter 與 modulo sampled
delta 得到的比例。

兩個視窗的 REF/FB accept、DMTD event、tag、TRR、IRQ 與 helper update delta
皆為 0。T0 的 event boundary 為
`DMTD_SAMPLED_TRANSITION_TO_DEGLITCH_ACCEPT`；T1 的舊 32-bit sampled
summary 因回繞只顯示 `DMTD_SAMPLED_TRANSITION`，應與上述有效 D0/native
證據一起解讀，不能視為 sampled activity 消失。

Master T1 的 `NATIVE_FB_SAMPLED` 第一筆被讀成 `0x00000000`，造成
`sampled/D0=3.947780628` 的不合理值。這是單一 32-bit mailbox sample 未被現行
合法範圍規則排除的讀取異常；本輪不使用該值推論硬體行為，根因收斂以兩次
一致的 Slave 結果為主。

原始證據保存於：

- `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/step123_focused.log`
- `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/step4_t0.log`
- `raw/EXP-WRPC-STEP4-D0-TRANSITION-COUNT64-20260824/step4_t1.log`
- 同一資料夾內的 firmware/build、Quartus compile 與 programmer logs

## Observation

- Step 1、Step 2、Step 3 regression barrier 均重新通過，因此允許執行
  Step 4 read-only 實驗。
- Slave REF/FB 的 `sampled/D0` 在 T0/T1 都非常接近 1，表示從既有
  `clk_i_d0` 到後段 sampled transition 計數之間沒有觀測到額外的大量遺失。
- Slave REF 的 `D0/DMTD` 約為 `0.9920`，FB 約為 `0.9876`；先前相對
  DMTD 少掉的轉換比例已存在於第一級 `clk_i_d0` 觀測結果。
- REF/FB native clock 與 DMTD clock 都持續運作在約 125 MHz，但 deglitch
  accept 與所有下游 event 仍沒有 sustained activity。
- 兩片設計整體 timing 未 closed；本輪結果只能定位觀測邊界，不能排除 timing
  對實際行為的影響。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_REF_FB_D0_TRANSITION = ACTIVE
SLAVE_D0_TO_SAMPLED_PIPELINE = PRESERVED_APPROX_1_TO_1
SLAVE_DEGLITCH_ACCEPT_AND_DOWNSTREAM = NONE_OBSERVED
FIRST_INACTIVE_BOUNDARY = DMTD_SAMPLED_TRANSITION_TO_DEGLITCH_ACCEPT
ROOT_CAUSE = NOT_PROVEN
```

本輪支持轉換比例差異不晚於最初的 `clk_in_i -> clk_i_d0` 非同步取樣關係
就已出現，並排除 D0 到後段 sampled 計數管線再大量漏掉轉換的假設。這仍不等於
已證明 DDMTD polarity、相位關係、metastability、threshold 或 timing 是根因。

## Next Step

先將本輪完整證據推送至 GitHub，請 White Rabbit 技術對話審閱後，再決定下一個
只增加 read-only observability 的單一變因；在審閱前不修改 functional behavior。

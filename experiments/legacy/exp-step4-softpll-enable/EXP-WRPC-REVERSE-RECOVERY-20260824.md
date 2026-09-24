# EXP-WRPC-REVERSE-RECOVERY-20260824

## 實驗摘要

- Experiment ID：`EXP-WRPC-REVERSE-RECOVERY-20260824`
- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Git commit：`7cda07f15515cea778068e606c20c2eecca0a1e3`
- Commit message：`實驗：回復Slave控制DMTD方向`
- 實驗類型：Step 2 / Step 3 read-only regression recovery A/B
- 是否修改 FPGA RTL、firmware 演算法、PTP、WR signaling、SoftPLL、PHY：否
- 本次唯一功能變因：移除 Slave top-level 的 `g_softpll_reverse_dmtds => true`，恢復預設 DMTD 方向；保留既有 TRR POP observability counter 與 JTAG diagnostics。

## 想驗證什麼

前一個 current image 在 Slave 出現 `PTP=4`、沒有 Foreign Master、以及 Step 3 不穩定。這次只測試「Slave reverse DMTD 方向是否是 Step 2 / Step 3 regression 的原因」。若移除 reverse DMTD 後，fresh build、fresh SOF、雙板燒錄與 focused repeated sampling 都恢復，才可支持這個變因與 regression 有關。

本實驗不以 SoftPLL lock 或 `time_valid=1` 為目標，也不允許藉由修改 SoftPLL 演算法來讓 Step 4 通過。

## Build 與 provenance

本次使用 exact HEAD `7cda07f15515cea778068e606c20c2eecca0a1e3`，在 pain 以 clean firmware build 與 `quartus_sh --clean` 流程重新產生 Master/Slave MIF、SOF。

### Toolchain

- Quartus Prime：17.0.0 Build 595
- Programmer：Quartus Prime Programmer 17.0.0 Build 595
- JTAG read：Quartus Prime SignalTap II / `quartus_stp`

### Master artifact

- MIF SHA256：`cbea463ae832f27d6e20770ecd28b1c00b073f2149984d394be1e7fd02f530cf`
- SOF SHA256：`8b0004c173c0c1cf7cfa3cb3b73275d8f4abf865793c9ba82077f2d66f200505`
- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Programmer checksum：`0x30B32E2A`

### Slave artifact

- MIF SHA256：`3388ecb9125d4207fac0b8d3f4ca4e9032dd24ad555fb365376d95ff7278c3e1`
- SOF SHA256：`c81179fba0555ae00cea2a428f1403e0eb7975204fb32953ca5f528c169b1a2a`
- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Programmer checksum：`0x30B41C87`

### Build 結果

- Firmware build：成功
- Master Quartus compile：0 errors、282 warnings；timing closed：NO，worst setup `-0.394 ns`
- Slave Quartus compile：0 errors、282 warnings；timing closed：NO，worst setup `-0.390 ns`，worst hold `0.037 ns`
- Master programming：configuration succeeded，0 errors / 0 warnings
- Slave programming：configuration succeeded，0 errors / 0 warnings
- `quartus_stp` dashboard：script evaluation successful，0 errors / 0 warnings

原始檔案保存在本資料夾的 `raw/EXP-WRPC-REVERSE-RECOVERY-20260824/`。

## Regression 方法

使用 repository 既有 focused script：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

每次等待約 60 秒後取樣；每筆樣本先做 mailbox read validation。重測一次以確認結果是否穩定。另執行一次 read-only dashboard 取得 Step 1～Step 6 的整體摘要。

## 結果一：focused regression 第一次

### Master

```text
valid_samples=20 invalid_samples=0 counter_decreased=0 PTP_TX_DELTA=37
STEP2_REGRESSION=PASS
```

Master 連續樣本維持正確 MAC、`MODE=2`、`PTP=6`、PTP counter 有增加，PHY/link 狀態正常。

### Slave

```text
valid_samples=20 invalid_samples=0 counter_decreased=0 PTP_TX_DELTA=6
STEP2_REGRESSION=FAIL
STEP3_REGRESSION=FAIL
STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 樣本主要為 `PTP=4`、`foreign=0/255`、`RX=0x0000/0`、`TX=0x1000/8`、`LOCK_ENABLE=0`、`RCER=0`；`RXERR` 約由 96 增至 110。

## 結果二：focused regression 重測

### Master

```text
valid_samples=20 invalid_samples=0 counter_decreased=0 PTP_TX_DELTA=55
STEP2_REGRESSION=PASS
```

### Slave

```text
valid_samples=10 invalid_samples=10 counter_decreased=0 PTP_TX_DELTA=11
STEP2_REGRESSION=FAIL
STEP3_REGRESSION=FAIL
STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 仍未以 focused accepted samples 穩定得到 `PTP=9` 與 Foreign Master。第二次另有 10 筆 JTAG mailbox read 被 validation reject，不能當成硬體功能證據。

## 結果三：dashboard 唯讀 snapshot

dashboard 在同一 fresh image 的稍後讀值中顯示：

- Master：Step 1 pass、Step 2 pass；MAC 正確、`MODE=2`、`PTP=6`，PTP/MiniNIC counters 有活動，`RXERR delta=0`。
- Slave：Step 1 pass；讀到 MAC 正確、`MODE=3`、`PTP=9`、PTP/MiniNIC counters 有活動、Foreign Master count=1，但 `RXERR delta=9`。
- Slave Step 3：`parentIsWRnode=0`、`parentCalibrated=0`、state `WRS_IDLE`，因此 Step 3 error。
- Slave Step 4：`SPLL_STATE=3`、`SEQ_CLEAR_DACS`、`RCER=1`，但 `OCER` timeout，DMTD、tag、TRR、TRR POP、IRQ、helper update 的 delta 都是 0，因此 Step 4 error。

dashboard 文字同時把 Slave Step 2 顯示為 `pass`，但同一區塊已顯示 `WDIAGS_RXERR delta=9` 為 error。這表示目前 dashboard 的 summary aggregation 仍有判定缺陷；該 snapshot 不能覆蓋 focused regression，也不能單獨宣稱 Step 2 PASS。

## 結果判定

```text
STEP1_REGRESSION = PASS（dashboard 顯示 Master/Slave PHY、link、encoding 狀態正常）
STEP2_REGRESSION = INVALID / RETEST
STEP3_REGRESSION = INVALID / RETEST
STEP4_ALLOWED    = NO
```

### 證據解讀

本次唯一變因「移除 Slave reverse DMTD」沒有讓 focused Step 2 / Step 3 regression 穩定通過。dashboard 稍後讀值又曾看到 Slave 暫時進入 `PTP=9` 與 Foreign Master=1，但同時有 RXERR 增加、parent flags 不成立，且與 focused samples 不一致。

因此目前只能判定：

1. Master fresh image 的 Step 2 evidence PASS。
2. Slave 的 read-only evidence 在不同取樣工具/時間間出現不一致。
3. 目前不能把這一輪結論寫成 `HARDWARE/FIRMWARE FAILURE`，因為存在 invalid mailbox sample、時間狀態變化，以及 dashboard aggregation 誤判。
4. 也不能把它寫成 Step 2 / Step 3 PASS；可靠 regression gate 尚未建立。
5. 「移除 reverse DMTD」尚不足以解釋或修復現象，後續必須回到已知成功 tree 與 current tree 的 source-level functional delta 做更小範圍 A/B。

## Conclusion

本次 fresh HEAD build、fresh SOF、雙板 program 均成功，但 Step 2 / Step 3 的 Slave repeated evidence 沒有穩定重現。因此本實驗失敗於「恢復 regression gate」，不是 compile 或 programmer failure；Step 4 禁止開始。

目前最保守且有證據支持的結論是：

```text
HARDWARE/FIRMWARE FAILURE：尚未證明
JTAG/DASHBOARD MEASUREMENT FAILURE：已觀察到，包含 invalid mailbox samples 與 Step 2 summary aggregation 誤判
STEP4_ALLOWED：NO
```

## Next Step

1. 保留本次 SOF 與所有 raw logs，不覆蓋。
2. 針對 `7dd298bb` 已知成功 tree 與 current `7cda07f` 做 source-level diff，先隔離後續 diagnostics/SoftPLL mapping 變更，不修改 PTP/WR/SoftPLL 演算法。
3. 先建立同一套 focused read-only acceptance parser：要求 20～30 個 accepted samples；invalid sample 不得混入統計；counter decrease 只標記 `RETEST`；單一 counter delta=0 不得使 Step 2 hard fail。
4. 只有 Slave 的 Step 2 與 Step 3 連續 accepted samples 穩定通過後，才重新計算 `STEP4_ALLOWED=YES`。

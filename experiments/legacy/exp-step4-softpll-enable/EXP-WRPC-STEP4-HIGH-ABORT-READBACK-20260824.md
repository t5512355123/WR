# EXP-WRPC-STEP4-HIGH-ABORT-READBACK-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-READBACK-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 硬體 source commit：`126dda8550db3f8de33c9e37303e4a16aa730350`
- JTAG diagnostics commit：`51f874ab052c770d8e35e678f535892c38502847`
- 狀態：沿用目前硬體，只執行 read-only JTAG；本輪沒有 firmware build、Quartus compile 或 FPGA program

## 想驗證什麼

上一輪確認 Slave REF/FB 位於 `GOT_EDGE`，sampled transition 持續增加，但 accepted DMTD
與後續 event chain 沒有 sustained activity。本輪只回答：

> 目前硬體的 REF/FB 32-bit HIGH qualification-abort counter，是否能用 delta 判斷
> `GOT_EDGE` 的 HIGH qualification 正在反覆被 LOW sample 中斷？

## 本輪操作變因

本輪沒有修改任何 RTL、firmware、Wishbone mapping 或演算法。只讀取 source 已存在的：

- `0x001002A0`：REF 32-bit HIGH qualification-abort counter
- `0x001002A4`：FB 32-bit HIGH qualification-abort counter

上述欄位在 source 中由 `dbg_high_qual_abort_count_o` 經同步後接到既有
`diag_dmtd_ref_seen_i/diag_dmtd_fb_seen_i` read-only words。觸發條件仍是 deglitch FSM
位於 `GOT_EDGE`，`stab_cntr` 已開始累積，卻在達到 threshold 前遇到 LOW sample。

## 沿用的 Hardware Provenance

本輪沒有重新燒錄，板上仍是上一輪 exact source commit `126dda8` 所產生的 fresh SOF：

- Quartus：17.0.0 Build 595 Standard Edition
- Master MIF SHA256：`e1b83b06e1c589ce76bce59aebddae9e080331ebb479dde93c65c0599748ec2d`
- Slave MIF SHA256：`b7410ed150e30b42f8ac0bdae97ad4b50c9bca3fedc7b19c4c4cfa9865f0a5be`
- Master SOF SHA256：`486c54a8deb633a46decab57340ecc16b07a5833c91532a8ea2879eb86c5f108`
- Slave SOF SHA256：`cdfaf06ddca05aa9a972d990fb907c8980d87fc338f81ce7efeeba8f011c9a81`
- Master programmer checksum：`0x30A84EF1`
- Slave programmer checksum：`0x30B13132`

完整 build/program provenance 見前一筆：
`EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824.md`。

## JTAG / Runtime 原始結果

### Step 1～3 regression barrier

`read_wr_handshake_focused.tcl 20 1000`：

| Gate | Master | Slave |
|---|---|---|
| 有效 samples | 20/20 | 20/20 |
| 無效 samples | 0 | 0 |
| Counter decrease | 0 | 0 |
| PTP TX delta | 114 | 12 |
| Step 2 | PASS | PASS |
| Step 3 | N/A | PASS |

Slave 20/20 samples 均維持有效 WR handshake evidence；保留既有
`POST_STEP3_LOCK_STAGE=TIMEOUT` 與 `STATE_EVIDENCE=READ_INCONSISTENT`，不把它誤判成
Step 3 regression。

### Step 4 HIGH-abort T0/T1

兩次 `read_step4_startup_focused.tcl 10 500 all` 均完整結束，沒有 Tcl exception。

| Board | Window | REF HIGH-abort first/last | FB HIGH-abort first/last | REF/FB state | Slave accept/downstream |
|---|---|---|---|---|---|
| Master | T0 | `FFFFFFFF/FFFFFFFF` | `00000000/00000000` | `GOT_EDGE/WAIT_STABLE_0` | N/A |
| Master | T1 | `FFFFFFFF/FFFFFFFF` | `00000000/00000000` | `GOT_EDGE/WAIT_STABLE_0` | N/A |
| Slave | T0 | `FFFFFFFF/FFFFFFFF` | `FFFFFFFF/FFFFFFFF` | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |
| Slave | T1 | `FFFFFFFF/FFFFFFFF` | `FFFFFFFF/FFFFFFFF` | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |

Slave sampled transition 仍持續大量增加：T0 FB delta=`686,696,027`；T1 REF/FB delta
分別為 `689,542,426 / 686,986,610`。T0 REF 跨越 32-bit 邊界，script 保留
`DECREASED_OR_RESET`，不把它當成硬體失敗。

Slave REF/FB HIGH-abort 在所有 accepted samples 都已是 `0xFFFFFFFF`。因此 script 顯示的
`delta=0` 只代表 counter 已飽和，不能支持「目前沒有 HIGH qualification abort」。

### Raw evidence

原始檔位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT-READBACK-20260824/`

- `EXP-WRPC-STEP4-HIGH-ABORT-READBACK-dashboard.log`
- `EXP-WRPC-STEP4-HIGH-ABORT-READBACK-step23.log`
- `EXP-WRPC-STEP4-HIGH-ABORT-READBACK-step4-t0.log`
- `EXP-WRPC-STEP4-HIGH-ABORT-READBACK-step4-t1.log`

## Observation

1. Step 1～3 barrier 再次通過，允許解讀 Step 4 read-only diagnostics。
2. Slave REF/FB current deglitch state 在 T0/T1 都是 `GOT_EDGE/GOT_EDGE`。
3. Slave sampled transition 持續增加，但 accepted DMTD 與 downstream chain 都沒有
   sustained activity，Step 4 仍未通過。
4. Slave REF/FB HIGH-abort counter 均已飽和為 `0xFFFFFFFF`；`delta=0` 是量測動態範圍
   不足，不是 abort 不活動的證據。
5. Master REF 也已飽和；Master FB 保持 0。不同 channel 不可用同一個零 delta 作相同推論。
6. 本輪沒有 functional 修改，也沒有新的 compile/program，因此不構成新的 SOF qualification。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_HIGH_ABORT32_READBACK = SATURATED
SLAVE_HIGH_ABORT_SUSTAINED_ACTIVITY = MEASUREMENT_INVALID
HARDWARE_FUNCTIONAL_FAILURE = NOT_PROVEN
JTAG_READ_FAILURE = NO
DIAGNOSTIC_DYNAMIC_RANGE_FAILURE = YES
```

目前不能用 32-bit cumulative HIGH-abort delta 回答 reviewer 的 binary question，因為 counter
在開始量測前已飽和。這是 observability 限制，不是 JTAG mailbox failure，也不能宣稱是
SoftPLL/RTL 根因。

## Next Step

將本紀錄與 raw evidence 推送 GitHub，請「分支 · White Rabbit 技術應用」依飽和證據指定
下一個單一、read-only、source-backed observability 變因。下一輪不得直接把 `delta=0`
解讀成 HIGH qualification 沒有被中斷。

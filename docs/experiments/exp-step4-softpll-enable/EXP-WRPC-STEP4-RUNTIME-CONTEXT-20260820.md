# EXP-WRPC-STEP4-RUNTIME-CONTEXT-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-RUNTIME-CONTEXT-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 狀態：**準備 clean build；尚未以本變因重新燒錄**

## 這次想驗證什麼

目前 fresh SOF 已觀察到 Slave：

```text
RCER=1、LOCK_ENABLE=4、SPLL_STATE=SEQ_CLEAR_DACS
TAG_VALID/TRR_WRITE/IRQ/HELPER_UPDATE_COUNT = 0
```

本輪只分辨兩種 runtime 情況：

1. `spll_init()` 或 `SEQ_CLEAR_DACS` 反覆被重新執行。
2. init 次數沒有增加，但 DAC timeout 已經過期，仍沒有 raw tag-driven IRQ。

## 相較 baseline 的唯一修改

只增加 read-only observability：

- firmware runtime counters：`spll_init_count`、`SEQ_CLEAR_DACS_entry_count`
- timer shadows：`current_tics`、`dac_timeout`、`last_init_tics`、`last_clear_dacs_tics`
- WDIAGS offsets：`0x13C..0x150`
- JTAG script：`scripts/jtag/read_step4_runtime_context.tcl`
- WDIAGS DPRAM 深度由 85 words 提供到 `0x150`

沒有修改：

- Master/Slave role、MAC、PHY、Simple Word Alignment、PTP/PPSI
- WR signaling 行為
- SoftPLL state transition、tagger enable、IRQ、PI、lock threshold
- DDMTD polarity、DCO gain、SI5340 控制

## 預期判讀

```text
Case A1a：INIT_COUNT 不增加、CLEAR_DACS_COUNT 不增加，
          CURRENT_TICS 已超過 DAC_TIMEOUT，raw event 仍為 0
          => init 後沒有 tag-driven IRQ/event。

Case A1b：INIT_COUNT 或 CLEAR_DACS_COUNT 增加，
          => runtime re-init 或 sequence reset loop。
```

## 建置與燒錄 provenance

待 exact commit 完成：

- firmware build log / MIF SHA256
- Master/Slave QSF、SDC、SOF SHA256
- Quartus version
- programmer output、checksum、configuration result

## JTAG 原始結果

待 clean build/program 後保存：

- `read_step4_runtime_context.tcl` 原始輸出
- `read_wb_runtime.tcl` Step 1～3 gate snapshot
- 必要時 raw helper correlation

## Conclusion

待實驗結果。即使本輪判定 A1a 或 A1b，也只代表找到第一個 runtime blocker，不代表 Step 4 PASS。

## Next Step

依結果再選一個最小 functional A/B；在此之前不修改 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。

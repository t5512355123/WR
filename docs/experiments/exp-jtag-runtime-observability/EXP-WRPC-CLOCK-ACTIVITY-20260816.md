# 實驗：EXP-WRPC-CLOCK-ACTIVITY-20260816

## 實驗名稱

`f4b7e79 加入時鐘域活動唯讀診斷`：確認 reference clock、DMTD（Digital Mixed-Mode Detection，數位混合模式偵測）clock 與 recovered RX clock 是否持續運作。本次不修改 WR 控制流程。

## 日期、版本與可追溯資訊

- 日期：2026-08-16
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`f4b7e797fea5391479be97431a47a4b9965f9015`
- GitHub：`git@github.com:t5512355123/WR.git`
- pain checkout：detached HEAD，明確指向上述 commit
- Quartus：`17.0.0 Build 595`

## 這次想驗證什麼

前一輪觀測長時間顯示 Slave 的 `REF_COUNT=0`、`TAG_COUNT=0`，且 sequence 停在 `SEQ_CLEAR_DACS`。本次只增加時鐘域活動計數器，驗證下列三個 source clock 是否真的有跳變：

1. `QSFPA_REFCLK_p`：WR/PHY reference clock。
2. `QSFPB_REFCLK_p`：DMTD clock。
3. `wr_rx_clk`：PHY recovered RX clock。

本次不把 clock 有活動等同於 SoftPLL 已收到 tag，也不把它等同於 WR 已同步。

## 相較 baseline 唯一修改了什麼

只在 Master/Slave JTAG top-level 增加三個 source-clock activity marker，將其同步到 `CLK_50_B2J` 後以 16-bit counter 累加，並透過 `altsource_probe` instance 7 唯讀讀出：

```text
bits  0..15 : QSFPA reference-clock activity counter
bits 16..31 : QSFPB DMTD-clock activity counter
bits 32..47 : recovered RX-clock activity counter
bits 48..50 : 三個 synchronized toggle marker
bit  51     : wr_ready
bit  52     : wr_rx_locked_to_ref
bit  53     : wr_rx_locked_to_data
```

Tcl 只增加 instance 7 的前後讀取與驗證；沒有修改 PHY、lane、polarity、line rate、PTP filter、servo、SoftPLL 控制、SI5340 或 PPS 控制。

## 建置與 artifact

pain 從 GitHub fetch 後 checkout 明確 commit，使用 Quartus 17 完成兩端 full compilation：

```text
Master Quartus build passed: DE5a_wr_master_jtag.sof (timing_closed=NO)
Slave  Quartus build passed: DE5a_wr_slave_jtag.sof (timing_closed=NO)
```

Master：

```text
QSF_SHA256=e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b
SDC_SHA256=b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
MIF_SHA256=3fa8dd7950415dc945ef339ccc29898cc88bb9d21fa380413dc5cbb88cac4fad
SOF_SHA256=53410372ad486af0d4c9d269d6232b8949367a2e6d001af6bcf46c8263f4d4e8
```

Slave：

```text
QSF_SHA256=199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58
SDC_SHA256=b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
MIF_SHA256=e31548728c805197c60adfdf7496e15799b68d1ece7ef95ba9fb18353c06a3e8
SOF_SHA256=aa83259c4009537282a7c83d995078612037bd39204e0656d9e729819e9e5d68
```

兩端 Fitter 均成功，但 timing 尚未完全關閉：Master worst setup slack `-2.974 ns`，Slave worst setup slack `-3.081 ns`。

## 燒錄結果

本次兩片 FPGA 均實際燒錄，使用 Quartus Programmer：

```text
Master cable: DE5 [1-11.1]
Master programmer checksum: 0x30ABDD91
Master: Configuration succeeded -- 1 device(s) configured
Master: Quartus Prime Programmer was successful. 0 errors, 0 warnings

Slave cable: DE5 [1-11.2]
Slave programmer checksum: 0x30A5A13F
Slave: Configuration succeeded -- 1 device(s) configured
Slave: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

燒錄原始 log：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260816/program_master.log
SHA256=15c0554f1b0921fd4998d1ef461cd38a5e5aa423a6a6bf4991fe8debe95a1165
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260816/program_slave.log
SHA256=2ab4704fb2c7f33db42e31c52abdb4b76cc8f2b4a1d6d6611c9a12319a9b2fa1
```

## JTAG/runtime 原始結果

使用同一 JTAG session，每秒取樣一次，共 60 個樣本。pain terminal 完成訊息：

```text
JTAG_RC=0
SESSION_TIME_SERIES_DONE
Info (23030): Evaluation of Tcl script scripts/jtag/read_wb_timeseries_session.tcl was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

原始 runtime log：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-CLOCK-ACTIVITY-20260816/runtime_60samples.log
SHA256=baef49d8ae49069a662ca9e6fa0c0b837269b166ea06d412bee35927c3cf0f82
```

取樣接受統計：Master `55/60`，Slave `60/60`。Master 前幾筆在燒錄後初始化期間被一致性規則排除；Slave 全部 60 筆有效。

時鐘活動 probe 的 Slave 讀值持續變化，例如：

```text
sample=46 ref=7358->48912 dmtd=630->42168 rx=14779->56334
sample=47 ref=15031->57184 dmtd=8256->50394 rx=22453->64607
```

Slave 的 WR/SoftPLL 狀態仍為：

```text
link_up=1
wr_mode=3
spll_locked=0
time_valid=0
REF_COUNT=00000000
TAG_COUNT=00000000
VISIT_MASK=00000200
TRANSITIONS=00000000
LAST_STATE=00000009
TRR_CSR=00020100
```

`VISIT_MASK=0x200` 與 `LAST_STATE=9` 對應 `SEQ_CLEAR_DACS`；`TRR_CSR=0x20100` 的 empty bit 只表示該次讀取當下 FIFO 為 empty。Master 仍可觀察到 `status_low=0xFF`、`time_valid=1`、`pps_valid=1`。

## Observation

1. `QSFPA_REFCLK_p`、`QSFPB_REFCLK_p` 與 `wr_rx_clk` 都有持續跳變，沒有證據顯示這三個 clock domain 停止。
2. Slave 的 PHY/WR link、CPU runtime、PTP packet path 仍然活著；目前沒有回到 CPU boot 或 gross PHY link failure 的證據。
3. Slave 的 reference/tag activity shadow、SoftPLL state transition 與 lock 狀態仍沒有增加；sequence 仍停在 `SEQ_CLEAR_DACS`。
4. clock activity counter 只能證明 clock 在跑，不能證明 DMTD tagger 已產生有效 tag，也不能證明 tag 已寫入 SoftPLL FIFO。

## Conclusion

目前證據支持的保守結論是：

> 三個主要時鐘域都在運作，因此「clock 完全停止」不是目前最可能的解釋。問題優先收斂到 recovered clock/tagger 的 edge 產生、tag FIFO 寫入，或 tag-to-SoftPLL/IRQ 路徑；但本次尚未觀測 raw tag strobe 或硬體 FIFO write event，所以尚不能宣稱根因已確定，也不能直接歸咎於特定光模組、光纖、PHY 參數或 SoftPLL gating。

compile 與燒錄成功只代表診斷 bitstream 已進入兩片 FPGA；Slave 仍未達到 `time_valid=1`，因此 WR 時間同步尚未完成。

## Next Step

1. 維持目前 PHY、PTP、servo、SoftPLL 控制與 SI5340 設定不變。
2. 下一個單一變因只加入 SoftPLL interrupt-entry 累計或 raw tag FIFO write/strobe 的唯讀診斷，以區分「tagger 沒有產生 tag」與「tag 有產生但 IRQ/FIFO 沒被消費」。
3. 先完成下一個診斷版本的 compile，再燒錄；燒錄後立即建立新的實驗紀錄，不能沿用本紀錄代替。
4. 在取得 raw tag/IRQ 證據前，不修改 pre-emphasis、QSFP port、polarity、PTP 演算法、servo threshold 或 SI5340 控制。

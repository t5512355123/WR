# EXP-WRPC-STEP4-DMTD-SAMPLER-RUN-LENGTH-AUDIT-20260826

## 稽核基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-DMTD-SAMPLER-RUN-LENGTH-AUDIT-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Source HEAD：`3a46b6d`
- Functional programmed image：前一輪由 `32feb04` 建置並燒錄的 image；目前 HEAD 的後續 commit 只有診斷/文件變更，沒有改變本輪使用的 functional sampler 設定
- 實驗類型：source-only；不編譯、不燒錄、不寫入 SoftPLL/threshold 設定

本輪依分支 2 的 `SOURCE_ONLY_DMTD_SAMPLER_RUN_LENGTH_AUDIT` 建議，追蹤：

```text
REF / FB clk_in
  -> g_divide_input_by_2
  -> g_reverse
  -> dmtd_sampler
  -> clk_sampled
  -> GOT_EDGE qualification
```

## 有效 generic 與時鐘接線

兩個 DE5a top 都只明確設定 `g_pcs_16bit => false`，沒有覆寫
`g_softpll_reverse_dmtds`。`xwr_core`/`wr_core` 的 default 與 generic map
因此得到：

```text
g_pcs_16bit             = false
g_softpll_reverse_dmtds = false
g_reverse_dmtds         = false
g_divide_input_by_2     = true
r_deglitch_threshold    = 1000
```

有效的 top-level clock map 為：

```text
u_xwr_core.clk_dmtd_i  => QSFPB_REFCLK_p  (nominal 124.992 MHz)
u_xwr_core.clk_ref_i   => QSFPA_REFCLK_p  (nominal 125 MHz)
wr_core.clk_ref_i(0)   => phy_rx_clk      (recovered REF clock)
wr_core.clk_fb(0)      <= clk_ref_i       (因此 FB = QSFPA_REFCLK_p)
```

REF 與 FB 的 DMTD instances 都把各自的 `clk_in_i`、相同的
`clk_dmtd_i`、`g_reverse_dmtds` 與 `g_divide_input_by_2` 傳給
`dmtd_with_deglitcher`；其中 `g_use_sampled_ref_clocks=false`，所以使用
內建 `dmtd_sampler`。

主要 source evidence：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:670-687`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:692-709`
- `vendor/wr-cores/modules/wrc_core/xwr_core.vhd:100-102,331-333`
- `vendor/wr-cores/modules/wrc_core/wr_core.vhd:657-684,717-720`
- `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd:591-617,658-674`
- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd:50-77,611-634`

## 頻率算術

本輪使用 top-level design intent 的 nominal input frequency；REF 是
transceiver recovered clock，沒有在上一輪 100×100 ms raw log 中讀取真正的
native REF/FB frequency counter。名義值為：

```text
f_REF  = 125,000,000 Hz
f_FB   = 125,000,000 Hz
f_DMTD = 124,992,000 Hz
```

`g_divide_input_by_2=true` 時，sampler 先在每一個 raw `clk_in_i` rising edge
翻轉 `clk_in`，所以送入 DMTD sampler 的有效頻率是：

```text
f_REF_post = f_REF / 2 = 62,500,000 Hz
f_FB_post  = f_FB  / 2 = 62,500,000 Hz
```

目前 straight/non-oversampled sampler 的 beat 關係不是
`|f_DMTD - f_post|`，而是 sampler 每次看到 post-divider clock 的相鄰半週期；
因此相對於兩個 post-divider half-cycles 的 phase slip 是：

```text
expected beat = |f_DMTD - 2*f_post|
              = |124,992,000 - 125,000,000|
              = 8,000 Hz
```

一個 post-divider HIGH 或 LOW 半週期為 8 ns，而一個 DMTD sampling cycle
約為 8.000512 ns，因此每一個 HIGH/LOW run nominally 只有約 1 個 DMTD
cycle。8 kHz 的慢速 phase slip 只會在邊界偶爾造成額外一個 sample，故理想
straight/div2 path 的預期 HIGH run 是：

```text
expected HIGH run cycles = 1 nominal; occasional 2 at a sampling boundary
```

這裡的 8 kHz 是相位滑移/邊界重複的慢速 beat，不代表 `clk_sampled` 會連續
保持 HIGH 約 7,812 個 DMTD cycles；在 div2 straight mode 下，正常樣本序列
主要是 HIGH/LOW 交替。

## REF / FB 對照表

| Path | `f_in` | `f_DMTD` | `divide_by_2` | `reverse` | expected beat | expected HIGH run cycles | measured HIGH max |
|---|---:|---:|---:|---:|---:|---:|---:|
| REF | 125.000 MHz (`phy_rx_clk`, nominal) | 124.992 MHz | true | false | 8 kHz | 1 nominal / occasional 2 | Master 9; Slave 2 |
| FB | 125.000 MHz (`QSFPA_REFCLK_p`, nominal) | 124.992 MHz | true | false | 8 kHz | 1 nominal / occasional 2 | Master 7; Slave 1 |

測得的 HIGH max 來自上一輪同一 functional image 的 read-only evidence：

```text
Master: DMTD_HIGH_QUAL_MAX_STAB REF/FB = 9/7
        DMTD_D0_LOW_RUN_MAX     REF/FB = 9/7
Slave : DMTD_HIGH_QUAL_MAX_STAB REF/FB = 2/1
        DMTD_D0_LOW_RUN_MAX     REF/FB = 2/1
Threshold = 1000
```

Slave 的 REF/FB=`2/1` 與 nominal div2 straight sampler 的 1–2 cycle 預期
相容。Master 的 REF/FB=`9/7` 超出 nominal arithmetic 可直接解釋的範圍，
表示 Master path 存在額外的 same-level run extension；但 source-only audit
無法在沒有 sampled waveform、native input frequency readback 或新 image
的情況下判定是實際時鐘偏差、時序/取樣邊界、硬體波形，還是其他 path-specific
因素。

上一輪 raw log 的 DMTD sampling-clock counter 提供的實測值是：

```text
Master f_DMTD = 124,991,458.635 Hz
Slave  f_DMTD = 124,990,672.677 Hz
```

這兩個值來自 `wr_softpll_ng.p_diag_dmtd_native_edge_count`，只量 `clk_dmtd_i`。
上一輪腳本中名為 `NATIVE_REF_SAMPLED`/`NATIVE_FB_SAMPLED` 的 0x234/0x238
讀值，source mapping 實際上是 `dbg_sampled_transition_count`，不是
`clk_in_i` native edge frequency counter；本紀錄不把那兩組 delta 當成
`f_REF`/`f_FB`。

## 與 GOT_EDGE failure 的關係

`dmtd_sampler` 的 straight/div2 path 在 `clk_dmtd_i` domain 以 `clk_i_d0`
取樣 post-divider `clk_in`，經過 `clk_i_d1` 的 inversion/enable 與 pipeline
後輸出 `clk_sampled_o`。`p_deglitch` 在 `GOT_EDGE` 中只有看到 LOW 才會把
`stab_cntr` 清零並記錄 high-qualification abort；要到 threshold=`1000`
才會產生 ACCEPT。

因此現有證據可窄化為：

```text
effective current mode = straight + input divide-by-2
nominal expected run   = 1, occasionally 2
Slave measured run     = compatible with nominal sampler arithmetic
Master measured run    = extended to 9/7, anomaly remains unexplained
threshold              = 1000
ACCEPT                 = 0 in the residency window
```

本結果不能把 Master 的 9/7 直接宣稱為 polarity、threshold、SoftPLL、PI、
DCO、SI5340、PHY 或 TRR/CPU 的根因，也不支持在未取得下一個 reviewer
決策前修改 functional RTL。

## 正式判定

```text
SOURCE_ONLY_DMTD_SAMPLER_RUN_LENGTH_AUDIT = COMPLETE
EFFECTIVE_REVERSE                         = false
EFFECTIVE_DIVIDE_INPUT_BY_2               = true
NOMINAL_EXPECTED_BEAT                     = 8 kHz
NOMINAL_EXPECTED_HIGH_RUN                 = 1, occasional 2
MASTER_HIGH_RUN                           = EXTENDED (9/7)
SLAVE_HIGH_RUN                            = COMPATIBLE (2/1)
ROOT_CAUSE                                = NOT_PROVEN
RTL_CHANGE                                = NONE
COMPILE_PROGRAM                           = SKIPPED
```

## 原始證據

```text
docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-GOT-EDGE-RESIDENCY-20260826/got_edge_residency_100x100.log
```

Raw log SHA256：

```text
A28E3A3BCA073FD9BDDE4BDE6BDC5E8AF920992B6D1854D08A6AD5013B95E579
```

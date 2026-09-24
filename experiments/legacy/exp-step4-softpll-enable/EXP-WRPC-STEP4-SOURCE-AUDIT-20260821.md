# EXP-WRPC-STEP4-SOURCE-AUDIT-20260821

## 審查範圍

- 日期：2026-08-21
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`9308ecef4687851337bac2533f2ba21f1e50e5b6`
- 審查類型：source-only、read-only
- FPGA program：未執行
- Quartus compile：未執行
- Wishbone control write：未執行

本紀錄只核對 focused JTAG 取樣所指出的 DMTD event generation boundary，不把歷史 SOF 或其他 operating point 的結果混入 current evidence。

## 目的

focused series 的 current 結果是：

```text
CURRENT_TICS              持續增加
DMTD REF/FB event         無 sustained delta
TAG pending/grant         無 sustained delta
TAG_VALID/TRR/IRQ         無 sustained delta
HELPER_UPDATE             無 sustained delta
```

因此本次 source audit 追蹤：

```text
top-level clock
  -> DMTD sampler
  -> clk_sampled
  -> deglitch FSM
  -> new_edge_p_dmtdclk
  -> CDC
  -> new_edge_p_sysclk
  -> tag_stb_p1_o
```

## Top-level clock、reset 與 PHY 接線

目前 Master/Slave top-level 的 source-backed 接線一致：

| 端點 | Master | Slave |
|---|---|---|
| `xwr_core.clk_sys_i` | `clk_sys_625` | `clk_sys_625` |
| `xwr_core.clk_dmtd_i` | `QSFPB_REFCLK_p` | `QSFPB_REFCLK_p` |
| `xwr_core.clk_ref_i` | `QSFPA_REFCLK_p` | `QSFPA_REFCLK_p` |
| `xwr_core.rst_n_i` | `wr_core_reset_n` | `wr_core_reset_n` |
| `wr_arria10_transceiver.g_use_simple_wa` | `true` | `true` |
| `wr_arria10_transceiver.clk_ref_i` | `QSFPA_REFCLK_p` | `QSFPA_REFCLK_p` |

source references：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:609-653`、`:670-712`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:632-676`、`:698-740`

top-level reset release 也維持已知 baseline 行為：`wr_core_reset_n` 在 `clk_sys_625` domain 中，只有 CPU reset 已解除、PLL lock、SI configuration 完成且延遲計數到達後才解除。這部分只讀取 source，沒有修改。

## wr_core 到 SoftPLL

`vendor/wr-cores/modules/wrc_core/wr_core.vhd` 的 source mapping 顯示：

```text
U_SOFTPLL.g_reverse_dmtds     => g_softpll_reverse_dmtds
U_SOFTPLL.g_divide_input_by_2 => not g_pcs_16bit and not g_softpll_reverse_dmtds
U_SOFTPLL.rst_dmtd_n_i        => rst_net_resync_dmtd_n
U_SOFTPLL.clk_ref_i(0)        => phy_rx_clk
U_SOFTPLL.clk_fb_i            => clk_fb
U_SOFTPLL.clk_dmtd_i          => clk_dmtd_i
```

目前 top-level `g_pcs_16bit=false`，而 current HEAD 沒有覆寫 `g_softpll_reverse_dmtds`，所以有效 source definition 是：

```text
g_softpll_reverse_dmtds = false
g_divide_input_by_2     = true
```

這些是目前 baseline 的 source facts，不是本輪要嘗試的變因。不能因為歷史 operating point 曾有不同結果，就在本輪直接切換。

## DMTD REF/FB instance

`vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd` 對兩類 DMTD 的接線如下：

### Reference DMTD

```text
DMTD_REF.clk_dmtd_i  => clk_dmtd_i
DMTD_REF.clk_sys_i   => clk_sys_i
DMTD_REF.clk_in_i    => clk_ref_i(i)
DMTD_REF.clk_sampled => clk_ref_sampled_i(i)
DMTD_REF.g_reverse   => g_reverse_dmtds
DMTD_REF.g_divide_input_by_2 => g_divide_input_by_2
```

### Feedback DMTD

```text
DMTD_FB.clk_dmtd_i   => clk_dmtd_i
DMTD_FB.clk_sys_i    => clk_sys_i
DMTD_FB.clk_in_i     => clk_fb_i(i)
DMTD_FB.g_reverse    => g_reverse_dmtds
DMTD_FB.g_divide_input_by_2 => g_divide_input_by_2
```

source references：

- `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd:436-472`
- `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd:474-514`

## deglitch 與 CDC 路徑

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd` 顯示：

1. `dmtd_sampler` 使用目前 generic 產生 `clk_sampled`。
2. `p_deglitch` 在 `clk_dmtd_i` domain 中運作。
3. FSM 依序使用 `WAIT_STABLE_0`、`WAIT_EDGE`、`GOT_EDGE`。
4. 在 `GOT_EDGE` 穩定時間達到 `r_deglitch_threshold_i` 時，產生 `new_edge_p_dmtdclk` 並 latch phase tag。
5. `gc_pulse_synchronizer2` 將 `new_edge_p_dmtdclk` 傳到 `new_edge_p_sysclk`。
6. `p_tag_output` 在 system clock domain 觀察同步後 pulse，輸出 `tag_stb_p1_o`。

source references：

- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd:216-236`
- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd:239-307`
- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd:404-421`
- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd:423-441`

這個 source chain 解釋了為何目前不能只由 `DMTD event=0` 直接宣稱原因是輸入 clock、deglitch threshold 或 CDC：現有 register 只看到了鏈路前後端的結果，還沒有把三層切開。

## 本輪判斷

目前最保守的結論：

```text
已證明：top-level source wiring 與 current generic 定義
已觀測：CURRENT_TICS 活動，但 DMTD event counters 無 sustained delta
尚未證明：clk_sampled 是否有 transition
尚未證明：deglitch FSM 是否接受 edge
尚未證明：CDC 是否成功送出 new_edge_p_sysclk
```

因此：

```text
STEP4 = NOT PASS
HARDWARE/FIRMWARE FAILURE = NOT PROVEN
JTAG/DASHBOARD MEASUREMENT FAILURE = NOT INDICATED IN THIS SERIES
NEXT = diagnostic-only observability design review
```

## Next Step 邊界

若要繼續，下一輪只能新增不回饋功能邏輯的觀測點，至少分開：

```text
raw sampler transition
deglitch accepted edge / new_edge_p_dmtdclk
post-CDC new_edge_p_sysclk
```

新增診斷觀測前必須先 commit/push，pain checkout exact commit，並在有 program 的情況下重新保存 MIF/SOF hash、Quartus version、programmer checksum、Step 1/2/3 regression 與 Step 4 raw log。未取得這些 evidence 前，不修改 `g_divide_input_by_2`、`g_softpll_reverse_dmtds`、deglitch threshold、PI、lock detector、DCO、SI5340、PTP、WR signaling 或 PHY。

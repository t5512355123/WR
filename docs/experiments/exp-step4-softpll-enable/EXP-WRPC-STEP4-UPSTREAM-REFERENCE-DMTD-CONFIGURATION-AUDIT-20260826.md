# EXP-WRPC-STEP4-UPSTREAM-REFERENCE-DMTD-CONFIGURATION-AUDIT-20260826

## 稽核基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-UPSTREAM-REFERENCE-DMTD-CONFIGURATION-AUDIT-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Source HEAD：`8593aa8`
- 實驗類型：source-only；不編譯、不燒錄、不修改 functional RTL

本輪依分支 2 的 `UPSTREAM_REFERENCE_DMTD_CONFIGURATION_AUDIT` 建議，將目前
DE5a 8-bit SoftPLL 路徑與 repository 內保留的 upstream/reference source
snapshot 比對，回答：

1. 正常 WR SoftPLL 是否使用 `g_divide_input_by_2=true`？
2. upstream 的 deglitch threshold 是否為 1000？
3. 是否存在 reverse、oversampling 或其他 clock arrangement，使 run length
   不應直接以目前的 nominal arithmetic 解讀？

## Source snapshot scope

本稽核使用 repository 內的 vendor snapshot，而不是把不同版本的 online
source 混在一起：

- `vendor/wr-cores`：原始 provenance 記錄的 upstream remote 為
  `https://gitlab.com/ohwr/project/wr-cores.git`，snapshot HEAD
  `0f8fbced87988254f5c9ca55c0e04585b29b485c`
- `vendor/wrpc-sw`：原始 provenance 記錄的 upstream remote 為
  `https://gitlab.com/ohwr/project/wrpc-sw.git`，snapshot HEAD
  `4528c0faa64138a6c97f15f7df373ff`

這是對目前 repository 所採用 dependency snapshot 的稽核；不宣稱它等同於
今日 upstream branch 的最新狀態。

## 目前 DE5a 的有效組態

兩個 DE5a top 都設定：

```text
g_pcs_16bit = false
g_softpll_reverse_dmtds = false   (由 xwr_core/wr_core default)
g_reverse_dmtds = false
g_divide_input_by_2 = true         (not false and not false)
g_use_sampled_ref_clocks = false
```

目前的 clock map 為：

```text
u_xwr_core.clk_dmtd_i => QSFPB_REFCLK_p  (nominal 124.992 MHz)
u_xwr_core.clk_ref_i  => QSFPA_REFCLK_p  (nominal 125 MHz)
wr_core.clk_ref_i(0)  => phy_rx_clk       (recovered REF clock)
wr_core.clk_fb(0)     <= clk_ref_i        (FB = QSFPA_REFCLK_p)
```

主要 evidence：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:670-687`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:693-710`
- `vendor/wr-cores/modules/wrc_core/xwr_core.vhd:100-102,331-333`
- `vendor/wr-cores/modules/wrc_core/wr_core.vhd:657-684,717-720`

## Upstream core-level reference comparison

`vendor/wr-cores/top/spec_1_1/wr_core_demo/spec_top.vhd` 的 reference design
使用：

```text
g_pcs_16bit    => false
g_softpll_reverse_dmtds 未覆寫
```

在相同的 `xwr_core`/`wr_core` wrapper 中，`wr_core.vhd` 對 SoftPLL 的 generic
map 是：

```text
g_reverse_dmtds     => g_softpll_reverse_dmtds
g_divide_input_by_2 => not g_pcs_16bit and not g_softpll_reverse_dmtds
```

因此 reference design 的 core-level effective setting 為：

```text
g_reverse_dmtds     = false
g_divide_input_by_2 = true
```

結論一：對 `xwr_core`/`wr_core` 內部 SoftPLL REF/FB DMTD path 而言，正常
8-bit WR reference 確實使用 divide-by-2；目前 DE5a 的有效設定與此一致。

## Threshold comparison

`vendor/wrpc-sw/softpll/softpll_ng.c` 在 `spll_init()` 會執行：

```c
#ifndef CONFIG_SPLL_DEGLITCH_THR
#define CONFIG_SPLL_DEGLITCH_THR 1000
#endif
SPLL->DEGLITCH_THR = CONFIG_SPLL_DEGLITCH_THR;
```

目前 DE5a firmware defconfig 選的是 `CONFIG_TARGET_GENERIC_PHY_8BIT`，沒有
提供 `CONFIG_SPLL_DEGLITCH_THR` board override，因此對目前這組 firmware
build input，threshold=1000 是 upstream software default。repository 內也可
看到 board-specific override，例如 `ertm14=700`、`wr2rf-vme=550`；所以
1000 是 generic default，不是所有 WR board 的 universal constant。

結論二：目前 DE5a 的 threshold=1000 有 source-level 依據，且與執行期讀值
一致；它不是由 `dmtd_with_deglitcher` generic hard-code，而是由 firmware
runtime write 到 `SPLL->DEGLITCH_THR`。

## Reverse / PHY-local sampler distinction

upstream snapshot 另有 Xilinx PHY-local sampler，例如：

```text
vendor/wr-cores/platform/xilinx/wr_gtp_phy/family7-gtx-lp/
  wr_gtx_phy_family7_lp.vhd:294-310
```

其中 `U_Sampler_RX` 與 `U_Sampler_TX` 明確使用：

```text
g_divide_input_by_2 => false
g_reverse           => true
```

這些 instance 的 `clk_in_i` 是 PHY 的 `rx_rec_clk`/`tx_out_clk`，輸出是
PHY-local `rx_rec_clk_sampled`/`tx_out_clk_sampled`，再由 PHY-local selector
產生 `clk_sampled_o`。它們不是 `wr_core.vhd` 內部 SoftPLL 對 REF/FB
`dmtd_with_deglitcher` 的同一個 instance；後者仍由 `wr_core` 的
`g_reverse_dmtds` 與 `g_divide_input_by_2` generic map 控制。

結論三：upstream 確實存在另一種 `reverse=true/divide=false` 的 PHY clock
arrangement，但不能把它直接解讀為目前 DE5a SoftPLL 內部 REF/FB path 應改成
reverse mode。它說明不同 PHY clock topology 可能採用不同 sampler mode，
而不是證明目前 core-level setting 錯誤。

## 對目前 run-length 結果的影響

目前 DE5a 使用的 core-level mode：

```text
reverse = false
divide_input_by_2 = true
threshold = 1000
```

因此上一輪用於推導 nominal HIGH run 的 straight/div2 arithmetic 仍是適用
的第一層模型；upstream source 沒有支持「目前應無條件改成 reverse=true」的
結論。Master 的 HIGH run 9/7 仍是 anomaly，不能只靠 upstream generic
comparison 消除，也不能據此直接修改功能組態。

目前 source-level verdict：

```text
UPSTREAM_CORE_REFERENCE_DIVIDE_BY_2 = true
UPSTREAM_CORE_REFERENCE_REVERSE     = false
CURRENT_DE5A_EFFECTIVE_DIVIDE       = true
CURRENT_DE5A_EFFECTIVE_REVERSE      = false
UPSTREAM_GENERIC_THRESHOLD          = 1000
CURRENT_DE5A_THRESHOLD_SOURCE       = firmware default 1000
PHY_LOCAL_ALTERNATIVE               = reverse=true, divide=false
CONFIGURATION_MISMATCH              = NOT_PROVEN
MASTER_RUN_LENGTH_ROOT_CAUSE        = NOT_PROVEN
RTL_CHANGE                          = NONE
COMPILE_PROGRAM                     = SKIPPED
```

## Evidence paths

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:670-687`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:693-710`
- `vendor/wr-cores/top/spec_1_1/wr_core_demo/spec_top.vhd:459-475`
- `vendor/wr-cores/modules/wrc_core/xwr_core.vhd:100-102,331-333`
- `vendor/wr-cores/modules/wrc_core/wr_core.vhd:657-684,717-720`
- `vendor/wr-cores/modules/wr_softpll_ng/xwr_softpll_ng.vhd:68-75,160-161`
- `vendor/wrpc-sw/softpll/softpll_ng.c:395-398`
- `firmware/configs/de5a_master_defconfig`
- `firmware/configs/de5a_slave_defconfig`
- `vendor/wr-cores/platform/xilinx/wr_gtp_phy/family7-gtx-lp/wr_gtx_phy_family7_lp.vhd:294-310`
- `provenance/vendor_git_state.md:6-17`

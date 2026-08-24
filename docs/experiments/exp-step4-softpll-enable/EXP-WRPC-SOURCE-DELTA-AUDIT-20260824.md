# EXP-WRPC-SOURCE-DELTA-AUDIT-20260824

## 審計範圍

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- 文件/dashboard HEAD：`92aa725`
- 目前 fresh hardware functional image：`7cda07f`
- 已知 Step 2/3 control：`7dd298bb`
- 已知 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 類型：source-only audit
- 是否 compile：否
- 是否 program：否

本審計因 Slave focused regression 仍未穩定通過而進行。目的只是找出 `7dd298bb -> 7cda07f` 的未隔離 source region，不在本輪修改 functional code，也不把任何差異直接宣稱為 root cause。

## 實際差異統計

使用：

```text
git diff --stat 7dd298bb..7cda07f -- \
  firmware quartus/jtag_runtime_diag vendor/wrpc-sw vendor/wr-cores scripts/build scripts/jtag
```

結果摘要：

```text
20 files changed
110 insertions(+)
178 deletions(-)
```

相對 `51864b874 -> 7cda07f`，同一範圍為：

```text
23 files changed
4019 insertions(+)
217 deletions(-)
```

這表示不能只用目前 `7cda07f` 的單一 reverse-DMTD 變因解釋整個 Slave regression。

## 差異分類

### A. 明確屬於 read-only diagnostics / Tcl

下列變更的設計目的主要是讀取與顯示，不直接寫入 Wishbone control register：

- `scripts/jtag/read_step23_register_reliability.tcl`
- `scripts/jtag/read_step4_event_chain.tcl`
- `scripts/jtag/read_step4_runtime_context.tcl`
- `scripts/jtag/read_step4_startup_focused.tcl`
- `scripts/jtag/read_wb_runtime.tcl`
- `scripts/jtag/read_wr_handshake_focused.tcl`
- `vendor/wrpc-sw/dev/wdiags.c` 的 TRR POP shadow export
- `vendor/wrpc-sw/include/dev/wdiags.h` 對應宣告
- `vendor/wrpc-sw/lib/task-diags.c` 的 shadow 更新

但 firmware diagnostics 仍會增加 CPU 執行路徑與 memory-mapped export，不能在沒有 A/B 的情況下假設完全不影響 timing 或排程；因此本類只代表「設計意圖為 observability」，不是已證明的零影響。

### B. 可能改變 netlist、CDC、routing 或 register mapping 的 diagnostics RTL

- `vendor/wr-cores/modules/timing/dmtd_phase_meas.vhd`
- `vendor/wr-cores/modules/timing/dmtd_sampler.vhd`
- `vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd`
- `vendor/wr-cores/modules/wr_softpll_ng/spll_wb_slave.vhd`
- `vendor/wr-cores/modules/wr_softpll_ng/spll_wb_slave.wb`
- `vendor/wr-cores/modules/wr_softpll_ng/spll_wbgen2_pkg.vhd`
- `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd`
- `vendor/wr-cores/modules/wrc_core/wrc_periph.vhd`

可觀察到的變更包含 debug port 移除/重接、Wishbone read alias 重新指向、以及新的 counter/export mapping。這些即使不改演算法，也可能改變 synthesis/fitter 的 fanout、placement、routing、CDC 或 firmware read-back 語意；目前應視為未隔離區域。

### C. Generated PHY wrapper 差異

- `vendor/wr-cores/platform/xilinx/wr_gtp_phy/kintex7-lp/wr_gtx_phy_kintex7_lp.vhd`

此檔案不是本 DE5a Arria 10 的主要編譯 target，但它仍屬 vendor generated source difference；本輪不將它當成 DE5a 根因，也不修改它。

### D. 目前沒有證據支持的 functional root cause

目前沒有 source-only 證據可以把下列任一項單獨定為根因：

- DMTD polarity
- SoftPLL 演算法
- PTP role / startup
- WR signaling 演算法
- PHY
- TRR POP counter
- 任一單一 JTAG register alias

`g_softpll_reverse_dmtds => true` 已在 `7cda07f` 被移除，但 fresh Step 2/3 沒有恢復，因此只能記錄為 `NOT SUFFICIENT`，不能記錄為 root cause。

## 與實機證據的對照

`7cda07f` fresh image：

- Master focused：20/20 valid，`MODE=2`、`PTP=6`，Step 2 PASS。
- Slave focused：accepted samples 反覆出現 `MODE=3`、`PTP=4`、Foreign=0/255、state idle，並有 invalid mailbox samples；Step 2/3 gate 未通過。
- 後續 dashboard/raw snapshot 曾讀到 Slave `PTP=8`、Foreign=1/0、parent flags=1、`WRS_S_LOCK`，但 RXERR delta=4，Step 2 仍為 invalid，且狀態隨時間變動。

這組結果同時支持兩件事：

1. dashboard/JTAG 確實存在 invalid/非 atomic snapshot 問題，不能把每筆 raw 值直接當成穩定狀態。
2. accepted samples 中仍有重複的 Slave PTP/Foreign/RXERR 異常，因此不能把全部現象簡化成 dashboard bug。

## 審計結論

```text
FIRST_UNCONTROLLED_SOURCE_REGION = 7dd298bb -> current diagnostics/SoftPLL mapping tree
SLAVE_REVERSE_DMTD_REMOVAL       = NOT SUFFICIENT
ROOT_CAUSE                       = NOT PROVEN
STEP2_REGRESSION                 = INVALID / RETEST
STEP3_REGRESSION                 = INVALID / RETEST
STEP4_ALLOWED                    = NO
```

本輪沒有進行 compile、program 或 functional modification。下一個硬體 recovery 實驗若要進行，應以 `7dd298bb` exact control tree 為基礎，只加入一個最小、單義的 TRR POP read-only export，並重新建立 fresh Step 2/3 gate；在 gate 通過前禁止解讀 Step 4。


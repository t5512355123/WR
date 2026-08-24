# EXP-WRPC-STEP4-DEGLITCH-STATE-20260824

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-DEGLITCH-STATE-20260824`
- 日期：2026-08-24
- Git branch：`exp/step4-control-recovery-fresh`
- Git commit：`91fbd52e228cdb36bca7d7ea1802e3808c44e92e`
- 實驗類型：JTAG / Wishbone read-only diagnostics
- Quartus compile：未執行
- FPGA program：未執行

本次只使用目前已燒錄的 control-recovery hardware image 做觀測；沒有重新產生或燒錄 SOF。最近一次 control recovery 所使用的硬體 provenance 保留在：

`EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824.md`

## 想驗證什麼

在不修改任何功能邏輯的前提下，將 Step 4 的來源鏈分成下列節點，確認第一個沒有可靠 activity 的邊界：

```text
clk_sampled transition
    -> deglitch qualification / accept
    -> post-deglitch DMTD event
    -> tag / TRR
    -> IRQ / helper update
```

同時確認 `SPLL_DMTD_STATE` 是否能觀察到 `WAIT_STABLE_0`、`WAIT_EDGE`、`GOT_EDGE`，而不是只依賴單一 summary register。

## 唯一修改

本輪沒有修改 FPGA RTL、firmware、MIF、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY。

唯一修改是加入兩個 read-only Tcl diagnostics commit：

1. `35e98b5`：新增 `scripts/jtag/read_step4_deglitch_state.tcl`。
2. `91fbd52`：補上 `SPLL_STATE` enum validation、16-bit deglitch threshold normalization，以及 counter decrease / measurement-quality 標記。

腳本只透過既有 Wishbone mailbox 發出 read command；不讀 `TRR_R0`，避免消費 tag FIFO，也不寫任何 Wishbone control register。

## Source-backed 觀測欄位

| 位址 | 欄位 | 用途 |
|---:|---|---|
| `0x001002DC` | `diag_dmtd_state` | REF/FB deglitch state、reset、qualification bucket、reached flag |
| `0x00100234/238` | sampled transition | `clk_sampled` transition counter |
| `0x0010022C/230` | accept counter | `new_edge_p_dmtdclk` accept counter |
| `0x00100298/29C` | DMTD event | post-deglitch system-side event counter |
| `0x00100284/288` | tag/TRR | tag-valid 與 TRR-write counter |
| `0x00100248` | deglitch threshold | source 只保證低 16 bit；讀值高 16 bit 為 undefined，不納入判定 |
| `0x0010023C` | high qualification max | REF/FB 最高 HIGH qualification depth |
| `0x0010025C` | D0 low run max | REF/FB `clk_i_d0` 最大 LOW run |

`SPLL_DMTD_STATE` 的 state encoding 依 `dmtd_with_deglitcher.vhd`：

```text
0 = WAIT_STABLE_0
1 = WAIT_EDGE
2 = GOT_EDGE
```

## 執行指令與工具結果

pain 先 checkout exact commit：

```text
git checkout --detach 91fbd52e228cdb36bca7d7ea1802e3808c44e92e
```

實際執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step4_deglitch_state.tcl \
  20 500 --raw
```

工具輸出：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
EXIT_CODE=0
```

Quartus 版本為 `17.0.0 Build 595`。本次沒有 compile、program 或 reboot。

## Raw evidence

第一輪 raw log：

`raw/EXP-WRPC-STEP4-DEGLITCH-STATE-20260824/deglitch_state_20x500_raw.log`

SHA256：`96AC7534B11CABFB26D44A4B5A58C99AD0A8A7BD145F1BF090076AABF2E07CCE`

修正 measurement validation 後第二輪 raw log：

`raw/EXP-WRPC-STEP4-DEGLITCH-STATE-20260824/deglitch_state_20x500_raw_v2.log`

SHA256：`40CF51684A3F87C2A3AF38939203AEAE014E06311D48D3BF339A8E952342FC5F`

## 觀測結果

### Master：`DE5 [1-11.1]`

```text
SAMPLED delta REF/FB = 1404507204 / 1405543058
ACCEPT  delta REF/FB = 0 / 0
EVENT   delta REF/FB = 0 / 0
TAG delta = 0
TRR delta = 0
IRQ delta = 0
HELPER_UPDATE delta = 0
REF state = GOT_EDGE 20/20 samples
FB  state = GOT_EDGE 20/20 samples
REF/FB reached = 20/20 samples
REF/FB reset = 0
```

第二輪 also 標記 sampled、accept、event、tag 等 counter 曾出現 decrease，代表至少部分跨 sample read 不能直接當成可靠 monotonic series。

### Slave：`DE5 [1-11.2]`

```text
SAMPLED delta REF/FB = 1415350559 / 1408737227
ACCEPT  delta REF/FB = 0 / 0
EVENT   delta REF/FB = 0 / 0
TAG delta = 0
TRR delta = 0
IRQ delta = 0
HELPER_UPDATE delta = 0
REF state = GOT_EDGE 20/20 samples
FB  state = GOT_EDGE 20/20 samples
REF/FB reached = 20/20 samples
REF/FB reset = 0
```

Slave 第二輪的 measurement-quality 標記為：

```text
accept_ref decreased = 2
accept_fb  decreased = 2
trr_write  decreased = 1
```

這些 decrease 不能直接解讀成硬體 counter reset 或功能錯誤；它們先被分類為 `MEASUREMENT_INVALID / RETEST` 候選，原因可能包含 mailbox tear、cross-register read 或 counter wrap/reset。

## 對 Step 1～Step 3 regression barrier 的影響

這次沒有重新 program，因此 Step 1～Step 3 使用 control recovery 實驗已保存的 fresh hardware 證據：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

其中 Step 2/3 的 60 秒後 focused repeated samples 已確認：

- Master `MODE=2`、`PTP=6`。
- Slave `MODE=3`、`PTP=9`。
- Slave `FOREIGN_META=03000001`。
- Slave `RX=0x1001 LOCK`、`TX=0x1000 SLAVE_PRESENT`。
- `LOCK_ENABLE=4`。

因此本次沒有觸發 regression barrier；仍只允許繼續 Step 4 的 read-only、single-variable 診斷。

## 結論

本次真正被證明的內容：

1. 新增 Tcl diagnostics 在 pain 上可完整執行，SignalTap/Tcl 回報 0 errors、0 warnings。
2. 兩片板的 `clk_sampled` transition counter 有大量 activity。
3. 在這個 read-only window 中，沒有取得可直接信任的 `accept`、post-deglitch event、tag/TRR、IRQ/helper sustained delta。
4. `SPLL_DMTD_STATE` 多數時間顯示 `GOT_EDGE` 且 reached=1，但沒有觀察到 `WAIT_EDGE`；這只能描述目前 synchronized shadow 的讀值，不能單獨證明每次 deglitch FSM transition。
5. 部分 counter 有 decrease，表示 JTAG measurement quality 仍需改善；不能把這次結果直接標示為 `HARDWARE/FIRMWARE FAILURE`。

目前分類：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4           = NOT_PASS / MEASUREMENT_QUALITY_REVIEW_REQUIRED
STEP4_ALLOWED   = YES
```

領先觀測邊界仍是：

```text
sampled transition -> deglitch accept
```

但由於 counter decrease，這個邊界目前只能稱為「重複觀測支持的 leading boundary」，不能稱為已證明的根因。

## 下一步

1. 保持目前硬體與 functional source 不變。
2. 先改善 read-only mailbox 的同一 register consistency check，或使用更窄的 focused register set，避免大量連續 read 造成 cross-register measurement tear。
3. 重新執行至少 20～30 個 sample，只有在 accepted sample 全部可靠後，才判斷 `sampled -> accept` 是否真的沒有 activity。
4. 不修改 deglitch threshold、DDMTD polarity、SoftPLL algorithm、PI、lock、DCO、SI5340 或 PHY。

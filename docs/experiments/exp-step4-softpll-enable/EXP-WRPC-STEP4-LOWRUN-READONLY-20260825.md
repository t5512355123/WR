# EXP-WRPC-STEP4-LOWRUN-READONLY-20260825

## 實驗名稱

Step 4 `WAIT_STABLE_0` 前級 low-run 與 deglitch threshold 唯讀回歸

## 實驗日期

2026-08-25

## Git 與變因

- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Tcl commit：`16c8682859d8e981fe938bbb5ad2aaab16f09fe6`
- 本次唯一變更：`scripts/jtag/read_step4_startup_focused.tcl`
- 變更內容：依 `spll_wb_slave.vhd` 的 source mapping，只保留 `0x00100248` 的低 16 位 threshold；新增既有 `clk_i_d0` low-run max 與 threshold 的 read-only 比較輸出。
- 未修改：RTL functional path、firmware、MIF、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY、Wishbone write 行為。
- 本次沒有 Quartus compile，也沒有 program FPGA。

## 為了驗證什麼

Reviewer 建議先確認是否已有「輸入端連續低電位長度」的 source-backed counter，再比較：

```text
sampler input activity
    ↓
existing clk_i_d0 low-run max
    ↓
source-defined deglitch threshold
    ↓
WAIT_EDGE_ENTRY
```

本次重用既有 `dbg_input_d0_low_run_max_o`，其 source 說明是 sampler 的 `clk_i_d0` domain，Wishbone 位址為 `0x0010025C`。它不是 `dmtd_with_deglitcher.vhd` 內部 `clk_sampled`/`stab_cntr` 的直接替代物，因此比較結果只能作為前級線索，不能直接宣稱 functional predicate 已通過。

`0x00100248` 在 `spll_wb_slave.vhd` 的 read mapping 只有 `rddata_reg(15 downto 0) <= spll_deglitch_thr_int`；高 16 位未定義。先前整個 32 位讀值的高半部會變動，造成 threshold 被誤判為 measurement invalid。本次 Tcl 將其正規化為低 16 位後再做 series delta。

## 執行設定

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl \
  30 200 events
```

- samples：30
- sample gap：200 ms
- 觀察時間：約 10 秒
- read retries：5
- read-only：是
- pain exact checkout：`16c8682859d8e981fe938bbb5ad2aaab16f09fe6`
- raw log：`raw/20260825_lowrun_audit/events.log`
- raw log SHA256：`286eca6180a6510233bd0404cc5d72b7cd108e6ffcd9f16bd7ecc4a81910f358`

## 原始結果摘要

Quartus 17 SignalTap/Tcl 正常完成：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

兩板均為 30/30 valid samples、0 timeout、0 invalid。source-defined threshold 讀值已穩定：

```text
DEGLITCH_THRESHOLD = 1000 (0x03E8)
threshold_delta     = 0
```

Master `DE5 [1-11.1]`：

```text
DMTD native sampled/transition activity : delta > 0
clk_i_d0 low-run max                    : REF=7, FB=7
low-run >= threshold                    : REF=0, FB=0
WAIT_EDGE_ENTRY                         : REF=0, FB=0
ACCEPT                                  : REF=0, FB=0
TAG/TRR/IRQ/helper/state transition     : all delta=0
```

Slave `DE5 [1-11.2]`：

```text
DMTD native sampled/transition activity : delta > 0
clk_i_d0 low-run max                    : REF=65535, FB=1
low-run >= threshold                    : REF=1, FB=0
WAIT_EDGE_ENTRY                         : REF=0, FB=0
ACCEPT                                  : REF=0, FB=0
TAG/TRR/IRQ/helper/state transition     : all delta=0
```

## 判讀

1. 這次證明 threshold 的前一次 measurement invalid 主要來自未定義高 16 位；正規化後 threshold 是穩定的 1000，該 dashboard 問題已修正。
2. Master 的 `clk_i_d0` 最大低-run 明顯小於 threshold，與 `WAIT_EDGE_ENTRY=0` 同方向，表示 sampler input 端沒有形成足以跨過門檻的長低-run；但這仍不是 `clk_sampled` 的直接證據。
3. Slave REF 的 `clk_i_d0` low-run max 為 65535，已大於 threshold，但 `WAIT_EDGE_ENTRY=0`。這個結果特別提醒我們：`clk_i_d0` low-run 與 deglitch FSM 使用的 `clk_sampled` 不是同一個 signal/domain，不能用它單獨推論 predicate 失敗位置。
4. 兩板 native sampled/transition activity 持續存在，但 accept 與 downstream event 都沒有活動；Step 4 仍未達成。
5. 根因仍不能寫成 threshold、polarity、clock quality、timing 或 FSM bug；目前保守結論仍是 `STATE_EVIDENCE=READ_INCONSISTENT`、`ROOT_CAUSE=NOT_PROVEN`。

## 回歸狀態

- `STEP1_REGRESSION = PASS`
- `STEP2_REGRESSION = PASS`
- `STEP3_REGRESSION = PASS`
- `STEP4_REGRESSION = NOT_PASS`
- `STEP4_ALLOWED = YES`
- `HARDWARE/FIRMWARE_FAILURE = NOT_PROVEN`
- `JTAG/DASHBOARD_MEASUREMENT_FAILURE = threshold upper-half interpretation fixed`

Step 2/3 的 PASS 沿用同一 fresh HEAD image 的 repeated accepted evidence；本次未燒錄，因此不能把本次 Tcl 變更描述成新的硬體 milestone。

## 下一步

下一步應直接針對 `dmtd_with_deglitcher.vhd` 內 functional `clk_sampled` 與 `stab_cntr` 的 read-only observability 做 source audit。現有 `clk_i_d0` low-run max 只能當前級線索，不新增重複 probe，也不修改 threshold、FSM、SoftPLL 或任何 functional algorithm。

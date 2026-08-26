# EXP-WRPC-STEP4-CORE-DMTD-DIV2-20260826

## 實驗身分

- 日期：2026-08-26
- Branch：`exp/step4-softpll-enable`
- Functional commit：`73d16414cf015f9411431ae7f5a862afb8454098`
- 實驗主機：`pain`
- Quartus：`17.0.0 Build 595`
- 實驗類型：單一 core-side DMTD clock A/B、fresh firmware build、Quartus clean compile、雙板 programming、Step 1/2/3 read-only regression barrier

## A/B 目的與唯一變更

前一輪 upstream/reference topology audit 顯示：upstream core-facing DMTD clock 約為 62.5 MHz，CLBv3 路徑則是 124.992 MHz 經 /2 後得到 62.496 MHz；目前 DE5a 直接把 124.992 MHz 接到 `xwr_core.clk_dmtd_i`。本輪只驗證這個 clock-topology hypothesis：

- A（既有 image）：`xwr_core.clk_dmtd_i = QSFPB_REFCLK_p`，約 124.992 MHz。
- B（本輪 image）：`QSFPB_REFCLK_p` 以一個頂層 FF toggle divider 降為約 62.496 MHz，再接到 `xwr_core.clk_dmtd_i`。

Master 與 Slave 的唯一 RTL 變更都是 `p_dmtd_core_div2` 及 `clk_dmtd_62m496`；SDC 保留 124.992 MHz 輸入 clock，並新增對 divider register 的 `create_generated_clock -divide_by 2`。以下均未修改：

- `g_softpll_reverse_dmtds=false`
- `g_divide_input_by_2=true`
- deglitch threshold `1000`
- PTP、WR signaling、SoftPLL FSM、PI/DCO、SI5340、PHY、firmware 與角色設定

## Build / programming provenance

| 項目 | Master | Slave |
|---|---|---|
| Project / top | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b` | same |
| MIF SHA256 | `861948c458411465ce84839871bbea3fa82539f87739f855b747363c57655f70` | `57ea898297d07297f80bb12aa5b1c501fabbf089878bce90c36492219d0dd4aa` |
| SOF SHA256 | `c68f9c47683d47746594792ab270df86c59ce8d248c9631b52a102712bfb3939` | `d03a01cdb2d4c3e831c1154d0d8da04c9cfe03881c0144c53da5bb6e1ef27536` |
| Compile / fitter | successful / successful | successful / successful |
| Timing closed | `NO` | `NO` |
| Worst setup slack | `-0.389 ns` | `-0.412 ns` |
| Worst hold slack | `0.039 ns` | `0.031 ns` |
| Programmer cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |
| Programmer checksum | `0x30B1722A` | `0x30B05EEB` |
| Programming result | configuration succeeded; 0 errors, 0 warnings | configuration succeeded; 0 errors, 0 warnings |

兩份 build 都包含 `Full Compilation was successful`，並且由同一個 functional commit `73d1641` 產生。Timing 的負 slack 是此專案既有狀態，本輪未以 timing closed 宣稱通過。

## Step 1/2/3 regression barrier

本輪執行的都是 read-only JTAG / Wishbone 讀取：

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 1000 25
quartus_stp -t scripts/jtag/read_step23_register_reliability.tcl 20 250 all
```

### Dashboard

兩張板的基本 PHY/link checks 均為 PASS；但完整 Step 2/3 gate 沒有成立：

- Master cable `DE5 [1-11.1]`：Step 1 PASS；MAC pair 被讀成 `...01/...02`、WDIAGS mode 為 `3 SLAVE`、PTP 讀值 `6 MASTER/9 SLAVE`，RXERR delta `3`，Step 2/3 為 NA。
- Slave cable `DE5 [1-11.2]`：Step 1 PASS；自身 MAC 為 `...02`、mode `3 SLAVE`、PTP `9 SLAVE`，PTP RX 在短窗無 delta；Step 3 的 parent/signaling/lock 欄位沒有通過。
- Dashboard summary：`STEP1_REGRESSION = PASS`、`STEP2_REGRESSION = INVALID`、`STEP3_REGRESSION = INVALID`、`STEP4_ALLOWED = NO`。
- Dashboard 的 `read_wb_runtime.tcl` 會自動列印 Step 4 欄位；因 regression barrier 已失敗，本紀錄不把那些欄位當成 Step 4 functional observation。

### Focused handshake（20 x 1 s）

```text
Master: valid_samples=14 invalid_samples=6 counter_decreased=0
        PTP_TX_DELTA=24 STEP2_REGRESSION=FAIL STEP3_REGRESSION=FAIL
        POST_STEP3_LOCK_STAGE=NOT_OBSERVED STATE_EVIDENCE=READ_INCONSISTENT

Slave : valid_samples=16 invalid_samples=4 counter_decreased=0
        PTP_TX_DELTA=36 STEP2_REGRESSION=FAIL STEP3_REGRESSION=FAIL
        POST_STEP3_LOCK_STAGE=NOT_OBSERVED STATE_EVIDENCE=READ_INCONSISTENT
```

Focused samples 出現 status-only / invalid mailbox words，且兩板都沒有取得 `signal_good` 或 `state_good`；因此不能以這組資料宣稱 Step 2/3 通過。

### Independent register reliability（20 samples）

- Master：各主要 mailbox 欄位大多為 20/20 valid，但 `STEP2_INDEPENDENT=FAIL`；Step 3 N/A。
- Slave：主要 endpoint/PTP/counter 欄位為 20/20 valid，但 `FOREIGN_META` 僅 14/20 valid，且 `MODE` 出現兩個值並有 decrease；`STEP2_INDEPENDENT=FAIL`、`STEP3_INDEPENDENT=INVALID`。
- Tcl evaluation 本身成功，0 errors、0 warnings；這只代表診斷腳本完成，不代表硬體 gate PASS。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = FAIL / INVALID
STEP3_REGRESSION = FAIL / INVALID
STEP4_ALLOWED     = NO
STEP4_RESULT      = NOT RUN; no functional interpretation permitted
AB_RESULT         = INCONCLUSIVE; regression barrier failed
```

本輪證明 B image 可以成功 compile、program，且 PHY/link 基本檢查仍可通過；但 Step 2/3 regression barrier 失敗，因此不能判定 62.496 MHz core-side DMTD 對 Step 4 是改善或退化，也沒有執行 Step 4 focused experiment。最直接的 runtime anomaly 是兩板在這個 image 下都呈現 `mode=3 SLAVE`，以及 Step 2/3 的 mailbox/status 欄位不一致；這些應交由下一輪建議決定，不能在本輪越過停損規則自行擴大變更。

## Raw evidence

完整 raw evidence 位於：

`raw/EXP-WRPC-STEP4-CORE-DMTD-DIV2-20260826/`

- `step1_dashboard.log`
- `step3_handshake.log`
- `step23_register_reliability.log`
- `functional_ab_master_build.log`、`functional_ab_slave_build.log`
- `quartus_jtag_master_compile.log`、`quartus_jtag_slave_compile.log`
- `functional_ab_master_program.log`、`functional_ab_slave_program.log`
- `build_info_jtag_master.txt`、`build_info_jtag_slave.txt`

另外將下載時發現的既有 `quartus_jtag_slave_page3_compile.log` 移到未納入提交的 `build/functional_ab_stale_slave_page3_compile.log` 保存；本報告不將它用作本輪 Slave provenance，本輪正式 Slave compile evidence 是 `quartus_jtag_slave_compile.log`。

## Next step constraint

依分支 2 對本 A/B 的停損規則，本輪到此停止，不讀取或分析 Step 4。下一步需先把這份 barrier failure record 推送，請分支 2 根據最新 GitHub 實驗紀錄決定後續方向。

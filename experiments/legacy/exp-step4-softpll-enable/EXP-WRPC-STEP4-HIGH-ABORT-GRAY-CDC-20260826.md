# EXP-WRPC-STEP4-HIGH-ABORT-GRAY-CDC-20260826

## 實驗基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-GRAY-CDC-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- FPGA/build commit：`8c5692cab6310eba3b2db9bcc336f09a47f63ca2`
- Quartus：17.0.0 Build 595
- 本輪目的：驗證 high-qualification abort counter 改用 Gray code 跨 `clk_dmtd_i` → `clk_sys_i` 後，fresh SOF 在兩張 DE5a 上的讀值是否與 `GOT_EDGE_ENTRY` 一致。

本輪只修改 read-only diagnostic counter 的 CDC 表示法；沒有修改 FSM、threshold、polarity、SoftPLL、PI、DCO、SI5340 或 PHY 功能行為。

## Source / Git 狀態

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd` 的 `dbg_high_qual_abort_count` 原先以 binary bus 直接進入 `gc_sync_register`。本輪改為在 DMTD domain 產生 Gray code，經兩級同步器後在 system domain decode 回 binary，並保留 32-bit modulo counter 行為。

本輪 GitHub push 已完成：

```text
8c5692c 診斷: 以Gray code同步高資格中止計數器
```

## Fresh build provenance

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| MIF SHA256 | `23c5e429018e6cad8271ab05475ce8afbc666a06b6d592ce26b0dceefa71fdac` | `7c398e331983c3dfe7788d4a52e70d9471619fceea0214f98df555aaefbb8161` |
| SOF SHA256 | `bb71b19c0a877c6c6dc6d19342d05c81cf4a1b1a7c81c8b3bf24dcbd29ecd44a` | `17f7b36e74d1a9b64468c4dc4914f55eff7b7258ddee70542a66e7a7ec1a426e` |
| Programmer checksum | `0x30B23B7C` | `0x30AFEC3D` |
| Quartus compile | Full Compilation successful | Full Compilation successful |
| Timing | `TIMING_CLOSED=NO`, worst setup `-0.157 ns` | `TIMING_CLOSED=NO`, worst setup `-0.237 ns` |

兩個建置均成功，但 timing 未 closed；這是工程風險，不能與 runtime Step4 結果混為一談。

## Programming evidence

- Master：cable `DE5 [1-11.1]`，`Configuration succeeded`，0 errors / 0 warnings，checksum `0x30B23B7C`。
- Slave：cable `DE5 [1-11.2]`，`Configuration succeeded`，0 errors / 0 warnings，checksum `0x30AFEC3D`。

因此本輪已建立 `8c5692c` → fresh build → fresh SOF → 兩板 programming 的 provenance。

## Step2 / Step3 barrier

`read_wr_handshake_focused.tcl 30 1000`：

```text
Master: valid=30 invalid=0 counter_decreased=0 PTP_TX_DELTA=174 STEP2=PASS STEP3=NA
Slave : valid=30 invalid=0 counter_decreased=0 PTP_TX_DELTA=24  STEP2=PASS STEP3=PASS
Slave : POST_STEP3_LOCK_STAGE=TIMEOUT STATE_EVIDENCE=READ_INCONSISTENT
```

Step2/3 barrier 允許繼續觀察 Step4；但 Slave 的 `TIMEOUT` / `READ_INCONSISTENT` 仍保留，不能解讀成已完成 WR lock。Handshake SignalTap 執行為 0 errors / 0 warnings。

## Step4 focused observation

命令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 20 500 all --raw
```

兩板均完成 20 個樣本、無 timeout/invalid，SignalTap 回傳 `STEP4_RC=0`，且 log 結束為 0 errors / 0 warnings。

### Master（DE5 [1-11.1]）

```text
DMTD native delta       = 1594192084, result=VALID
counter CDC              = GRAY2_HI_LO_HI
HIGH_QUAL_ABORT delta    = REF 720896056 / FB 720186826
GOT_EDGE_ENTRY delta     = REF 0 / FB 0
ACCEPT delta             = REF 0 / FB 0
EVENT_BOUNDARY           = QUALIFICATION_PROGRESS_TO_DEGLITCH_ACCEPT
LOW_QUAL_ABORT window    = REF 0 / FB 65270, result=VALID
```

另一次 boundary snapshot 顯示 `HIGH_QUAL_ABORT ref=791294563 fb=790528721`、`GOT_EDGE_ENTRY ref=0 fb=4256626402`、`ACCEPT=0/0`；這個 snapshot 與 20-sample series 不能組成一致的 live event chain。

### Slave（DE5 [1-11.2]）

```text
DMTD native delta       = 1632872395, result=VALID
counter CDC              = GRAY2_HI_LO_HI
HIGH_QUAL_ABORT delta    = REF 716743721 / FB 725435847
GOT_EDGE_ENTRY delta     = REF 0 / FB 33707467  (first DMTD group)
ACCEPT delta             = REF 0 / FB 0
EVENT_BOUNDARY           = QUALIFICATION_ABORT_AFTER_GOT_EDGE
LOW_QUAL_ABORT window    = REF 0 / FB 0, result=VALID
```

在後續 boundary series 中，Slave 的 `HIGH_QUAL_ABORT` 為 REF `805085277` / FB `814826668`，而 `GOT_EDGE_ENTRY delta=0/0`；因此這輪仍不能把 high-abort 增量解讀成對應的 GOT_EDGE event rate。

兩板 downstream 的 `TAG_VALID`、`TRR_WRITE`、`TRR_POP`、`IRQ`、`HELPER_UPDATE` 與 `STATE_TRANSITION` 在主要觀察窗口均沒有形成可用的 downstream event chain。`TRR_POP=0` 只能表示本輪沒有可觀察的上游 TRR pop，不能單獨證明 CPU 讀取失敗。

## 正式判定

```text
BUILD_MASTER       = PASS
BUILD_SLAVE        = PASS
PROGRAM_MASTER     = PASS
PROGRAM_SLAVE      = PASS
STEP2_REGRESSION   = PASS
STEP3_REGRESSION   = PASS with Slave TIMEOUT / READ_INCONSISTENT caveat
STEP4_ALLOWED      = YES
STEP4_RESULT       = NOT_PASS
GRAY_CDC_READBACK  = IMPROVED_ENCODING_OBSERVED, CONSISTENCY_NOT_PROVEN
ROOT_CAUSE         = NOT_PROVEN
TRR_CPU_READ       = NOT_RUNTIME_VERIFIED
```

本輪確認 fresh image 已包含 Gray CDC 修改，且 high-abort readback 顯示 `GRAY2_HI_LO_HI`；但 `GOT_EDGE_ENTRY`、`HIGH_QUAL_ABORT`、`ACCEPT` 仍未形成可相互驗證的事件鏈。因此不再自行修改 functional behavior，下一步交由分支2依這份 fresh experiment record 建議更窄的 atomic diagnostic 或 CDC/observability 實驗。

## 原始證據

raw logs 與 build provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT-GRAY-CDC-20260826/`

包含：

- `observation_meta.txt`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `program_jtag_master_8c5692c.log`
- `program_jtag_slave_8c5692c.log`
- `sof_sha256.txt`
- `step123_handshake.log`
- `step4_focused.log`

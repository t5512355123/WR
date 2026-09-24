# EXP-WRPC-STEP4-ATOMIC-GOT-EDGE-20260826

## 實驗基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-ATOMIC-GOT-EDGE-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- FPGA/build commit：`32feb04f190685a86b55d8b0b4344f94426f615e`
- Quartus build：17.0.0 Build 595
- Step4 Signal Tap：21.3.0 Build 170
- 本輪目的：以與 DMTD `WAIT_EDGE -> GOT_EDGE` 狀態轉移同一個 `clk_dmtd_i` 狀態機程序更新的 atomic counter，重新比較 `ATOMIC_GOT_EDGE_ENTRY`、`HIGH_QUAL_ABORT` 與 `ACCEPT`。

本輪只增加 read-only diagnostic counter、Gray CDC、Wishbone readback alias 與對應觀測標籤；沒有修改 FSM 功能路徑、threshold、polarity、SoftPLL、PI、DCO、SI5340 或 PHY 控制行為。

## Source / Git 狀態

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd` 新增 `dbg_atomic_got_edge_entry_count`：

1. 在 `p_deglitch` 的 `WAIT_EDGE -> GOT_EDGE` 同一條件下以 32-bit modulo counter 加一。
2. 在 DMTD domain 轉成 Gray code。
3. 經 system domain 兩級 synchronizer 後 decode 回 binary。
4. 由 `0x001002F0` / `0x001002F4` read-side aliases 讀回 reference / feedback 值。

功能輸出與既有診斷 counter 均未接回控制回授；外部 DMTD 的新輸出則明確開路。

GitHub push 已完成：

```text
32feb04 診斷: 新增原子GOT_EDGE進入計數器
```

## Fresh build / programming provenance

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| SOF SHA256 | `fdb5133980447baa6a14bb0892e3ebd1f2618d2bfd4e3cccd2b72c73675b8bd1` | `590313aa2c6679896b55c0fcc03050401b41f5c6602816f0887541a9cef6c5eb` |
| Programmer checksum | `0x30B34229` | `0x30B546A2` |
| Quartus compile | Full Compilation successful | Full Compilation successful |
| Timing | `TIMING_CLOSED=NO` | `TIMING_CLOSED=NO` |
| JTAG cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |
| Programming | Configuration succeeded; 0 errors / 0 warnings | Configuration succeeded; 0 errors / 0 warnings |

兩個建置與兩片燒錄均成功，但 timing 未 closed；這是工程風險，不能與 runtime Step4 結果混為一談。

## Step2 / Step3 barrier

第一次 20×500 ms gate 的 Slave 有一個 `signal_bad`，結果為 `STEP2=FAIL` / `STEP3=INVALID`；原始輸出保留於 `step123_handshake.log`。按相同參數重跑後，採用以下穩定窗口作為繼續觀測的 gate：

```text
Master: valid=20 invalid=0 counter_decreased=0 PTP_TX_DELTA=71 STEP2=PASS STEP3=NA
Slave : valid=20 invalid=0 counter_decreased=0 PTP_TX_DELTA=12 STEP2=PASS STEP3=PASS
Slave : POST_STEP3_LOCK_STAGE=TIMEOUT STATE_EVIDENCE=READ_INCONSISTENT
```

Handshake Signal Tap 執行成功，0 errors / 0 warnings。Slave 的 timeout / inconsistent 仍保留，不能解讀成已完成 WR lock。

## Step4 focused observation

命令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 20 500 all --raw
```

腳本完成 `STEP4_FOCUSED_DONE`，Signal Tap 回傳 0 errors / 0 warnings。新 atomic aliases 在兩板均可讀取，且 mapping group 各自 20 個樣本的 delta 均為 0。

### Master（DE5 [1-11.1]）

```text
DMTD native delta       = 1592250518, result=VALID
HIGH_QUAL_ABORT delta    = REF 791219484 / FB 789703953
ATOMIC_GOT_EDGE_ENTRY    = REF 0 / FB 0
NATIVE_REF/FB_ACCEPT     = REF 0 / FB 0
EVENT_BOUNDARY           = QUALIFICATION_PROGRESS_TO_DEGLITCH_ACCEPT
```

### Slave（DE5 [1-11.2]）

```text
DMTD native delta       = 1593627162, result=INVALID
HIGH_QUAL_ABORT delta    = REF 791978162 / FB 786675807
ATOMIC_GOT_EDGE_ENTRY    = REF 0 / FB 0
NATIVE_REF/FB_ACCEPT     = REF 0 / FB 0
EVENT_BOUNDARY           = QUALIFICATION_ABORT_AFTER_GOT_EDGE
```

Slave 的 DMTD measurement 因 threshold/native counter decrease 被標成 invalid；這不改變 atomic alias 在 boundary series 中讀值 valid 且 delta 為 0 的觀測結果。

## 正式判定

```text
BUILD_MASTER       = PASS
BUILD_SLAVE        = PASS
PROGRAM_MASTER     = PASS
PROGRAM_SLAVE      = PASS
STEP2_REGRESSION   = PASS on retry
STEP3_REGRESSION   = PASS on retry with Slave TIMEOUT / READ_INCONSISTENT caveat
STEP4_ALLOWED      = YES
STEP4_RESULT       = NOT_PASS
ATOMIC_READBACK    = VALID_READBACK, ZERO_DELTA_ON_BOTH_BOARDS
HIGH_ABORT_RESULT  = INCREMENTED_ON_BOTH_BOARDS
ROOT_CAUSE         = NOT_PROVEN
TRR_CPU_READ       = NOT_RUNTIME_VERIFIED
```

依分支 2 的判讀規則，本輪屬於 `atomic=0` 且 `high_abort>0`：HIGH_ABORT 的 observability / mapping 仍不能視為已證實的 live functional path。因此不修改 functional behavior，也不進入 threshold、SoftPLL 或 TRR/CPU 方向；下一步交由分支 2 依這份 fresh record 決定更窄的觀測實驗。

## 原始證據

raw logs 與 provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-ATOMIC-GOT-EDGE-20260826/`

包含：

- `build_provenance.txt`
- `git_commit.txt`
- `git_head.txt`
- `program_jtag_master_32feb04.log`
- `program_jtag_slave_32feb04.log`
- `sof_sha256.txt`
- `step123_handshake.log`
- `step123_handshake_retry.log`
- `step4_focused.log`

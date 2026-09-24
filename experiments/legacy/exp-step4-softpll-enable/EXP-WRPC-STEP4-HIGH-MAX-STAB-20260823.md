# EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823`
- 日期：2026-08-23
- 本機 branch：`exp/step4-softpll-enable`
- GitHub / pain exact HEAD：`8c3e0393b9950501a56eb11cb20ce8d6067c7ef0`
- 歷史 Step 3 參考 commit：`b7d262b5321d0d273c36b6aeb6a8fc57d76ea82e`
- 本輪目標：在不改變 White Rabbit 功能行為的前提下，觀測 DMTD `GOT_EDGE` 進入 HIGH qualification 後，在中止前實際走到的最大 `stab_cntr` 深度。

## 單一變因與禁止事項

本輪唯一變因是增加 read-only observability：把既有 DMTD stability readout `0x0010023C` 改為保存 REF/FB 的 `HIGH_QUAL_MAX_STAB`，表示 HIGH qualification 中止前觀測到的最大 stability depth。這個值只送到 JTAG/Wishbone read-only path，不回饋功能資料路徑。

本輪沒有修改：

- Master/Slave role switching、PTP algorithm、WR signaling algorithm
- SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold
- DCO、SI5340 control、PHY functional RTL、WRPC firmware functional behavior
- deglitch threshold、DMTD FSM、tag arbitration 或任何 Wishbone control register 行為

硬體在本輪重新由 exact HEAD 建置與燒錄；所有讀取均為 JTAG read-only，沒有寫入 runtime control register。

## 建置與燒錄

使用 pain 上的 Quartus 17 build wrapper：

```text
./scripts/pain/pain_build_jtag_master.sh
./scripts/pain/pain_build_jtag_slave.sh
./scripts/pain/pain_program_jtag_master.sh
./scripts/pain/pain_program_jtag_slave.sh
```

實際環境：

- Quartus Prime：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master / Slave 均先 `quartus_sh --clean`，再執行 full compile
- Master build：`Full Compilation was successful`，但 timing report 的 `timing_closed=NO`
- Slave build：`Full Compilation was successful`，但 timing report 的 `timing_closed=NO`
- Master programmer checksum：`0x309FC2A0`
- Slave programmer checksum：`0x30A7D749`
- Master / Slave：均為 `Configuration succeeded`、`0 errors`、`0 warnings`

### HEAD 到 SOF provenance

完整 hash 與建置識別保存於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823/provenance.txt`

重要 hash 如下：

| 物件 | SHA256 |
|---|---|
| Master QSF | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` |
| Master SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Master MIF | `cade94a3e6852f43fb3b696103d13e30ab5a873675c5c486a49629de376a9043` |
| Master SOF | `9b1e9fff75c330e70f3c2cbea012c3fe7527fd0dab749cc6b3a418d0f60c6691` |
| Slave QSF | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| Slave SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Slave MIF | `a254186fbe33e4c33115a6c4a669448fe56216b2b0bb2b59e56ceefd86a0205d` |
| Slave SOF | `a0851389cbf165659f4f23f56ca14b7811520b92fd57c62d66f1ac821f90d103` |

## JTAG regression 方法

Step 2/3 使用既有 focused script，沒有只依賴 dashboard：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 20 500

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 20 1000
```

Step 4 使用 10 samples、500 ms gap；T1 前等待 60 秒：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step4_startup_focused.tcl 10 500 all
```

## Step 1～Step 3 regression 結果

燒錄後很早的 20-sample window 中，Slave 仍在 startup transitional state，`PTP=8`，所以該早期 window 不作 Step 2 PASS 證據。等待後的 20 samples、1000 ms gap window 才作為本輪 final regression gate。

### Step 1：PHY / Link

- Master status probe：`0xFF`
- Slave status probe：`0xEF`
- 兩板 MAC、PHY ready、RX/TX ready、link evidence 正常
- `RXERR=0`

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

延遲窗口的 focused samples 為 20/20 valid：

- Master：`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`
- Slave：`MAC=02:00:22:33:44:02`、`MODE=3`、穩態 `PTP=9`
- Slave：`FOREIGN=1/0`、`wr_config=3`
- Master/Slave 的 PTP 與 MiniNIC counters 都有增加
- `RXERR=0`
- 最終窗口 `PTP_TX_DELTA`：Master `106`、Slave `11`

```text
STEP2_REGRESSION = PASS
```

### Step 3：WR Parent / Signaling

Slave final focused samples 中反覆觀測到：

- Foreign Master：`1/0`
- parent flags：`1/0/1`，即 parent is WR、parent mode/calibration source-backed evidence
- RX WR message：`0x1001`（LOCK）
- TX WR message：`0x1000`（SLAVE_PRESENT）
- `LOCK_ENABLE=4`
- RXERR=0

focused script 的 final gate 為 `STEP3_REGRESSION=PASS`。`STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT` 仍保留：20 個 sample 的 `local_state=0` 與 handshake counter/message evidence 不完全一致，不能把它省略，也不能只靠這個 shadow 宣稱硬體失敗。

```text
STEP3_REGRESSION = PASS
```

## Step 4 T0/T1 結果

raw log：

- T0：`raw/EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823/step4_t0_after_program.log`
- T1：`raw/EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823/step4_t1_delayed.log`

`HIGH_QUAL_MAX_STAB` 的輸出是 packed 32-bit word，高 16 bits 為 FB、低 16 bits 為 REF。

| Window | Board | REF max before abort | FB max before abort | sampled | accepted | downstream |
|---|---|---:|---:|---|---|---|
| T0 | Master | 0 | 3 | 有大量 delta | 0 | DMTD/tag/TRR/IRQ/helper 無 sustained delta |
| T0 | Slave | 0 | 1 | 有活動但曾出現 reset/wrap ambiguity | 0 | DMTD/tag/helper 無 sustained delta；TRR 僅有一次窗口活動 |
| T1 | Master | 0 | 5 | 有大量 delta | 0 | DMTD/tag/TRR/IRQ/helper 全為 0 delta |
| T1 | Slave | 0 | 1 | 有大量 delta | 0 | DMTD/tag/TRR/IRQ/helper 全為 0 delta |

其他重要 T1 evidence：

- Slave `RCER=1`
- Slave `SPLL_STATE=0x00030009`
- Slave `PSTAT.locked=0`
- Slave `WR_LOCK_ENABLE_COUNT=4`
- Slave `TRR_WRITE_COUNT`、tag、IRQ、helper update 在 T1 沒有 sustained activity
- Master `RCER=0`，也沒有 accepted DMTD event 或 downstream event

這個 read-only max-depth 觀測顯示，在本次 T0/T1 窗口中，REF/FB 的 HIGH qualification 中止前最大深度只有 0～5；但是它本身只是一個診斷量，不能單獨證明光路、時鐘、deglitch threshold 或任何功能根因。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = STATE_SHADOW_INCONSISTENCY_RETAINED
```

本輪真正被證明的是：fresh HEAD 的 Step 2/3 regression 可以在等待 startup 後重現；fresh HEAD 的 Step 4 SoftPLL startup 仍沒有形成「accepted DMTD edge → DMTD event → tag/TRR/IRQ/helper」的持續鏈路。T0 的單次 TRR activity 不足以改判 Step 4 PASS，因為 Step 4 gate 要求 sustained activity。

目前第一個有直接 read-only evidence 的 inactive boundary 仍是：

```text
DMTD sampled transition
  -> HIGH qualification / deglitch acceptance
  -> accepted DMTD edge = 0
```

這不是對 physical hardware root cause 的最終宣判；後續仍需依單一變因與 source-backed diagnostics 繼續縮小問題。未經下一個明確批准，不修改 SoftPLL、DDMTD、WR signaling、PI、lock threshold、DCO、SI5340 或 PHY functional behavior。

## 下一步

1. 保留 `8c3e039` 作為本輪可重現的 Step 2/3 regression 與 max-before-abort diagnostic baseline。
2. 由 White Rabbit 技術討論檢視本輪 fresh provenance 與 T0/T1 evidence，決定下一個唯一 read-only 變因。
3. Step 4 在 accepted DMTD/downstream sustained activity 出現前，不宣稱完成，也不進入 Step 5 closed-loop tuning。


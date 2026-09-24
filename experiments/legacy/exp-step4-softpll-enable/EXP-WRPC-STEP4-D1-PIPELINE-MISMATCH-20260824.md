# EXP-WRPC-STEP4-D1-PIPELINE-MISMATCH-20260824

## 實驗身分

- Experiment ID：`EXP-WRPC-STEP4-D1-PIPELINE-MISMATCH-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- Source commit：`c9f1f15005fa41b581736ec56c27e207178731ac`
- 實驗目的：驗證 straight、non-oversampled `dmtd_sampler` 內部的同步管線關係 `clk_i_d1[n] = not(clk_i_d0[n-1] and en_i_d0[n-1])` 是否持續成立。
- 單一操作變因：以 REF/FB 各一個 32-bit、飽和、唯讀的 `D1_PIPELINE_MISMATCH_COUNT` 取代上一輪會重複取樣非同步 `clk_in` 的 D0 shadow 診斷。沒有修改 White Rabbit signaling、PTP、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 WRPC firmware 功能行為。

## Fresh Build Provenance

| 項目 | Master | Slave |
|---|---|---|
| Git commit | `c9f1f15005fa41b581736ec56c27e207178731ac` | 同左 |
| Quartus | `17.0.0 Build 595` | 同左 |
| MIF SHA256 | `13f1dca14561ac118ab84a77c2f48bf433893911daf21e75b9e8b70dc7bdf260` | `172774ca0953de1485bfb41cc9d605651d6f300de37394b75320ded8850be3c7` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | 同左 |
| SOF SHA256 | `7a1ca58d525394a7a996247f27d8d851e307e8a3569054f13672ec4241860cef` | `29756c128e61acfbbaf2736a8a65d6058d771298167c20a58979ee60ff4a89f2` |
| Full Compilation | PASS | PASS |
| Timing closed | NO | NO |
| Worst setup slack | `-0.404 ns` | `-0.223 ns` |

## 燒錄結果

| 板卡 | Cable | Programmer checksum | 結果 |
|---|---|---|---|
| Master | `DE5 [1-11.1]` | `0x30AA777D` | Configuration succeeded，0 errors，0 warnings |
| Slave | `DE5 [1-11.2]` | `0x30ADDA10` | Configuration succeeded，0 errors，0 warnings |

## JTAG Runtime 原始結果

### Step 1～3 Regression

`read_wr_handshake_focused.tcl 30 500`：

| 板卡 | Valid / Invalid | Step 2 | Step 3 | PTP TX delta | 其他證據 |
|---|---:|---|---|---:|---|
| Master | `30 / 0` | PASS | N/A | `97` | `MAC=...:01`、`MODE=2`、`PTP=6`、RXERR 沒有增加 |
| Slave | `30 / 0` | PASS | PASS | `14` | `MAC=...:02`、`MODE=3`、`PTP=9`、foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4` |

Slave 的 `signal_good=30`、`signal_bad=0`；`local_state` 仍連續讀成 IDLE，與 LOCK/SLAVE_PRESENT/LOCK_ENABLE 證據互相衝突，因此依既有規則保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，不以單一 shadow state 否決 Step 3。

### Step 4 T0 / T1

兩個獨立視窗均使用 `read_step4_startup_focused.tcl 10 500 all`。每個關鍵欄位都是 `10/10 valid`、0 timeout。

| 板卡 | 視窗 | D1 mismatch REF/FB | sampled REF/FB delta | accept REF/FB delta | DMTD/tag/TRR/IRQ/helper delta |
|---|---|---|---|---|---|
| Master | T0 | `0 / 0` | `686,012,664 / 684,696,875` | `0 / 0` | 全部 `0` |
| Master | T1 | `0 / 0` | `685,734,485 / 684,445,230` | `0 / 0` | 全部 `0` |
| Slave | T0 | `0 / 0` | `684,243,051 / counter decreased` | `0 / 0` | 全部 `0` |
| Slave | T1 | `0 / 0` | `685,335,897 / counter decreased` | `0 / 0` | 全部 `0` |

Slave 同時維持 `SPLL_MODE=SLAVE`、`RCER=1`、sequencer=`SEQ_WAIT_CLEAR_DACS`，但 accepted DMTD、event、tag pending/grant/valid、TRR write、IRQ、state transition、helper update 均沒有 sustained activity。

Dashboard 顯示：

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4 SoftPLL Startup        error
Step 5 Closed-loop Lock       NA
Step 6 Global Time            NA
```

### Raw Evidence

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-D1-PIPELINE-MISMATCH-20260824/`

- `firmware_master_build.log` / `firmware_slave_build.log`
- `build_jtag_master.log` / `build_jtag_slave.log`
- `build_info_jtag_master.txt` / `build_info_jtag_slave.txt`
- `program_master.log` / `program_slave.log`
- `c9f1f15_step23_20260824.log`
- `c9f1f15_step3_focused_20260824.log`
- `c9f1f15_step4_t0_20260824.log`
- `c9f1f15_step4_t1_20260824.log`
- `dashboard.log`

## Observation

- Fresh `c9f1f15` 硬體再次重現 Step 1、Step 2、Step 3 PASS，Step 4 regression barrier 沒有退化。
- `D1_PIPELINE_MISMATCH_COUNT=0` 在兩片板、REF/FB、T0/T1 均成立，支持 source-defined D0/en→D1 同步管線關係沒有觀測到不一致。
- sampled transition 持續增加，表示 DMTD sampler 前段仍有活動；但 accepted DMTD 與後續 event chain 在兩個視窗都沒有 sustained delta。
- 因此目前可將第一個沒有持續活動的觀測邊界收斂到 deglitch acceptance；尚不能僅靠本輪資料判定是 deglitch 狀態機、輸入脈寬、clock-domain timing 或其他原因。
- Master/Slave 都沒有 timing closure，這是重要殘留風險，但本輪也沒有證明它就是 Step 4 根因。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
ROOT_CAUSE = NOT_PROVEN
```

## Next Step

請外部檢視最新 GitHub 實驗紀錄，決定下一個單一 read-only observability 變因。下一輪不得同時修改 deglitch threshold、DDMTD polarity、SoftPLL、DCO 或 SI5340 行為。

# EXP-WRPC-STEP4-WAIT-EDGE-ENTRY-20260824

## 實驗資訊

- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 診斷 source commit：`5dcc36190093369f36eee81207ae8e10399360ff`
- Functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- Quartus：17.0.0 Build 595 Standard Edition

## 驗證目的

確認 reference 與 feedback 的 DMTD deglitch FSM，是否曾完成 LOW qualification，並從 `WAIT_STABLE_0` 進入 `WAIT_EDGE`。這是 read-only observability 實驗，不改變 PTP、WR signaling、SoftPLL、DDMTD、DCO、SI5340 或 PHY 行為。

## 唯一修改變因

- 將 `0x00100260/0x00100264` 的唯讀診斷 alias，從上一輪 D1 pipeline mismatch 改為 REF/FB `WAIT_STABLE_0 -> WAIT_EDGE` 飽和計數器。
- 計數器只讀取既有 `state`、`stab_cntr` 與 `r_deglitch_threshold_i`，不驅動 functional path。
- 寫入側原有 `EIC_IDR/EIC_IER` 行為維持不變。

## Fresh Build Provenance

| Artifact | SHA256 |
|---|---|
| Master MIF | `06fabbdfbb69c14910c2d31b019daf89005045c99ed03010a3fe8f9471b31973` |
| Slave MIF | `bc7996532fe5a1872bb4264291c68b7c709726d919e63bc56d716bb4c8fe6af5` |
| Master QSF | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` |
| Slave QSF | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| Master/Slave SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Master SOF | `5590811cc1c2c94045789fe58f11568a433e9c7bd5bb76ca14e5cf26ad92dea0` |
| Slave SOF | `f72f1bd3374de8abddec122dad7c4de37aa64559296bf0b05f09c9dceb4aa24a` |

## 編譯結果

- Firmware build：PASS
- Master Quartus compile：PASS，`timing_closed=NO`
- Slave Quartus compile：PASS，`timing_closed=NO`
- Master 最差 setup/hold WNS：`-0.818 ns / -0.499 ns`
- Slave 最差 setup/hold WNS：`-0.606 ns / -0.465 ns`

時序未閉合是本實驗的重要限制。即使 runtime 計數器有活動，也不能把本次 image 宣稱為已完成 timing closure。

## 燒錄結果

- Master：2026/08/24 02:09～02:10，`DE5 [1-11.1]`，checksum `0x30A9E382`，configuration succeeded，0 errors / 0 warnings。
- Slave：2026/08/24 02:10，`DE5 [1-11.2]`，checksum `0x30AA1EE1`，configuration succeeded，0 errors / 0 warnings。
- 兩片板卡均燒錄本文件所列 fresh SOF，未使用歷史 SOF。

## JTAG 原始結果

### Step 1～3 regression barrier

`read_wr_handshake_focused.tcl 30 1000`：

| Gate | Master | Slave |
|---|---|---|
| 有效 samples | 30/30 | 30/30 |
| 無效 samples | 0 | 0 |
| Counter decrease | 0 | 0 |
| PTP TX delta | 168 | 42 |
| Step 2 | PASS | PASS |
| Step 3 | N/A | PASS |

Slave 保持 foreign=`1/0`、parent=`1/0/1`、RX=`LOCK 0x1001`、TX=`SLAVE_PRESENT 0x1000`、`LOCK_ENABLE=4`。`signal_good=28`、`signal_bad=2`，live WR state 與成功 signaling shadow 仍不一致，因此保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，不把它誤判為 Step 3 regression。

### Step 4 T0/T1

兩次 `read_step4_startup_focused.tcl 10 500 all` 均完整結束，0 errors / 0 warnings。

| Board | Window | REF sampled delta | FB sampled delta | REF WAIT_EDGE delta | FB WAIT_EDGE delta | REF/FB state | accept/event/tag/TRR/IRQ/helper |
|---|---:|---:|---:|---:|---:|---|---|
| Master | T0 | 685,609,189 | 686,226,664 | 0 | 0 | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |
| Master | T1 | 686,512,905 | 687,099,242 | 0 | 0 | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |
| Slave | T0 | 688,355,320 | 685,841,691 | 0 | 0 | `WAIT_STABLE_0/WAIT_STABLE_0` | 全部 delta=0 |
| Slave | T1 | 688,597,987 | 686,089,360 | 0 | 0 | `WAIT_STABLE_0/WAIT_STABLE_0` | 全部 delta=0 |

累計值不是零，表示啟動早期曾經通過這些節點；但 T0/T1 的 bounded window 都沒有持續增加：

- Master WAIT_EDGE REF/FB 累計：`0x02E3FCD8 / 0x024358EB`。
- Slave WAIT_EDGE REF/FB 累計：`0x1389385C / 0x12D47779`。
- Slave `RCER=1`、SoftPLL mode=`SLAVE`、sequence=`CLEAR_DACS`，但 accepted DMTD、event、tag/TRR、IRQ、state transition、helper update 都沒有 sustained delta。

Dashboard 再次確認兩板 Step 1/2 PASS、Slave Step 3 PASS、Slave Step 4 error；所有 Tcl 均成功結束，沒有 JTAG exception。

### Raw evidence

原始檔位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-WAIT-EDGE-ENTRY-20260824/`

- `provenance.txt`
- `firmware_build.log`
- `quartus_master_build.log`、`quartus_slave_build.log`
- `master_sta_summary.txt`、`slave_sta_summary.txt`
- `program_master.log`、`program_slave.log`
- `step23_focused_30x1s.log`
- `step4_t0_10x500ms.log`、`step4_t1_10x500ms.log`
- `dashboard.log`

## Observation

1. Current hardware 的 Step 1～3 regression barrier 再次通過，允許解讀 Step 4 observability。
2. Slave 在兩個視窗都固定於 `WAIT_STABLE_0`，同時 sampled transition 大量增加，但 `WAIT_EDGE_ENTRY` REF/FB delta 都是 0。因此目前 source-backed evidence 支持 Slave 沒有持續完成 LOW qualification。
3. Master 固定於 `GOT_EDGE`，所以不能把 Master 的 WAIT_EDGE delta=0 直接解讀成 LOW qualification failure；Master 的 stalled side 位於後續 HIGH qualification/accept 路徑。
4. 兩板的 WAIT_EDGE 與 accept 累計值均非零，支持這條路徑在啟動早期曾有活動；本實驗證明的是「目前沒有 sustained activity」，不是「從未工作」。
5. 此結果沒有證明 DDMTD polarity、clock quality、deglitch threshold 或任一 RTL assignment 是根因。時序未閉合也只列為 caveat，不能單獨歸因。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_FIRST_INACTIVE_BOUNDARY = WAIT_STABLE_0_LOW_QUALIFICATION
ROOT_CAUSE = NOT_PROVEN
JTAG_MEASUREMENT = VALID_FOR_KEY_SAMPLES
```

Step 4 尚未達成。這次實驗把 Slave 的第一個未持續活動節點收斂到 `WAIT_STABLE_0` 的 LOW qualification，但仍需下一個單一變因、source-backed read-only 實驗才能找出 qualification 為何無法完成。

## Next Step

將本次 exact commit、原始 log 與結論推送 GitHub，交由「分支 · White Rabbit 技術應用」檢視後，只依其建議增加下一個單一 read-only observability 變因。

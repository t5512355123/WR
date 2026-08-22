# EXP-WRPC-STEP4-DMTD-STABILITY-20260822

## 實驗資訊

- 實驗名稱：Step 4 DMTD 穩定門檻唯讀觀測版 fresh SOF 燒錄
- 日期：2026-08-22
- Git branch：`exp/step4-softpll-enable`
- Git HEAD：`0cc755bd53914e2a3d449c3c8643b1f95c05abd5`
- 目的：在不改變 White Rabbit functional behavior 的前提下，觀察 DMTD deglitcher 的穩定度 bucket 與 threshold sticky 狀態，定位 Step 4 的第一個無活動節點。

## 唯一變因

本次只加入 DMTD stability 的唯讀觀測扇出與 JTAG decode：

- `dmtd_with_deglitcher.vhd`：輸出穩定度 bucket 與 threshold-reached sticky 訊號。
- `wr_softpll_ng.vhd`：保存舊有 `SPLL_DMTD_STATE` 欄位，附加 stability bucket/sticky 欄位。
- `read_step4_startup_focused.tcl`：讀取並顯示新欄位。

本次沒有修改：Master/Slave role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY functional RTL 或 firmware functional behavior。沒有寫入 Wishbone control register。

## Fresh build provenance

建置來源是 exact HEAD `0cc755b`，不是 historical `c88cc05` SOF。

| 項目 | Master | Slave |
|---|---|---|
| Firmware MIF SHA256 | `c52b05da936871439793cc31f80e15772104d24be6020c68c4e7694f259f5535` | `1f6acd6c6faaa8e88344ae04df97a3e657fe10b9554d53dc2bf288851def406d` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF SHA256 | `ee50ebebb04a6066c39929b81927975cf2d5ee0d55a76704523ab0903cec7037` | `2a4700d8920d57105af23f89d7d5d8e1c9c4bd2a0d556e5d329af518388cc4f6` |

- Quartus：Quartus Prime Shell 17.0 Build 595 (04/25/2017 SJ Standard Edition)
- Build logs：
  - `raw/build_observability_0cc755b_master_20260822.log`
  - `raw/build_observability_0cc755b_slave_20260822.log`
  - `raw/build_info_observability_0cc755b_master_20260822_retry.txt`
  - `raw/build_info_observability_0cc755b_slave_20260822_retry.txt`

## 燒錄結果

### Master

- cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A95DC3`
- 結果：`Configuration succeeded`
- Quartus Programmer：0 errors, 0 warnings
- 原始紀錄：`raw/program_observability_0cc755b_master_20260822.log`

### Slave

- cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A3DC51`
- 結果：`Configuration succeeded`
- Quartus Programmer：0 errors, 0 warnings
- 原始紀錄：`raw/program_observability_0cc755b_slave_20260822.log`

以上只證明兩片 FPGA 接受了 exact HEAD 產生的 SOF；runtime gate 尚待下方唯讀回歸測試。

## Runtime regression

燒錄完成後，依序等待穩定時間並執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl 30 500 all
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl 30 500 events --raw
```

原始輸出將保存於：

- `raw/regression_step23_observability_0cc755b_20260822.log`
- `raw/regression_handshake_focused_0cc755b_20260822.log`
- `raw/regression_step4_stability_0cc755b_20260822.log`

### Step 1/2/3 focused evidence

- Step 1：兩片板的 link/runtime status 可讀，沒有本次 fresh SOF 導致的 link regression。
- Step 2：
  - Master：`STEP2_INDEPENDENT=PASS`，MAC `02:00:22:33:44:01`、MODE=2、PTP=6，PTP/MiniNIC counter 持續增加，RXERR=0。
  - Slave：`STEP2_INDEPENDENT=PASS`，MAC `02:00:22:33:44:02`、MODE=3、PTP=9，PTP/MiniNIC counter 持續增加，RXERR=0，`FOREIGN_META=03000001`。
- Step 3 focused：Slave 30 samples 全部 mailbox-valid；29/30 samples signal evidence 合格，`FOREIGN=1/0`、parent `1/0/1`、RX `0x1001 LOCK`、TX `0x1000 SLAVE_PRESENT`、`LOCK_ENABLE=4`。結果為 `STEP3_REGRESSION=PASS`，並同時標記 `POST_STEP3_LOCK_STAGE=TIMEOUT`、`STATE_EVIDENCE=READ_INCONSISTENT`；這不宣稱 live state 持續停留在 `WRS_S_LOCK`。
- Step 2/3 reliability script 的 Slave aggregate 將 Step 3 標示 `INVALID`，因為該腳本看到 `WDIAGS_TEMP=WRS_IDLE`；focused script 顯示 source-backed 的 handshake/lock-enable 證據成立，因此本紀錄採用 focused result，並保留兩者差異供後續修正判定。

### Step 4 fresh evidence

Slave 30 samples：

- `SPLL_MODE_SEQUENCE=0x00030009`，30/30 穩定。
- `RCER=1`、`OCER=1`，表示 SoftPLL channel 已 enable。
- `SPLL_DMTD_STATE=0x0C000002`，解碼為 `ref_state=2`、`fb_state=0`、ref/fb threshold sticky 都為 1，stability bucket 都為 0。
- `DMTD_REF_EVENTS`、`DMTD_FB_EVENTS`：`delta=0`。
- `TAG_PENDING`、`TAG_GRANT`、`TAG_VALID`、`TRR_WRITE`、`IRQ`、`STATE_TRANSITION`、`HELPER_UPDATE`：全部 `delta=0`。
- `DMTD_REF_SEEN`、`DMTD_FB_SEEN` 有變化；這些 packed/timestamp-like 欄位有 wrap/decrease，依腳本規則只作 activity/measurement-ambiguous evidence，不作單獨的成功判定。
- Step 4 boundary：`DMTD_DEGLITCH_ACCEPT`。

Master 30 samples：`RCER=0`、`OCER=1`，下游事件全部為 0；其 packed DMTD measurement 被標為 `DMTD_DEGLITCH_MEASUREMENT_AMBIGUOUS`，不把 Master-only measurement ambiguity 當成硬體 failure。

因此本次：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS (focused evidence; state readback inconsistent)
STEP4_RESULT = NOT_PASS
FIRST_OBSERVED_STEP4_BOUNDARY = DMTD_DEGLITCH_ACCEPT
```

這表示目前已觀察到 SoftPLL channel enable 與 deglitch stability sticky，但尚未觀察到 accept 後的 system event、tag、TRR、IRQ、sequencer 或 helper activity；不足以宣稱 Step 4 PASS。

## 結論

本次 fresh hardware evidence 支持：

1. exact `0cc755b` 已完成 Master/Slave fresh build。
2. 兩片 fresh SOF 都成功燒錄。
3. Step 2 focused regression PASS。
4. Step 3 focused regression PASS，但 current state readback 與 handshake history 不一致，需保留 `READ_INCONSISTENT` 標記。
5. Step 4 尚未通過；第一個觀察到的無下游 activity 邊界是 DMTD deglitch accept/output CDC 之間，不能再往 helper/DCO 推論。

目前最重要的區分是：這不是 `RCER=0` 的單純 SoftPLL disabled 證據；Slave 已有 `RCER=1`。同時也不能把 `DMTD_REF_SEEN/FB_SEEN` 的變化直接當成已完成 tag/servo path，因為後續 event counters 仍為 0。

## 下一步

先不修改 functional algorithm。下一個實驗只允許增加一個 read-only diagnostic variable：在 deglitch accept 與 system-domain event 之間，觀察既有 source-backed 的 CDC event pulse/同步後 sticky event；若 repository 沒有可直接觀測的 source-backed register，先做 source audit，不猜地址、不燒錄 functional change。Step 4 在新的 accepted-event evidence 以前維持 `NOT_PASS`。

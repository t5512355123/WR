# EXP-WRPC-CONTROL-RECOVERY-FRESH-20260824

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 fresh control recovery 與 Step 4 T0 唯讀觀測
- 日期：2026-08-24
- Git branch：`exp/step4-control-recovery-fresh`
- Git commit：`48ba8b1889ad1f0f69ade899fe241f0205f667d0`
- 控制來源：`exp/step4-post-div-edge-observability@48ba8b1`
- 實驗目的：確認控制來源在 fresh firmware、fresh Quartus build、fresh SOF 與雙板重新燒錄後，能否重新通過 Step 2 / Step 3 regression，並保存 Step 4 T0 的 read-only evidence。

本次沒有修改 Master / Slave role switching、PTP、WR signaling、SoftPLL、DDMTD、PI、lock threshold、DCO、SI5340 或 PHY functional behavior。控制來源沒有加入 `divide=false`；`wr_core.vhd` 保持 `g_divide_input_by_2 => not g_pcs_16bit and not g_softpll_reverse_dmtds`，且 reverse 設定維持 false。

## 建置與 provenance

- Quartus：17.0.0 Build 595 / Standard Edition
- Firmware MIF（Master）：`9c0dd19afc48fa0b0bc855e6c99df207f5a9fc779aeeb5da7b1fda42b10e6864`
- Firmware MIF（Slave）：`e507d1b031606d5f40fa667e9dd72891f443415d4c1c7774fa67e172fa7f8fb8`
- Master QSF：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF：`a28ad2cdbc206d77a64fc37856bf570e788c9745310ac5fe99a3d4e9dfa120d5`
- Slave SOF：`d4e718093be453f44c40b129e28b70ce7a1dc278eafc1247c047bc80f708dbb4`
- Master programmer checksum：`0x30AA3EE5`
- Slave programmer checksum：`0x30B06A0E`
- Master / Slave Quartus build：Fitter 成功，`timing_closed=NO`

## 燒錄結果

Master 使用 `DE5 [1-11.1]`，Slave 使用 `DE5 [1-11.2]`。兩片均回報：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

燒錄後等待 30 秒，再執行 focused read-only regression；本次未寫入任何 Wishbone control register。

## Step 2 / Step 3 regression

使用：

```text
quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 30 500 25
```

### Master

- accepted samples：30/30
- invalid samples：0
- MAC：`02:00:22:33:44:01`
- MODE：`2`
- PTP：`6`
- PTP / MiniNIC counters：持續增加
- RXERR：`0`
- 結果：`STEP2_REGRESSION=PASS`

### Slave

- accepted samples：30/30
- invalid samples：0
- MAC：`02:00:22:33:44:02`
- MODE：`3`
- PTP：`9`
- FOREIGN：`1/0`
- parent flags：`parent=1/0/1`
- RX WR message：`0x1001 / LOCK`
- TX WR message：`0x1000 / SLAVE_PRESENT`
- LOCK：`1`
- LOCK enable：`4`
- RCER：`0x00000001`
- PTP / MiniNIC counters：持續增加
- RXERR：`0`
- 結果：`STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS`

所有 Slave sample 的 `local_state=0`（`WRS_IDLE`），因此腳本保留：

```text
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
```

這表示 current-state 欄位與 LOCK / SLAVE_PRESENT / LOCK_ENABLE 的長時間 evidence 不一致；本次不把單一 state 欄位直接提升成 Step 3 hardware failure。

## Step 4 T0 read-only observation

使用：

```text
quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl 10 500 events
```

### 觀測到的活動

- Master / Slave `DMTD_NATIVE_EDGE_COUNT64` 持續增加。
- Master / Slave raw REF/FB edge 與 post-divider edge 持續增加。
- Master / Slave sampled / D0 transition counter 有活動。
- Slave `RCER=0x00000001`；Master 此 snapshot 為 `RCER=0`。

### 尚未觀測到的 Step 4 downstream activity

- `DMTD_REF_EVENTS` / `DMTD_FB_EVENTS` delta：`0`
- accepted counter delta：`0`（部分欄位同時出現 `DECREASED_OR_RESET` / CDC invalid indication）
- TAG pending / grant / valid：`0`
- TRR write：`0`
- IRQ：`0`
- helper update：`0`
- state transition：`0`

Tcl 最終輸出為 `STEP4_EVENT_ACTIVITY ... dmtd=0 pending=0 grant=0 tag_valid=0 trr_write=0 irq=0 state_transition=0 helper_update=0`。因此本次不能宣稱 SoftPLL 已完成 Step 4 startup gate。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED     = YES
STEP4_RESULT      = NOT_PASS
```

### Observation

fresh control SOF 可以重新建立 Endpoint / MiniNIC / PPSI / PTP packet path，也可以重新得到 Slave Foreign Master、WR message 與 LOCK enable evidence。這排除了「本次 fresh build 使 Step 2 / Step 3 必然失效」的說法。

Step 4 T0 顯示 DMTD raw edge 與 sampled path 正在活動，但從 sampled/D0 到 deglitch acceptance、TAG/TRR/IRQ/helper 的 downstream path 尚未有正增量。部分跨 clock domain counter 同時出現 `INVALID` 或 `DECREASED_OR_RESET`，所以目前證據同時包含功能上游停滯與觀測 CDC 不確定性，尚不足以單獨定義根因。

### 結論

這次 fresh/current hardware 的 Step 2 與 Step 3 regression 通過；Step 4 仍未通過。結論目前應區分為：

- Hardware / firmware：Step 4 downstream startup activity 尚未被證明。
- JTAG measurement：部分 accepted / sampled counter 存在 CDC invalid 或 reset/wrap 訊號，不能直接當作硬體失敗。

本次沒有修改 Step 4 functional algorithm，也沒有進入 Step 5 closed-loop lock 研究。

## 原始證據

- Programmer：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/master-program.log`
- Programmer：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/slave-program.log`
- Firmware build：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/master-firmware-build.log`
- Firmware build：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/slave-firmware-build.log`
- Master Quartus build：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/master-quartus-build.log`
- Slave Quartus build：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/slave-quartus-build.log`
- Step 2 / 3 focused regression：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/step23-30x500.log`
- Step 4 T0 focused observation：`raw/EXP-WRPC-CONTROL-RECOVERY-20260824/step4-t0-10x500.log`

## 下一步

保留本 control recovery 版本作為 fresh Step 2 / Step 3 reference。下一個 Step 4 實驗只能在這個 regression barrier 之上一次修改一個變因，並且需重新保存 exact commit、MIF/SOF hash、programmer log、Step 2/3 barrier 與 Step 4 T0/T1 evidence。

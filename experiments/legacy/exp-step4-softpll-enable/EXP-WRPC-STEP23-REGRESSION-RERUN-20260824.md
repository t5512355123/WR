# EXP-WRPC-STEP23-REGRESSION-RERUN-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- 文件提交時 HEAD：`546f84435782774fbee1d1801285a28a23118b0d`
- 唯讀診斷 Tcl：`6ac8b869acf7fb6f54cd7b57565a988811ba474b`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- 實驗類型：Step 2 / Step 3 read-only regression
- 本輪沒有修改 RTL、firmware、MIF、SOF，也沒有 Quartus compile 或 FPGA programming。

## 目的

在允許進入 Step 4 functional experiment 前，重新以目前雙板硬體做可靠的
Step 1～Step 3 regression。這次使用既有 focused handshake script，不把單次
dashboard snapshot 當作唯一判定來源，並確認無效 mailbox 值與 counter 倒退沒有
混入判定。

## 測試命令

```text
cd /home/b10504072/04_WR
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
```

原始輸出：

`raw/EXP-WRPC-STEP4-REGRESSION-20260824/step123_rerun.log`

本次設定為 30 個 sample、sample 間隔 1000 ms。每一個 sample 都必須先通過
JTAG validity check；若 mailbox 回傳無效值，該 sample 不可進入 gate 判定。

## SOF provenance

本次只做 read-only 觀測。板上目前仍是先前由 source commit
`6a25705feb653e5e9fd108054fc8d95cacbaf2b0` clean build 後燒錄的 SOF：

- Master SOF SHA256：`de1568c50ea54381de6357e0afe5c006ee940cb68fe2396689e391ab90b5032d`
- Slave SOF SHA256：`93a1ea028a3a8787238be93dbf2042bfa1bc4c95e939a5ca120a19250ac8a59a`
- Master programmer checksum：`0x30B32E2A`
- Slave programmer checksum：`0x30B41C87`

上述 SOF 並非本次文件 HEAD `546f844` 的 fresh build 產物；因此本紀錄是
目前已燒錄硬體的 read-only regression evidence，不宣稱完成 `546f844`
到新 SOF 的 provenance reproduction。

## Master 結果

30/30 samples 有效，0 個 invalid sample，0 個 counter decrease。

| 欄位 | 觀測結果 |
|---|---|
| MAC | `02:00:22:33:44:01` |
| WDIAGS_MODE | `2` |
| WDIAGS_PTP | `6` |
| PTP RX | `46971 -> 47043` |
| PTP TX | `106072 -> 106236`，delta `164` |
| MiniNIC TX | `134446 -> 134655` |
| MiniNIC RX | `70611 -> 70720` |
| RXERR | 全程 `0` |
| focused gate | `STEP2_REGRESSION=PASS` |

Master 的模式、PTP state、唯一 MAC、MiniNIC/PTP activity 與 RX error
均符合目前 regression gate。Master 不適用 Slave-side Step 3 gate。

## Slave 結果

30/30 samples 有效，0 個 invalid sample，0 個 counter decrease。

| 欄位 | 觀測結果 |
|---|---|
| MAC | `02:00:22:33:44:02` |
| WDIAGS_MODE | `3` |
| WDIAGS_PTP | 每個 sample 都是 `9` |
| PTP RX | `106231 -> 106396` |
| PTP TX | `14182 -> 14204`，delta `22` |
| MiniNIC TX | `75427 -> 75541` |
| MiniNIC RX | `129889 -> 130092` |
| RXERR | 全程 `0` |
| Foreign Master | `1/0`，foreign count `1`、best index `0` |
| Parent metadata | `parent=1/0/1` |
| WR RX message | `0x1001` LOCK |
| WR TX message | `0x1000` SLAVE_PRESENT |
| LOCK_ENABLE | `4` |
| focused gate | `STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS` |

focused script 同時報告 live WR state 為 `WRS_IDLE` 30/30，且 state evidence
為 `READ_INCONSISTENT`；其餘握手證據仍持續成立。因此不能把這個 shadow/state
欄位直接解讀成 Step 3 hardware failure，也不能把它當成 state 已經穩定進入
後續 lock stage 的證據。

## 觀察與判讀

- Master 與 Slave 的 mailbox sample 全部有效，沒有 `A5A5...` 類型 invalid
  read 混入判定。
- PTP TX 即使只有短窗口 delta `22` 或某個單一窗口為 `0`，也不能單獨使
  Step 2 FAIL；本次 PTP RX、MiniNIC TX/RX 與角色/identity 均有一致 activity。
- Slave 的 `WRS_IDLE` 與 `SLAVE_PRESENT`、`LOCK`、`LOCK_ENABLE=4` 的證據互相
  不完全一致，應保留為 read inconsistency，需更長 time-series 或 atomic
  snapshot 釐清，不能直接歸類為硬體/firmware failure。
- `POST_STEP3_LOCK_STAGE=TIMEOUT` 是 focused script 在 Step 3 gate 之後等待
  後續 lock stage 的結果，不是 Step 3 gate 本身失敗。

## Source audit 假設（尚未證明）

目前 source audit 發現 top 沒有覆寫 `g_softpll_reverse_dmtds`，因此有效值仍是
default `false`。在 `g_pcs_16bit=false` 時，`wr_core.vhd` 會使
`g_divide_input_by_2=true`；`dmtd_sampler.vhd` 因而先把 REF/FB input clock
除以 2，再由約 125 MHz 的 DMTD clock 取樣。

這與目前看到的 D0 transition 約 0.99、stable-hit=0、accept=0 相容，故是
目前最強的 functional root-cause hypothesis；但它仍只是 source-based
hypothesis，不是本次 regression 證明的根因。本輪不修改此設定。若未來獲准
做 A/B，必須另開單一變因、先 commit，再 fresh build/program 並立即建立燒錄
實驗紀錄。

## Regression barrier 結果

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE_FIRMWARE_FAILURE = NOT_ESTABLISHED
JTAG_DASHBOARD_MEASUREMENT_ANOMALY = Slave live state READ_INCONSISTENT
```

因此本輪沒有阻擋進入 Step 4 的 Step 2/3 regression failure；但 Step 4
本身仍未達成，`DMTD/deglitch accept` 與後續 event/tag/TRR/IRQ/helper
activity 尚未取得 PASS 證據。

## 下一步

先保留本輪 raw evidence，不改 functional behavior。下一個 Step 4 變因須等
確認並保存本輪 regression 後，另行決定是否做單一 `g_softpll_reverse_dmtds`
或等效 DMTD input divide A/B；在該變更獲准前，不進行任何 functional 修改、
compile、program 或 merge。

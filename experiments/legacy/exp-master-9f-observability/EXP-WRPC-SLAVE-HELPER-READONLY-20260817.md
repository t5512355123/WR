# EXP-WRPC-SLAVE-HELPER-READONLY-20260817

## 實驗名稱

已知成功 Master role 搭配 Slave SoftPLL helper 唯讀時間序列觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-HELPER-READONLY-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：唯讀 JTAG/runtime 觀測
- 本輪沒有重新 compile、沒有燒錄 FPGA、沒有寫入 WR 設定，也沒有寫入 `DATA_SNAPSHOT`。

## Git 來源與版本

- 研究分支：`exp/master-9f-observability`
- 本機記錄分支 HEAD：`b3c09a5`（記錄 Slave DCO 基線觀測結果）
- pain 執行腳本時 checkout：`bc5de194a811bbf27eafc804c3bb53afb61e119a`
- 已知成功 Master role 的歷史基線：`9f848ec`
- 這一輪只使用既有 `read_wb_timeseries_session.tcl`，沒有修改 Master role 或 Slave 控制參數。

## 想驗證什麼

延續已知成功的 Master role，確認 Slave 目前到底卡在：

1. PHY/link 或 PTP parent discovery；
2. SoftPLL helper 是否收到資料並進行 acquisition；
3. helper error 是否收斂到 lock detector threshold；或
4. Slave 是否已經 SoftPLL lock，只是尚未通過後續 `time_valid` 條件。

這一輪特別觀察 `WR_SPLL_HELPER_LOCKDET`、helper error/output、tag/ref/IRQ counters、`SSTAT`、`PSTAT`、parent metadata 與 `UCNT`。

## 相較 baseline 唯一修改

沒有修改硬體、韌體、PHY、PTP、PI gain、lock threshold、DCO controller 或 role 啟動流程。

唯一操作變因是：以既有 JTAG mailbox 連續讀取 60 列資料，每列間隔約 1 秒，並用 `CTRL_BEGIN/CTRL_END` 驗證 register frame 是否一致。

## Bitstream / firmware provenance

以下是本輪觀測時板上已存在的前一輪已燒錄映像；本輪沒有重新燒錄：

| 項目 | Master | Slave |
|---|---|---|
| SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` | `fd9db251d8c81b4ef65ffed547f52bed4ebeb5fe6946ee5aaae94dd7567f5dff` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Quartus | Quartus Prime 17.0 Build 595 | Quartus Prime 17.0 Build 595 |

SOF 的燒錄與 checksum 證據沿用：

- Master：`docs/experiments/EXP-WRPC-MASTER-DCO-HANDSHAKE-RESTORE-20260817.md`
- Slave：`docs/experiments/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817.md`

## 觀測指令與原始資料

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 3
```

腳本只使用既有的 JTAG source/probe 與 Wishbone mailbox read。原始 log：

```text
artifacts/EXP-WRPC-SLAVE-HELPER-READONLY-20260817/runtime_timeseries_60s.log
```

原始 log SHA-256：

```text
13D96A40829EA06640ACDE9102BC8B48A9D009B3AF25E391D09BAFE9E8A90E1C
```

DCO 唯讀重複觀測 log：

```text
artifacts/EXP-WRPC-SLAVE-HELPER-READONLY-20260817/dco_repeated_readonly.log
SHA-256: 97A27C3DC560ECF135673A09BE4043E5609D6BF8A229E024DDCEC60509F73208
```

## JTAG/runtime 原始結果

### Master

Master 60/60 列皆成功接受，代表性 frame：

```text
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_PTP_META: ...02010204
```

整個觀測窗中可見：

- `status_low=0xFF`
- `wr_mode=2`
- `time_valid=1`
- `pps_valid=1`
- `link_up=1`
- PTP RX/TX counters 持續活動

這與 `9f848ec` 的已知成功 Master role 一致，因此本輪不再修改 Master。

### Slave

Slave 60/60 列皆成功接受。代表性 frame：

```text
WDIAGS_SSTAT:00000001 WDIAGS_PSTAT:00000001 WDIAGS_PTP:00000009
WDIAGS_FOREIGN_META:03000001
WDIAGS_PARSE_META:05013749
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 servo_state=0 link_up=1 spll_locked=0
PARENT: foreign_count=1 foreign_best=0 detection=0 wr_config=3 is_wr=1 mode_on=0 calibrated=1
WR_LOCK: result=1 spll_locked=0 polls=883824 unlocked=883824 calibration_fail=0 enable=4 seq_state=4 align_state=0 mode=3 delock_count=0
WR_SPLL_LOCKDET: HELPER=00010000 LIMITS=271000C8 MAIN=00000000 FREQ_LIMITS=00320032 PHASE_LIMITS=03E804B0
WR_SPLL_ACTIVITY: REF_COUNT=0049E124 TAG_COUNT=00480FE1 HELPER_ERROR=FFFDB610 HELPER_OUTPUT=0000FFFB VISIT_MASK=00000618 TRANSITIONS=00000003 LAST_STATE=00000004 IRQ_COUNT=00984200 IRQ_MASK=010003E9 IRQ_STATUS=010003E8
```

觀測窗前後的 Slave raw counter 皆持續增加，例如：

```text
WR_SPLL_SOURCE_RAW: TAG_SOURCE_COUNT=06DEE265/06DEF4BE
WR_SPLL_SOURCE_RAW: TAG_SOURCE_COUNT=06E65F60/06E671AB
```

但 helper lock detector 的關鍵欄位沒有進展：

- `HELPER=0x00010000`：locked=0、lock_changed=0、lock counter=1
- `LIMITS=0x271000C8`：lock_samples=10000、threshold=200
- `HELPER_ERROR=0xFFFDB610`：signed value 約為 -150000，等於 helper error clamp
- `HELPER_OUTPUT=0x0000FFFB`：長時間停在下限附近
- `PSTAT.locked=0`、`spll_locked=0`
- `time_valid=0`

8 次 DCO probe 的代表值完全一致或呈現同一狀態：

```text
DCO_STATE A=0005000010008BA2 B=0005000010008BA2
```

依照 probe map，這代表 `rt_state=2、bus_state=0、bus_done=0、static_ready=1、hpll_pending=1、error=0、busy=1、completed_steps=0、last_hpll_data=0x0005`。DCO activity 的 `busy=1、error=0`，HPLL counter 會變化，但 completed step 仍為 0。這使「DCO transaction 長時間保持 busy、沒有完成」成為比「單純沒有 HPLL 輸入」更直接的觀測描述；仍不能單獨推出 I2C 線路或 register mapping 已經是根因。

## Observation

1. Master role 已穩定維持已知成功狀態；沒有證據支持再改 Master role。
2. Slave 的 PHY/link、PTP RX/TX、foreign master 與 parent metadata 都有活動；因此「Slave 完全沒有收到 Master」不是目前最符合證據的解釋。
3. Slave helper/SoftPLL 確實有 tag、reference、IRQ 與 Wishbone 診斷活動，但 error 固定在負向 clamp，lock counter 只維持 1，沒有累積到 10000 個低誤差樣本。
4. `SSTAT` 沒有進入 `TRACK_PHASE`；`PSTAT.locked=0` 且 `time_valid=0`。因此不能把目前狀態稱為完成同步。
5. DCO probe 顯示 transaction `busy=1` 長時間不回 idle，completed step 未增加；這是目前最值得先拆分的 Slave actuation evidence。
6. 本輪沒有改控制參數，故結果能直接作為目前 DCO handshake restore 版本的 read-only baseline。

## Conclusion

本實驗支持以下保守結論：

> Master 的 `9f848ec` role 與現行 observability 已經可重現；Slave 的主要阻塞點目前收斂在 SoftPLL helper acquisition/feedback 路徑。證據顯示 helper 有輸入與運算活動，但 error 長期飽和在 -150000，未達到 lock detector 的 ±200 threshold，因此尚未取得 SoftPLL lock，也尚未取得 `time_valid=1`。

本實驗**不能**單獨證明根因是 SI5340 I2C wiring、DCO register mapping、DCO handshake、DDMTD polarity，或 `time_valid` gating；這些仍需以單一變因實驗區分。

## Next Step

固定 Master：

```text
WDIAGS_MODE=2
WDIAGS_PTP=6
status=0xFF
```

下一輪只針對 Slave 做一個變因：保留現有 role/parent/PTP/PI/threshold，不改 Master，只針對 DCO actuation transaction 做更細的 read-only evidence，至少確認：

- DCO request 是否在每次 HPLL output 更新後被接受；
- DCO busy 是否會完成並回到 idle；
- completed step counter 是否增加；
- SI5340 controller 是否產生 error；
- helper error 是否仍固定在 clamp。

若下一輪需要重新燒錄，必須在燒錄完成後立即新增實驗紀錄，並記下 Git commit、MIF/SOF hash、Quartus version、programmer checksum、JTAG 原始輸出與 runtime 原始 log。

# EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-READONLY

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-READONLY-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`4efbb56`（唯讀觀測使用的 checkout）
- 實驗類型：JTAG 唯讀 runtime 觀測；沒有 compile，也沒有燒錄
- Quartus：17.0 Build 595
- 觀測程式：`scripts/jtag/read_wb_timeseries_session.tcl 60 1000 3`
- 遠端原始紀錄：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-SOURCE-AUDIT-20260818/runtime_lock_path_60s.log`
- 原始紀錄 SHA-256：`0561a45ec6fc3e6e987a422cecb27eace8f4f4dbe09058735b81234490afb376`

## 為了驗證什麼

本輪承接 `EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-SOURCE-AUDIT-20260818` 的 source audit，驗證實機是否真的從：

```text
Slave PTP / parent
    -> WR signaling
    -> locking_enable
    -> SoftPLL sequence / tagger
    -> TAG_VALID / TRR_WRITE / IRQ
```

逐步進展。

本輪特別觀察：

- `wrpc_wr_lock_enable_count`、poll、unlock、calibration fail。
- Slave parent flags、WR state 與 signaling。
- `SPLL` sequence state、`RCER`、`TAG_VALID`、`TRR_WRITE`、`IRQ`。
- `TAG_SOURCE_COUNT` 是否仍有原始來源活動。
- Master 是否維持歷史 baseline 的 role，不引入新的 role 切換方法。

## 相較 baseline 唯一修改了什麼

沒有修改任何 source、firmware、RTL、MIF、QSF、SDC、PHY、PTP 演算法或控制暫存器。本輪只有：

1. 從 GitHub checkout 明確的 `4efbb56`。
2. 使用現有兩片板的 JTAG 連線執行 60 秒、每秒一次的唯讀觀測。
3. 未寫入 `DATA_SNAPSHOT` 或其他功能控制值。

因此這不是新 bitstream 實驗，也不會改變目前硬體狀態。

## 燒錄與 bitstream provenance

本輪沒有燒錄。為了讓 runtime 結果仍可追溯，記錄觀測開始前板上的已知 bitstream：

### Master

- SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof`
- SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`
- MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- 前次燒錄 programmer checksum：`0x30A46449`
- Cable：`DE5 [1-11.1]`
- JTAG ID：`0x02E660DD`

### Slave

- SOF：本輪前一個 `移除 Slave 啟動時 SFP 比對` 實驗產物
- SOF SHA-256：`81d1f3444116a3aee4b5f31db0b0a83240fa9c422ece7e5f87f56f01572fbea2`
- MIF SHA-256：`7da77f8bbd47be594668055f2e398f0b3b72bba970d384729bda75a55d4dbe94`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- 前次燒錄 programmer checksum：`0x309FA629`
- Cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`

以上 provenance 是前次燒錄的證據；本輪本身沒有新的 programmer log。

## 原始 JTAG 結果

### Master：保留歷史 role，不重新設計

60 筆 sample 全部通過 session 的 accepted 判定。觀測到：

```text
wr_mode=2
time_valid=1
pps_valid=1
```

status 主要為 `0xFF`，部分 sample 為 `0xF3`。本輪讀到的 PTP counters 為：

```text
PTP_RX=0x00000064
PTP_TX=0x0000010D
```

兩個值在本輪 mailbox readout 中維持不變，因此這一輪只能確認 `MODE=2` 與有效時間旗標仍被讀到，不能單靠這份 log 宣稱 PTP RX/TX counter 在 60 秒內持續增加，也不能把完整歷史 `PTP=6` baseline 宣稱為本輪已重現。

### Slave：PTP 到 lock path

60 個目標 sample 中，58 個 accepted，2 個在三次 retry 後仍未 accepted。58 個有效 sample 的共同結果如下：

```text
wr_mode=3
time_valid=0
pps_valid=1
sstat_wr_valid=0
servo_state=0
spll_locked=0

WR_LOCK enable=0
WR_LOCK polls=0
WR_LOCK unlocked=0
WR_LOCK calibration_fail=0

RCER=0
TAG_VALID_COUNT=0
TRR_WRITE_COUNT=0
IRQ_COUNT=0
SSTAT=0
PTP_RX=0
PTP_TX=0
```

Slave 的 status/decode 在有效 sample 中主要是：

```text
status_low=EF，link_up=0 或 1
status_low=E3，link_up=0 或 1
```

parent 與 local WR fields 沒有形成有效 handoff：

```text
parent mode_on=0
parent_is_wr=0
parent_calibrated=0
parent_wr_config=0
state=0
next_state=0
```

`TAG_SOURCE_COUNT` 仍有變化，觀測摘錄為：

```text
開始：88632FE2/888B9DC6
結束：CC05B74E/CC2E4A2D
```

但 source counter 的活動不等同於有效 DDMTD tag；因為同時沒有 `RCER`、`TAG_VALID`、`TRR_WRITE` 或 `IRQ` 活動。

## Observation

1. Master 的 `MODE=2` 在本輪穩定，符合歷史成功 role 的要求；因此沒有理由創造新的 Master role switching 方法。
2. Master 的完整 `PTP=6` 與 counter 增長沒有在本輪重現，應保留為尚未完全重確認的事項，而不是把 `MODE=2` 過度解讀成完整 WR 成功。
3. Slave 的 raw tag source 仍活動，但有效 SoftPLL reference tagger 沒有被觀察到啟動。
4. 在 58 個有效 Slave sample 中，`WR_LOCK enable=0`、`SSTAT=0`、`RCER=0`、`TAG_VALID/TRR/IRQ=0` 全部同時成立。
5. 因此目前最有證據的邊界是 Slave 的 parent/WR signaling 到 `wrpc_spll_locking_enable()` 之前，或是該呼叫之後的 SoftPLL sequence/tagger enable；尚不能在這兩者之間做唯一判定。
6. 本輪沒有證據支持修改 Master、PHY、FINC/FDEC、PI、lock threshold 或 DDMTD polarity。

## Conclusion

本輪的證據支持以下保守結論：

> Master role 目前應固定在歷史 baseline 的 `WDIAGS_MODE=2` 路徑；Slave 的 raw source 有活動，但沒有進入可觀察的 WR parent/lock/valid-tag 路徑。問題尚未被證明是 `rts_lock_channel(0)` 本身，也尚未被證明是某一個單獨的 firmware function。

這次實驗不能宣稱：

- 兩片 DE5a 已完成 White Rabbit time synchronization。
- Master 的完整歷史 `WDIAGS_PTP=6` baseline 已在本輪重現。
- Slave 已收到並接受有效 WR parent。
- Slave SoftPLL 已 lock。

## Next Step

下一步仍先維持唯讀，不燒錄：

1. 將 `wrpc_wr_lock_enable_count`、parent flags、WR signaling、`SSTAT`、`RCER`、`TAG_VALID`、`TRR_WRITE`、`IRQ` 放在同一份 mailbox snapshot 中比對。
2. 若 `lock_enable_count` 始終為 0，優先查 Slave 是否進入 `WRS_PRESENT`、是否收到 WR `LOCK` signaling，以及 parent WR flags 的 mailbox mapping。
3. 若 `lock_enable_count` 增加但 `RCER` 仍長期為 0，才把範圍縮到 `spll_init()` 後的 helper sequence/tagger enable。
4. Master 只做既有 observability readback；不修改 role、startup command 或 PHY。
5. 只有唯讀證據無法區分時，才設計一個最小 firmware observability 變因；若需要 compile 或燒錄，必須建立新的 Experiment ID 並立即記錄完整 provenance。

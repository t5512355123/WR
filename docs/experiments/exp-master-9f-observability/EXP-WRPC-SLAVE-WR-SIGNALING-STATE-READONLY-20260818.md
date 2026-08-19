# EXP-WRPC-SLAVE-WR-SIGNALING-STATE-READONLY-20260818

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-WR-SIGNALING-STATE-READONLY-20260818`
- 日期：2026-08-18
- 實驗類型：雙板 JTAG 唯讀時間序列
- 本輪沒有 compile、沒有修改 source、沒有燒錄 FPGA。

## Git 與執行環境

- 本機研究 branch：`exp/master-9f-observability`
- 本機紀錄基準：`8b1f500`（已 push 至 GitHub）
- pain 實際執行 checkout：`4efbb5615d08c64a5988531ccc0f15b504f275cf`
- pain checkout 狀態：detached HEAD；既有未追蹤檔 `artifacts/build_info_jtag_slave.txt` 與 `quartus/jtag_runtime_diag/cr_ie_info.json` 保留，未加入或刪除。
- Quartus：Quartus Prime 17.0 Build 595
- 觀測程式：`scripts/jtag/read_wb_timeseries_session.tcl`
- 觀測內容：`WR_STATE_DEBUG`、`WR_RX_SIGNAL_DEBUG`、`WR_TX_SIGNAL_DEBUG`、handshake failure、parent metadata、WR lock、SoftPLL tag/TRR counters。
- JTAG 觀測為唯讀；沒有寫入 `DATA_SNAPSHOT` 或 WR 設定。

## 使用的既有硬體 provenance

本輪沒有產生新的 SOF；沿用前一輪雙板 baseline 已成功燒錄的 bitstream：

| 項目 | Master | Slave |
|---|---|---|
| role/source | `9f848ec` historical Master | `aa0825a` readback baseline |
| SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Programmer checksum | `0x30A46449` | `0x309FA629` |
| JTAG cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |

以上 bitstream 的燒錄證據保存在 `EXP-WRPC-BASELINE-DUAL-RESTART-20260818`；本實驗只重新讀取 runtime，不能把前一輪的燒錄再次算成本輪燒錄。

## 這次想驗證什麼

在不改 Master role 的前提下，定位 Slave 的 WR signaling 路徑停在哪裡：

```text
Master WR signaling
        -> Slave RX/parser
        -> WRS_PRESENT
        -> WRS_S_LOCK
        -> wrpc_spll_locking_enable()
        -> RCER / valid tag
```

特別要區分：

1. Slave 是否已找到 WR parent。
2. Slave 是否收到並接受 WR signaling。
3. Slave 是否進入 WR lock handoff。
4. SoftPLL reference tag 是否真的產生。

## 相較 baseline 唯一修改了什麼

沒有功能變因。只改變觀測方式：

- 第一次嘗試：`150 samples / 2000 ms / 3 retries`。
- 第二次正式觀測：`60 samples / 1000 ms / 3 retries`。

Master、Slave、MIF、SOF、PHY、PTP、SoftPLL、SI5340、FINC/FDEC、PI、threshold 與 DDMTD polarity 均沒有修改。

## 觀測一：150×2 秒嘗試（不完整）

- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-WR-SIGNALING-STATE-READONLY-20260818/runtime_150x2s.log`
- log SHA-256：`1ea9fb48434aa1138dde6ed474b35da0d1c8371aa49ace6a6b2f5b4545ca82a5`
- JTAG script：未取得完整雙板資料；timeout 前只完成 Master 約 143 個 sample，尚未進入完整 Slave 觀測。
- 結果：不把這份 log 當作完整雙板實驗結論，但保留作為觀測耗時與 timeout 證據。

## 觀測二：60×1 秒完整雙板結果

- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-WR-SIGNALING-STATE-READONLY-20260818/runtime_60x1s.log`
- log SHA-256：`129b4cab865e513a56ce034daa2e9c06f09c1a61d70ab7cb1cf4286cfea28956`
- Quartus/JTAG script exit code：`0`
- Master：60 rows、60 accepted、60 frame-valid。
- Slave：60 rows、56 accepted、56 frame-valid；4 rows 在 retry 上限後未接受，不把 rejected row 的跨欄位資料當成有效證據。

### Master 原始結果摘要

- `status_low=FF`：60/60 accepted rows。
- `time_valid=1`：60/60。
- `pps_valid=1`：60/60。
- `wr_mode=2`、`link_up=1`：60/60。
- `WDIAGS_PTP=6`：本輪 raw attempts 的有效觀測均維持該歷史 Master role 狀態。
- raw TAG/TRR counter 持續增加。

這支持 Master 仍維持歷史 `9f848ec` role；本輪沒有重新設計或切換 Master role。

### Slave 原始結果摘要

- `wr_mode=3`、`link_up=1`：60/60 rows。
- accepted rows 的 status 為 `EF` 或 `CF`；`time_valid=0`。
- `pps_valid=1` 出現在 `EF` rows，`CF` rows 則顯示 PPS valid 暫時為 0；不能宣稱 Slave PPS 已穩定。
- `WDIAGS_PTP=9`：對應 Slave PTP/WR role 的 runtime raw state。
- `PARENT` accepted rows 穩定呈現：
  - `foreign_count=1`
  - `foreign_best=0`
  - `parentWrConfig=3`
  - `is_wr=1`
  - `parent_calibrated=1`
- `WR_SIGNAL`：`rx_msg=0x0000`、`rx_count=0`；同時可見 `tx_msg=0x1000`、`tx_count=4`，另有 `fail_role=2`、`fail_state=1`、`fail_count=1`。
- `WR_LOCK`：`enable=0`、`polls=0`、`seq_state=0`；沒有有效的 lock handoff 證據。
- `WR_LOCAL` debug decode 顯示 `state=0`、`next_state=0`；目前不把這兩個值直接命名成 `WRS_PRESENT` 或 `WRS_S_LOCK`，因為其 register packing 與 WR state enum 仍需 source mapping 核對。
- raw `TAG_VALID_COUNT`、`TRR_WRITE_COUNT` 沒有形成增加事件；`TAG_SOURCE_COUNT` 只有少量活動。

## Observation

這次結果比上一輪更精確：

```text
Master role/time output                 已有穩定證據
Slave 找到 WR parent/parent flags       已有穩定證據
Slave 收到/接受 WR signaling RX         rx_count=0，尚無證據
Slave lock enable / polling              尚未啟動的證據
Slave valid tag/TRR                     尚無事件證據
```

因此目前不能再把問題優先描述成「Slave 完全找不到 parent」。較合理的下一個問題邊界是：

```text
Slave parent acquisition
        OK
        ↓
WR signaling RX/parser 或 handshake acceptance
        尚未證明
        ↓
WRS_PRESENT / WRS_S_LOCK / SoftPLL handoff
        尚未證明
```

但 `rx_count=0` 仍不能單獨證明光路完全沒有 signaling，因為該欄位的計數語意、`WR_STATE_DEBUG` 的 packing，以及 firmware shadow 更新時機都要與 source 對照。`PARENT is_wr=1` 也只能證明 parent flags/metadata 已被讀到，不能直接等同已進入 `WRS_S_LOCK`。

## Source audit：WR signaling mailbox 與 parser

本輪依照唯讀觀測結果核對下列來源，沒有修改 source、沒有重新編譯，也沒有燒錄：

- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-msg.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-present.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-idle.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-m-lock.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c`
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c`
- `vendor/wrpc-sw/ppsi/fsm.c`
- `vendor/wrpc-sw/lib/task-diags.c`

### 一般 signaling 計數與 WR signaling 計數不是同一件事

`wrc_ptp_ppsi.c` 在看到 PTP message type 為 signaling 時，會先增加一般 PTP signaling counter，之後才呼叫 `pp_state_machine()`。所以 `WDIAGS_PTP_META` 的 signaling 欄位有活動，只能表示符合 signaling message type 的封包抵達這個 PTP 接收路徑。

`wr-msg.c` 的 `msg_unpack_wrsig()` 則會在 WR 專用計數增加以前，依序檢查：

1. TLV type 是否為 `TLV_TYPE_ORG_EXTENSION`。
2. organization ID 是否為 `WR_TLV_ORGANIZATION_ID`。
3. magic number 是否為 `WR_TLV_MAGIC_NUMBER`。
4. WR version 是否為 `WR_TLV_WR_VERSION_NUMBER`。

只有四項都通過，才會讀取 message ID、增加 `wrpc_wr_rx_signaling_count`，並更新最後收到的 WR message ID。因此本輪「一般 PTP signaling 有活動、但 `WR_SIGNAL rx_count=0`」支持「封包已到 PTP 層，但尚未被 WR TLV parser 接受」；它不能單獨證明是哪一個欄位失敗，也不能把問題直接定義成光路中斷。

### Slave 握手目前缺少的訊息

`state-wr-present.c` 顯示 Slave 在 `WRS_PRESENT` 會送出 `SLAVE_PRESENT`，其值由 `wr-constants.h` 定義為 `0x1000`；它只有在 `msg_unpack_wrsig()` 成功且 message ID 是 `LOCK` 時，才會把下一狀態設為 `WRS_S_LOCK`。`state-wr-s-lock.c` 進入後才會呼叫 `locking_enable()`，並在 `locking_poll()` 回報 `WRH_SPLL_LOCKED` 時繼續前進。

因此本輪 Slave 的 `tx_msg=0x1000`、`tx_count=4` 與 `WR_LOCK enable=0/polls=0` 的組合，與「Slave 送出 PRESENT，但沒有接受到可用 LOCK、所以尚未進入 PLL locking handoff」一致。`fail_role=2` 對應 `WR_SLAVE`，`fail_state=1` 對應 `WRS_PRESENT`；這是 `wr_handshake_fail()` 儲存失敗前狀態的 source-backed 解碼。

### mailbox packing 與目前限制

`task-diags.c` 的現行 packing 為：

- `WR_STATE_DEBUG`：包含 local/parent WR flags、WR config、state/next state、parent detection 與 role。
- `WR_RX_SIGNAL_DEBUG`：高 16 位為最後成功解析的 WR message ID，低 16 位為成功解析計數。
- `WR_TX_SIGNAL_DEBUG`：高 16 位為最後送出的 WR message ID，低 16 位為送出計數。
- `WR_HANDSHAKE_FAIL_DEBUG`：高 8 位為失敗前 role，中間 8 位為失敗前 state，低 16 位為 handshake failure count。

這些欄位目前沒有提供「四個 WR TLV 檢查中是哪一個失敗」的 sticky reason。因此現有 mailbox 已足以把問題邊界縮到 signaling acceptance/handshake，但還不足以在不新增診斷欄位的情況下指出精確 reject reason。

另外，`fsm.c` 的一般 packet prefilter 會先檢查 domain、alternate-master、same-port 與其他 PTP 條件；本輪 `FILTER_META=0` 只表示目前有埋點的 generic prefilter reject counters 沒有增加，不能排除 WR 專用 TLV parser reject。`pp_prepare_pointers()` 與 `cmd_vlan.c` 也顯示 WRPC raw mode 的 offset 和 runtime `vlan off` 是獨立層次，下一輪必須核對實際 runtime protocol/offset 與 WR signaling buffer 位置，不能只由 `vlan off` 指令文字推論。

## Conclusion

> 本輪唯讀實驗沒有證明兩張 DE5a 已完成 White Rabbit 同步。它支持 Master `9f848ec` role 在本輪穩定，也支持 Slave 已看到並接受一筆 WR parent metadata；但 Slave 尚未顯示可採信的 WR signaling RX/handshake progression、SoftPLL lock enable、valid tag 或 `time_valid=1`。目前優先 blocker 應放在 Slave WR signaling state/parser/handshake 的 source 與 mailbox 語意，而不是先修改 Master role 或 SoftPLL 參數。

## Next Step

1. 下一輪先做 `EXP-WRPC-SLAVE-WR-SIGNALING-MAILBOX-SOURCE-AUDIT`：只核對 `SLAVE_PRESENT -> destination/identity -> Master filter/parser -> rx_count`，並確認 `WR_SIGNAL.rx_msg/rx_count/tx_msg/tx_count`、failure 欄位、local state、lock enable/polls 的確切更新條件；不改 firmware、不編譯、不燒錄。
2. 在這個 source audit 完成前，不改 Master、PHY、FINC/FDEC、PI、threshold、DDMTD polarity 或 SI5340，也不切換到另一份歷史 SOF。
3. 若 audit 確認是 WR TLV parser reject，下一個功能變因只能是增加 reject reason 的唯讀診斷，先定位四項檢查中的失敗點，再決定是否修正封包/offset；若只是 mailbox shadow 語意問題，先修正觀測解碼，不燒新的功能變體。
4. 任何後續 compile 若沒有燒錄，只記為 compile；任何後續燒錄都要立即建立新的繁中實驗紀錄，附 MIF/SOF/hash、Quartus/programmer 原始 log、JTAG runtime log 與證據限定的結論。

# 實驗：EXP-WRPC-WR-SIGNALING-MAILBOX-SOURCE-AUDIT-20260818

## 基本資訊

- Experiment ID：`EXP-WRPC-WR-SIGNALING-MAILBOX-SOURCE-AUDIT-20260818`
- 日期：2026-08-18
- 類型：唯讀 runtime 觀測與 source audit
- 本機 branch：`exp/master-9f-observability`
- 本機紀錄 commit：`6e98b93`（`記錄WR signaling唯讀觀測`）
- pain checkout：detached HEAD `6e98b93196a2b8d2dda87ac9914b1bc4da164869`
- Quartus：使用明確路徑 `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp`
- 編譯：沒有
- 燒錄：沒有

本輪沒有改變 FPGA image。現場使用的既有 image provenance 如下，僅作為 runtime 觀測的背景資料：

| 項目 | Master | Slave |
|---|---|---|
| role/source | `9f848ec` historical Master | `aa0825a` readback baseline |
| SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| programmer checksum | `0x30A46449` | `0x309FA629` |
| JTAG cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |

## 這次想驗證什麼

不改任何 runtime 行為，完成以下 source chain 的唯讀稽核：

```text
SLAVE_PRESENT
    -> destination / targetPortIdentity
    -> PTP signaling classification
    -> generic prefilter
    -> WR TLV parser
    -> wrpc_wr_rx_signaling_count
```

目標是區分「封包沒有到 PTP 層」與「已到 PTP 層但沒有通過 WR-specific parser」。

## 相較 baseline 唯一修改了什麼

沒有硬體或 firmware 變因。只新增一輪 30 samples、每 sample 1 秒、最多 3 retries 的唯讀觀測，並核對現有 source；不寫 JTAG control register、不改 startup command、不改 Master role、不改 PHY 或 servo/SoftPLL 參數。

## JTAG 實驗與原始證據

執行：

```text
cd /home/b10504072/04_WR
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_timeseries_session.tcl 30 1000 3
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-WR-SIGNALING-MAILBOX-SOURCE-AUDIT-20260818/runtime_30x1s.log
```

SHA-256：

```text
ec873775f5e73643cf038f81ed57ece058523123a31919c939da4939596fedc2
```

JTAG session 結束訊息：

```text
SESSION_TIME_SERIES_DONE
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

### Master

- 30/30 result rows accepted。
- `WDIAGS_PTP_META=02020406`，與目前 Master `MODE=2/PTP=6` runtime 相符。
- 本輪沒有改變或重新設計 Master role。

### Slave

- 30 result rows，其中 29 accepted；sample 015 在 3 retries 後為 `accepted=0`，不把該筆跨欄位 snapshot 當作有效資料。
- accepted rows 持續看到 `PARENT foreign_count=1/is_wr=1/parent_calibrated=1`。
- accepted rows 持續看到：

```text
WR_SIGNAL: rx_msg=0x0000 rx_count=0 tx_msg=0x1000 tx_count=4 fail_role=2 fail_state=1 fail_count=1
WR_LOCK: result=0 spll_locked=0 polls=0 calibration_fail=0 enable=0 seq_state=0
```

- `WDIAGS_PTP_META=03020409`，表示 Slave 的 PTP/WR role runtime 仍在運作，但不代表已完成 WR handshake。
- `time_valid` 仍為 0。

## Source audit 結果

核對的來源：

- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-msg.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-present.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-idle.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-m-lock.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c`
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c`
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c`
- `vendor/wrpc-sw/ppsi/time-wrpc/wrpc-socket.c`
- `vendor/wrpc-sw/ppsi/proto-standard/common-fun.c`
- `vendor/wrpc-sw/ppsi/fsm.c`
- `vendor/wrpc-sw/lib/task-diags.c`

### Destination 與 target identity

`wrpc_open_ch()` 建立 PTP raw socket 時使用 `PP_MCAST_MACADDRESS`；`wrpc_net_send()` 對一般 WR signaling 也使用 PTP multicast destination。`msg_pack_wrsig()` 的 payload targetPortIdentity 取自 `DSPAR(ppi)->parentPortIdentity`。

`msg_unpack_wrsig()` 會讀取 targetPortIdentity，但現行程式沒有用它做比對。因而目前沒有 source 證據支持「targetPortIdentity 不匹配就是這一輪的確定根因」。

### Parser 的確切 acceptance guard

`wr-msg.c` 只有在下列四項全部通過後，才會讀取 message ID、增加 `wrpc_wr_rx_signaling_count` 並更新最後收到的 WR message ID：

1. `TLV_TYPE_ORG_EXTENSION`
2. `WR_TLV_ORGANIZATION_ID`
3. `WR_TLV_MAGIC_NUMBER`
4. `WR_TLV_WR_VERSION_NUMBER`

所以目前「一般 PTP signaling counter 有活動、但 WR 專用 `rx_count=0`」只能支持：封包至少到達 PTP message-type 接收路徑，但沒有完成 WR-specific acceptance。它還不能指出四個 guard 中的哪一項失敗。

### Generic prefilter

`fsm.c` 的 generic prefilter 會檢查 domain、alternate master、same port、same clock 與 PTP state。這些欄位的埋點在本輪沒有增加；這降低了 generic prefilter reject 的優先度，但不能排除 WR TLV parser 的 early return。

### 握手狀態

- `wr-constants.h` 定義 `SLAVE_PRESENT=0x1000`、`WRS_PRESENT=1`、`WRS_S_LOCK=2`。
- `state-wr-present.c`：Slave 只有成功解析 `LOCK` 才會設定 `next_state=WRS_S_LOCK`。
- `state-wr-idle.c`：Master 只有成功解析 `SLAVE_PRESENT` 才會設定 `next_state=WRS_M_LOCK`。
- `state-wr-s-lock.c`：進入 Slave lock state 後才會呼叫 `locking_enable()`。
- `common-fun.c`：`wr_handshake_fail()` 儲存失敗前 state/role 後，清回 `WRS_IDLE` 與 non-WR。

因此 `tx_msg=0x1000`、Slave `rx_count=0`、`lock enable=0/polls=0` 與「Slave 曾送出 PRESENT，但沒有可採信的 LOCK acceptance」一致；這不是 SoftPLL 已經開始 lock 的證據。

## Observation

這一輪把問題邊界進一步縮到：

```text
PTP signaling message-type path     有活動
generic prefilter reject counters   沒有觀察到增加
WR TLV parser acceptance             尚未成功
Master WRS_M_LOCK / LOCK TX          尚無證據
Slave WRS_S_LOCK / PLL handoff       尚無證據
```

現有 mailbox 沒有提供四個 TLV guard 的 reject reason，因此單靠目前 `rx_count=0` 無法安全選擇 OUI、magic、version 或 offset 的功能修正。

## Conclusion

本實驗沒有證明兩張 DE5a 已完成 White Rabbit 同步，也沒有產生 compile 或燒錄成功證據。它支持：Master 歷史 role 仍穩定；Slave 已有 parent metadata 與 WR signaling TX activity；但 WR-specific signaling parser 尚未形成成功 RX count，握手也尚未進入可觀測的 Slave lock path。根因仍未被證明是 destination、TLV 欄位、buffer offset 或 role/state gate 中的哪一項。

## Next Step

下一個單一變因採用外部討論共識：只增加 `last_reject_reason` 與 `reject_count` 的唯讀 observability，不改任何 WR parser acceptance condition，不改 Master role、PHY、FINC/FDEC、PI、threshold、DDMTD polarity 或 SI5340。完成 compile 後先核對 MIF/hash；只有燒錄後，才建立新的燒錄實驗紀錄並以同一雙板 JTAG session 驗證 reject reason、Master LOCK TX、Slave LOCK RX、lock polling 與 `time_valid`。

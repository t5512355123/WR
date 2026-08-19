# EXP-WRPC-MASTER-9F-DIAGNOSTIC-BASELINE-20260818

## 基本資訊

- 實驗名稱：歷史成功 Master `9f848ec` 角色診斷基線
- Experiment ID：`EXP-WRPC-MASTER-9F-DIAGNOSTIC-BASELINE-20260818`
- 日期：2026-08-18
- 本機 branch：`exp/master-9f-observability`
- 本機 Git commit：`2f30166`
- pain checkout：detached HEAD `2f30166`
- Quartus：Quartus Prime 17.0 Build 595
- JTAG 工具：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp`

本輪只做既有 bitstream 的唯讀 JTAG 觀測，沒有修改 source、沒有重新編譯、沒有燒錄 FPGA，也沒有寫入 JTAG control register。

## 這次想驗證什麼

確認不重新發明 Master role 切換方法，直接沿用歷史上真正成功的 `9f848ec` Master baseline，並以最新 JTAG / clock / signaling observability 重新確認以下五項：

1. marker = `B004`
2. `WDIAGS_MODE = 2`
3. `WDIAGS_PTP = 6`
4. PTP RX/TX counter 持續活動
5. `link_up = 1`，且共同 status = `0xFF`

同一輪也觀察 Slave 是否已經從 `SLAVE_PRESENT` 進入 Master `LOCK` / Slave `S_LOCK`，以決定下一步是否仍應維持唯讀 source audit。

## 與 baseline 相較唯一改變

唯一改變是觀測方式：使用最新雙板 JTAG time-series script 進行 10 次、每次間隔 1 秒的唯讀取樣。沒有改變 Master role、startup command、PHY、PTP、servo、SoftPLL、FINC/FDEC、PI、threshold、DDMTD polarity 或 SI5340 設定。

## Image provenance

| 項目 | Master | Slave |
|---|---|---|
| 角色 / 來源 | 歷史成功 `9f848ec` | 最新 parser observability Slave image |
| SOF SHA-256 | `383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93` | `3862ffacab7b8d8629dbc8f9cbf8f1c32bbf3936b6ab649819d274f56f2c5fed` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `46ae80d66c95fbd9fb29e04c97515642fcd264c10427bc5fe6d9d65a385881c4` |
| 歷史 programmer checksum | `0x30A46449` | `0x309FA629` |
| JTAG cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |

本輪未重新燒錄，因此上述 checksum 是目前保存的 image provenance，不是本輪新的 programmer operation 結果。

## 實驗命令與原始證據

在 pain 執行：

```text
cd /home/b10504072/04_WR
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_timeseries_session.tcl 10 1000 3
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-DIAGNOSTIC-BASELINE-20260818/runtime_10x1s.log
```

原始 log SHA-256：

```text
b28a4c7b5200b8b400f6187914504052de57bf5b78d16fe453a750751836bcf6
```

JTAG 結束訊息：

```text
SESSION_TIME_SERIES_DONE
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

## 結果：Master

Master board `DE5 [1-11.1]` 的 10 個 sample 全部 `accepted=1`。

代表性原始讀值：

```text
WDIAGS_PTP_RX:00000139 WDIAGS_PTP_TX:00000AE4 WDIAGS_PTP_META:02020406
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 sstat_wr_valid=0 servo_state=0 link_up=1 spll_locked=0

WDIAGS_PTP_RX:0000013A WDIAGS_PTP_TX:00000B14 WDIAGS_PTP_META:02020406
DECODE: status_low=FF time_valid=1 pps_valid=1 wr_mode=2 sstat_wr_valid=0 servo_state=0 link_up=1 spll_locked=0

SESSION_SAMPLE_RESULT board=DE5 [1-11.1] sample=010 accepted=1 retries=1
```

判讀：

- `marker=B004`：通過
- `WDIAGS_MODE=2`：通過
- `WDIAGS_PTP=6`：通過
- `status_low=0xFF`：通過
- `time_valid=1`、`pps_valid=1`、`link_up=1`：通過
- PTP RX/TX 均為非零且跨 sample 有增加：通過

這些證據支持 Master 仍是歷史成功的 `9f848ec` role baseline。本輪不再修改 Master role。

## 結果：Slave

Slave board `DE5 [1-11.2]` 的大多數 sample accepted；少數 sample 在 retries 後未 accepted，未用那些不完整 snapshot 做跨欄位推論。

代表性原始讀值：

```text
WDIAGS_PTP_RX:000008E2 WDIAGS_PTP_TX:0000057E WDIAGS_PTP_META:03020409
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 sstat_wr_valid=1 servo_state=0 link_up=1 spll_locked=0

WDIAGS_SSTAT:00000001 WDIAGS_PSTAT:00000001 WDIAGS_PTP:00000009
WDIAGS_PTP_RX:00000915 WDIAGS_PTP_TX:000005A9 WDIAGS_PTP_META:03020409
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 sstat_wr_valid=1 servo_state=0 link_up=1 spll_locked=0
```

Slave 的 60 秒唯讀證據也顯示：

```text
FOREIGN_META=0x03000001
PARSE_META parent flags：parent_is_wr=1、parent_calibrated=1
UCNT：0x0000000F -> 0x0000001E
WR_SIGNAL：rx_msg=0x0000 rx_count=0 tx_msg=0x1000 tx_count=4
WR_LOCK：spll_locked=0 polls=0 enable=0
```

判讀：Slave 已看到 parent，PTP 與 servo 有活動，也送出 `SLAVE_PRESENT`；但沒有證據顯示 Master 已送出 `LOCK`，Slave 也沒有收到可接受的 `LOCK`。因此目前尚未進入 `WRS_S_LOCK`，不能宣稱 White Rabbit synchronization 完成。

## Source audit 與交叉討論共識

本輪核對 `fsm.c`、`wr-msg.c`、`state-wr-idle.c`、`state-wr-present.c`、`state-wr-m-lock.c`、`state-wr-s-lock.c` 與 standard signaling handler：

```text
Slave_PRESENT
  -> PTP signaling message path
  -> generic prefilter
  -> WR TLV parser
  -> Master wr_idle / WRS_M_LOCK
  -> LOCK
  -> Slave wr_present / WRS_S_LOCK
```

現有 parser reject counter 為 0，這只能表示目前觀測到的四個 WR TLV reject reason 沒有增加，不能證明封包已完成 Master 的 handshake acceptance。外部 White Rabbit 交叉討論也同意，下一步應先完成上述鏈路的唯讀 source/probe mapping audit，不應修改 Master，也不應先逆轉 DCO。

## Observation

Master 的 role 問題已用歷史 exact image 排除到很低優先度；本輪重新觀測仍穩定通過 `MODE=2/PTP=6/status=FF`。目前主要問題在 Slave `SLAVE_PRESENT` 到 Master `LOCK` 的 WR signaling handshake，而不是已被證明的 SoftPLL 或 DCO 問題。

## Conclusion

本輪沒有 compile 或燒錄，因此不能宣稱產生新的硬體版本或新的同步成功結果。

證據真正支持的結論是：

1. 歷史 `9f848ec` Master role baseline 已重新確認，應固定不動。
2. Slave 的 link、PTP parent discovery 與部分 servo activity 存在。
3. Slave 尚未取得 `time_valid=1`，且 WR signaling 尚未進入 `LOCK` / `S_LOCK`。
4. 目前不能把根因直接宣稱為 target identity、TLV 欄位、PCS、SoftPLL 或 DCO 其中任何一項。

## Next Step

下一輪維持 Master exact `9f848ec` 不變，只做 Slave 方向的最小唯讀觀測：補齊 Master/Slave 的 signaling TX/RX、target clock identity/port、prefilter reject reason 與 WR parser reject reason 的對照。只有當證據明確指出單一 Slave-only 功能錯誤後，才修改 Slave、compile、燒錄並另立新的實驗紀錄。


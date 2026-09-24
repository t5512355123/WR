# EXP-S6-POST-SLAVE-ENDPOINT-LINK-ATTRIBUTION-20260921

## 結論

本輪成功完成 link attribution，但不是 Step6A/Step6B PASS：

```text
LINK_ATTRIBUTION                 = PASS
POST_SLAVE_LINK_ESTABLISHMENT    = FAIL
FAILURE_CLASS                    = FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED
MASTER                           = FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED
SLAVE                            = FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED
S_LOCK                           = NOT_REACHED
STEP6A                           = NOT_PASS
STEP6B                           = NOT_RUN
```

兩板都在 6 筆有效樣本後停止，沒有 transport error，也沒有 reset/generation
變化。停止條件是 recovered-RX activity 連續 5 筆沒有增加；因此目前不能把
failure 縮到 Endpoint PCS/autonegotiation。

## 實驗範圍與硬體狀態

- branch：`exp/step6-Global-Time-Testing`
- Laptop/Pain source：`f37d61f7`
- 觀測前硬體狀態：保留 `EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-V2-20260921`
  failure session
- 本輪沒有 compile、Master/Slave program、power-cycle、PTP restart、mode command、
  fiber replug、PHY reset、SI5340 操作或 MDIO selector/control write
- observer：500 ms/sample，最多 120 samples；兩板各自執行，因 early-stop 實際各取 6 samples

## Source-backed evidence

目前 `DE5a_wr_master_jtag.vhd` 與 `DE5a_wr_slave_jtag.vhd` 的 probe mapping 支持：

- instance 0：WR/link/reset、RX data/K/bitslide、RX lock、disparity、errdetect、
  sync/pattern/running-disparity
- instance 7：REF、DMTD、recovered-RX activity counters，以及 RX ref/data lock
- Slave instance 45–48：sticky RX/link-loss counters
- Wishbone `0x00100100`：Endpoint ECR，bit 6=`TX_EN`、bit 7=`RX_EN`
- Wishbone `0x00100138`：Endpoint DSR，bit 0=`link status`、bit 1=`link activity`

本輪未讀 MDIO，避免 register selection 的 write transaction 改變 forensic state。

## 結果摘要

| Board | 有效樣本 | transport error | Endpoint control | RX data lock | RX activity count | RX syncstatus | DSR link | PTP | stop |
|---|---:|---:|---|---:|---:|---:|---:|---:|---|
| Master `DE5 [1-11.1]` | 6/6 | 0 | `ECR TX/RX=1`, `PHY_RST=0`, `TX_DISABLE=0` | 1 | 0，delta=0 | 0 | 0 | 6 | `FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED` |
| Slave `DE5 [1-11.2]` | 6/6 | 0 | `ECR TX/RX=1`, `PHY_RST=0`, `TX_DISABLE=0` | 1 | 0，delta=0 | 0 | 0 | 4 | `FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED` |

兩板也都維持：

```text
SI_CONFIG_DONE = 1
WR_READY       = 1
CPU_RESET_N    = 1
RX_READY       = 1
TX_READY       = 1
CORE_TM_LINK_UP= 0
CORE_LINK_OK   = 0
```

Slave 的 45–48 sticky raw words 在本輪沒有增加 delta；它們保存為原始證據，
但不把靜態/saturated 值解讀成「歷史上沒有錯誤」。本輪的主要歸因證據是兩板
一致的 `RX_CLOCK_ACTIVITY=0`、`RX_CLOCK_ACTIVITY_DELTA=0`、`RX_SYNCSTATUS=0`，
以及五筆連續 no-activity streak。

`RX_LOCKED_TO_DATA=1` 單獨不足以推翻這個結論；在目前 source contract 中，
recovered-RX activity 與 PCS sync 狀態仍未成立。

## Stop condition audit

- A（control disabled/reset）：未觸發；ECR TX/RX 都為 1，PHY reset/disable 都為 0。
- B（SerDes/RX stream）：觸發；兩板 no-activity streak 都達 5。
- C（PHY/PCS input integrity）：未作為第一歸因；未取得 recovered-RX activity。
- D（Endpoint PCS/autoneg）：未作為第一歸因；raw PHY healthy 的 10 筆條件未成立。
- late recovery：未發生；DSR/core link 全程為 0。
- reset/transport：未發生；6/6 samples valid，boot/reset counters 穩定。

## Raw integrity

Pain 回收的 raw log 與本機檔案 SHA-256 一致：

```text
master-endpoint-link.log  B8C642FDCC0B52C9F959BA8E142E2EECDE0409B1FDE5FFAEEE55AB55B1283132
slave-endpoint-link.log   B2967AD00202A10F362BE28510DDC706BAC6F6AFCCDA3AB5309F45DD9173E48E
```

正式 analyzer 結果在 `analysis/summary.json`；完整 raw 在 `raw/`。

## 下一步邊界

這輪只證明目前兩板的 Endpoint link failure 仍位於 SerDes/recovered-RX
stream/PCS input 之前或其邊界，不能直接宣稱是 autonegotiation bug，也不能
進入 S_LOCK 或 Global-Time trigger。下一輪方向須先由「分析下一步鎖定相位」
參考目前這個新 evidence 後指定；在此之前不重燒、不斷電、不調 PI/gain/timeout，
也不把 Step6A 判為 PASS。

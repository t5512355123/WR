# EXP-S6-POST-SLAVE-ENDPOINT-LINK-ATTRIBUTION-20260921

## Objective

在保留 `EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-V2-20260921` 硬體失敗
session 的前提下，分辨 Endpoint link 未建立的第一個可證明邊界：

1. Endpoint/PHY control 未 enable 或仍在 reset。
2. SerDes recovered RX stream 未成立。
3. RX stream 已 recovered，但 8b/10b/PCS input integrity 不健康。
4. raw PHY path 健康，但 1000BASE-X PCS/autonegotiation 沒有宣告 link。

本輪不是 S_LOCK、SoftPLL 或 TM_VALID 實驗；Step6A/Step6B 均不作判定。

## Hardware-state contract

保留目前 V2 state，不做：

- compile、Master/Slave programming、power cycle
- PTP restart、mode command、fiber replug、PHY reset
- SI5340 change、MDIO selector/control write

這是 observer/analyzer-only experiment。Pain 只需取得本輪 observer，
不應因為這輪沒有 production source 變更而重新燒錄。

## Source-backed mappings

`quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd` 與 Slave top-level 定義：

- instance 0 status low bits：SI/WR/link/reset/ready；bits 16–28 為 RX data、K、bitslide；
  high-word bits 0–7 為 RX lock、disparity、errdetect、sync/pattern/running disparity。
- instance 7：bits 0–15 REF activity、16–31 DMTD activity、32–47 recovered-RX activity；
  bits 52/53 為 RX ref/data lock。
- Slave instances 45–48：enc/disparity、errdetect/sync-loss、lock/link drop sticky counters。
- Wishbone `0x00100100` 是 Endpoint ECR，bit 6/7 分別為 TX_EN/RX_EN。
- Wishbone `0x00100138` 是 Endpoint DSR，bit 0 為 link status、bit 1 為 link activity。

本輪只用 passive probe/Wishbone reads；不碰 MDIO，因為 MDIO register selection
會產生 write transaction。

## Capture contract

- 每板約 500 ms 一筆，最多 120 筆（約 60 s）。
- Master 與 Slave 以獨立 observer session 讀取，保存完整 raw words 與 decoded fields。
- reset/boot/session/transport 改變即分類 INCONCLUSIVE。
- 讀取所有 `ENDPOINTLINK_SAMPLE`，不要用 S_LOCK、PSTAT 或 TM_VALID 當 link attribution。

## Stop/attribution contract

- control bad/reset/disable 連續 5 筆：`FAIL_ENDPOINT_CONTROL_NOT_ENABLED`
- RX data lock 消失或 recovered-RX activity 不增加連續 5 筆：
  `FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED`
- RX lock/activity 存在但 coding/disparity/errdetect/sync evidence 連續 5 筆不健康：
  `FAIL_PHY_PCS_INPUT_INTEGRITY`
- raw PHY healthy 且 Endpoint/core link 仍為 0 連續 10 筆：
  `FAIL_ENDPOINT_PCS_OR_AUTONEG_NOT_ESTABLISHED`
- link good 連續 5 筆：`PASS_LATE_RECOVERY`，但不延伸到 S_LOCK。

若資料無法保持 coherent，結果必須是 INCONCLUSIVE，不能以 observer 結束代替 PASS。

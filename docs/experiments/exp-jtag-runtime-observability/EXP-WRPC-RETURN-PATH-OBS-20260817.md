# EXP-WRPC-RETURN-PATH-OBS-20260817：Slave 回程 WR signaling 唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-RETURN-PATH-OBS-20260817`
- 日期：2026-08-17
- 分支：`exp/jtag-runtime-observability`
- 已燒錄硬體 source commit：`933ce3e`（時鐘/重置唯讀 probe 診斷版）
- 本輪性質：唯讀 JTAG 觀測，沒有重新編譯、沒有重新燒錄、沒有寫入 WR 設定。

## 這次想驗證什麼

確認 Slave 是否已進入 White Rabbit handshake，以及 Master 是否真的收到 Slave 發出的 `SLAVE_PRESENT` signaling。這用來區分 Slave 的 SoftPLL/DCO 沒運作，或是 Slave 到 Master 的回程封包沒有被 Master 端收到。

## 相較 baseline 唯一修改了什麼

- 沒有修改硬體或 firmware。
- 只使用已燒錄的 `EXP-WRPC-CLOCK-RESET-OBS-20260817` 診斷版，讀取既有的 WR state、signaling、PTP counter、SoftPLL raw register 與 DCO counter。

## 版本與硬體追溯

- Quartus：17.0.0 Build 595
- Slave SOF SHA-256：`f45a648f0e380a5ed0238f2d1030ebea9943cba93066c1f5cbc7247d40aa4a67`
- Slave MIF SHA-256：`578d526306bf28721412d2a7a51f928a169bc1561e20a404de726d51df669ecb`
- 燒錄 checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`

## 原始觀測結果

### 1. WR signaling / state

三個有效 Slave sample 都顯示：

- `WR_SIGNAL TX=10000004`：曾送出 `SLAVE_PRESENT (0x1000)` 共 4 次。
- `WR_SIGNAL RX=00000000`：沒有收到 Master 的 WR signaling。
- `WR_FAIL=02010001`：role=2、state=1、failure count=1；與 Slave 在 `WRS_PRESENT` 等待 `LOCK` 後失敗相符。
- 失敗後 `WR_LOCAL state=0 next_state=0 wr_mode=0 wrModeOn=0`，表示已回到非 WR handshake 的 idle 狀態。
- `parent_is_wr=1、parent_calibrated=1、parent_wr_config=3`，只能證明 Slave 看到了 Master 的 WR announce flags，不能證明 signaling 回程成功。

### 2. PTP counter 方向

- Slave 的 `PTP_RX` 在約三秒觀測內由 `0x000007EE` 增至 `0x000007FD`，代表 Slave 能收到 Master 的 PTP traffic。
- Master 的 `PTP_RX` 維持 `0x000064D8`，沒有對應增加；Master 沒有看到 Slave 的回程 PTP traffic。
- 因此目前呈現「Master -> Slave 可見、Slave -> Master 不可見」的單向證據。

### 3. SoftPLL / DCO

- Slave `SPLL LAST_STATE=7`，對應 `SEQ_DISABLED`；`VISIT_MASK=0、TRANSITIONS=0、REF_COUNT=0、TAG_COUNT=0`。
- Slave `DCO source=0`，一秒前後 destination/accepted/done 沒有變化。
- Slave SI5340 readback `page0_0021=0x0F、DEVICE_READY=0x0F`，I2C error=0；本輪沒有看到新的 DCO request。

原始 log：

- `build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/wr_state_runtime.log`，SHA-256：`25bd632161f9d5b65ad6564ceb2af0de29e37e46e00e205472322cbca61a5825`
- `build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/spll_raw.log`，SHA-256：`6eb419fc460eded9d987f15c94fff8eebf77ce4fb3163157113d8ad433f01b11`
- `build/artifacts/EXP-WRPC-CLOCK-RESET-OBS-20260817/dco_diag.log`，SHA-256：`f201c43d1839b7c18e12252602a53e95e973d07d4b37ce595e225a2fc0e1cf59`

### 4. Mini-NIC/PHY counter 交叉檢查

本段仍是唯讀觀測，沒有重新編譯、燒錄或寫入任何 WR/PHY/SI5340 設定。

- `runtime_counters_2s.log`：SHA-256 `e9974e56ddc09914a398d68d442d588ec470aed4f90add792c2b297ba70ea69a`。
- `phy_activity_2s.log`：SHA-256 `d1364e42e1a3d53a8ca365982a3061ca731c24e759bf85f02a39229c0e19f937`。
- `runtime_counters_after_phy.log`：SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。

兩秒 counter 讀取顯示：

- Master `PTP_RX` 維持 `0x64D8` 附近，`WDIAGS_RX` 維持 `0xA283` 附近；`RXERR` 由 `0x9D0` 增加至 `0x9D1`。
- Slave `PTP_RX` 由約 `0x0DFF` 增至 `0x0E05`，`WDIAGS_RX` 由約 `0x139E` 增至 `0x13A7`，`RXERR=0`。
- 這再次支持「Slave 能看到 Master 的 PTP，但 Master 沒有看到對應的 Slave 回程 PTP」；不過 PTP counter 是已接受/解析的封包統計，不能單獨證明光纖上完全沒有原始 frame。

clock-activity probe 的結果需要保守解讀：

- Slave：`RX_LOCK_DATA=1` 持續，`SYS625_LOCKED=1、CORE_RESET_N=1、PHY_RST=0、SI_DONE=1、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1`；但一秒前後 `RX_LOCK_REF` 由 `1` 變 `0`。
- Master：本次 instance 7 讀值的高位 runtime 欄位為 0，與同一 session 的 `status_probe=...82FF` 不一致；因此不能把這份 Master clock-activity probe 當作與 Slave 相同映像/相同欄位的有效對照。

本次沒有改硬體，故不能用這次結果宣稱 PHY 根因已確定。它只把「Master 端已接受的回程封包沒有增加」再次確認下來，同時指出下一步必須先核對兩端燒錄映像與 JTAG probe 版本，再進行任何 PHY 方向變因實驗。

## Observation

Slave 並非完全沒有執行 WR firmware：它曾送出 4 次 `SLAVE_PRESENT`，之後因沒有收到 `LOCK` 而失敗；但 Master 端的 WR signaling RX counter 為 0。這與 PTP counter 的單向結果一致。SoftPLL 顯示 `SEQ_DISABLED` 是 handshake 失敗後的結果，不能單獨當成 DCO 先出錯的證據。

## Conclusion

本輪仍未達成兩板 WR synchronization。現有證據把優先問題收斂到 **Slave -> Master 的回程封包接收路徑**：可能是 QSFP/PHY RX、lane/polarity/PCS、MAC/封包 filter/VLAN 或 WR signaling 封包在 Master 端被丟棄；目前尚不能在這些可能性中指定唯一硬體根因。DCO/SI5340 不是本輪首要變因，因為 Slave 在 handshake 通過前本來就不應進入 SoftPLL lock 流程。

## Next Step

下一步仍先做版本/映像核對，不立即燒錄新功能版：

1. 先用目前兩端的 `status_probe`、SOF checksum 與 probe instance mapping，確認 Master/Slave 都確實是同一套診斷欄位定義。
2. 在映像核對完成後，再比較兩端 QSFP lane0 的 RX CDR、word alignment、8b/10b error 與 MAC receive counter。
3. 若仍確認只有 Slave -> Master 方向遺失，再只修改一個 PHY 方向變因（先檢查 lane/polarity/PCS mapping），重新 compile、燒錄並立即建立新的燒錄實驗紀錄。

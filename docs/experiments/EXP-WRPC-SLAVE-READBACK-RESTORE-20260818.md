# EXP-WRPC-SLAVE-READBACK-RESTORE-20260818

## 實驗基本資料

- Experiment ID：`EXP-WRPC-SLAVE-READBACK-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：硬體重新燒錄後的恢復驗證
- 研究分支：`exp/master-9f-observability`
- 燒錄時 Git commit：`fa952d6`（紀錄提交後同步到 pain）
- SOF 編譯來源：`aa0825a`（本輪使用既有 SOF，不重新編譯）
- Quartus：Quartus Prime 17.0 Build 595
- 目的：恢復上一個已知能維持 WR 鏈路的 Slave readback 版本，確認前一輪新增 clock-effect counter 造成的異常不是永久性硬體狀態。

## 本輪唯一變因

本輪唯一操作變因是：

```text
Slave：由 clock-effect counter 版本 4a601f0 的 SOF
      恢復為 readback 版本 aa0825a 的既有 SOF
Master：不重新燒錄、不修改
```

本輪沒有修改 PHY、Master role、PTP 演算法、servo、SI5340 設定或 MIF。

## Bitstream 與來源證據

| 項目 | 值 |
|---|---|
| Slave SOF | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| Slave SOF SHA-256 | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| Quartus programmer checksum | `0x309FA629` |
| Slave MIF SHA-256 | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Slave QSF SHA-256 | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| Slave SDC SHA-256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Programmer cable | `DE5 [1-11.2]` |
| Device JTAG ID | `0x02E660DD` |

本輪 compile provenance 是先前 `EXP-WRPC-SLAVE-SI5340-READBACK-20260817`；本輪只做既有 SOF 的 restore programming。這不能解讀成新的 compile 成功。

## 燒錄結果

原始 programmer 輸出顯示：

```text
Info: Using programming cable "DE5 [1-11.2]"
Info: ... with checksum 0x309FA629 for device 10AX115N2F45@1
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

因此本輪「Slave SOF restore programming」成功。

## JTAG / runtime 原始結果

原始檔案保存於：

```text
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/program.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/runtime_snapshot.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/dco_state.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/dco_readback.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/clock_activity.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/runtime_timeseries.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818/log_sha256.log
```

### 立即 runtime snapshot

Master `DE5 [1-11.1]`：

```text
status_probe: 515AEAC1245082FF
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP_RX: 00006F76
WDIAGS_PTP_TX: 00010609
WDIAGS_PTP_META: 02010104
WDIAGS_MODE: 2
WDIAGS_SSTAT: 00000000
WDIAGS_PSTAT: 00000001
```

Slave `DE5 [1-11.2]`：

```text
status_probe: C372D841295082EF
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP_RX: 00000000
WDIAGS_PTP_TX: 00000000
WDIAGS_PTP_META: 03010104
WDIAGS_MODE: 3
WDIAGS_SSTAT: 00000000
WDIAGS_PSTAT: 00000001
```

立即 snapshot 時 Slave 的鏈路狀態已回到可工作形式，但 PTP 尚未累積到可判定同步的活動量，因此另外執行 30 秒時序。

### DCO readback

```text
DCO_STATE A=0005000500000320 B=0005000500000320
DCO_READBACK value=000500050005050D
```

依 readback 欄位解碼：

- completed DCO step count：`5`
- readback transaction count：`5`
- readback value：`0x0D`
- readback valid：`1`
- sticky ACK/NACK error：`0`
- value match：`1`

這證明 readback 觀測鏈仍能讀到有效值，且本輪沒有看到 I2C NACK。

### Clock activity

Slave 的 5 秒讀值為：

```text
BEGIN REF=8982 DMTD=7211 RX=46248
END   REF=27318 DMTD=25391 RX=64588
PPS_VALID=1 TIME_VALID=0 LINK_UP=1 LINK_OK=1
```

Clock activity probe 有變化，但這個 16-bit 計數器沒有用來宣稱絕對頻率；本輪只把它當作活動存在性的證據。

### 30 秒 runtime time-series

最後有效 Slave sample 的原始欄位為：

```text
WDIAGS_SSTAT:00000001
WDIAGS_PSTAT:00000001
WDIAGS_PTP:00000009
WDIAGS_PTP_RX:0000004D
WDIAGS_PTP_TX:00000038
WDIAGS_PTP_META:03020409
WDIAGS_FOREIGN_META:03000001
WDIAGS_PARSE_META:05011094
WDIAGS_DMS_L:000F488B
WDIAGS_CKO:007ABDE1
WDIAGS_UCNT:00000002
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 sstat_wr_valid=1 servo_state=0 link_up=1 spll_locked=0
PARENT: foreign_count=1 foreign_best=0 detection=0 wr_config=3 is_wr=1 mode_on=0 calibrated=1
```

Master 在時序中維持 `wr_mode=2`、`time_valid=1`、`pps_valid=1`、`link_up=1`，且 PTP RX/TX 持續活動。Slave 在後段時序已看到：

- `wr_mode=3`
- `link_up=1`
- `pps_valid=1`
- `SSTAT=1`
- `parent_is_wr=1`
- `parent_calibrated=1`
- `UCNT=2`
- PTP RX/TX 由 0 增加至 `0x4D/0x38`

但仍然是：

```text
time_valid=0
spll_locked=0
```

## Observation

1. 恢復 `aa0825a` readback SOF 後，Slave 可以重新維持 `LINK_UP=1 / LINK_OK=1`；因此前一輪 32-bit clock-effect counter 版本造成的 link down 不是由永久性硬體斷線造成。
2. readback 版本的 SI5340 readback 仍然有效，`ACK/NACK error=0`、`match=1`，所以目前沒有證據支持「I2C 完全沒有成功寫入」這個說法。
3. Slave 已經能看見 WR parent，並且 30 秒內出現 PTP RX/TX、`SSTAT=1`、`parent_is_wr=1`、`parent_calibrated=1` 與 `UCNT=2`；這比單純 `link_up` 更接近 servo 路徑已被啟動的證據。
4. 仍沒有看到 `time_valid=1` 或 `spll_locked=1`，所以不能宣稱 White Rabbit 時間同步完成。
5. 這一輪沒有發生 stall、主機斷線或需要實體重啟。

## Conclusion

本輪證據支持以下結論：

> `aa0825a` readback SOF 是目前可恢復 Slave WR link 的安全診斷 baseline；它沒有解決 Slave 最終 time-valid 問題，但已把系統恢復到可持續觀測、可看到 parent/servo 活動的狀態。

本輪證據**不支持**以下結論：

- 尚不能宣稱 SI5340 DCO 已正確調整到同步頻率。
- 尚不能宣稱 SoftPLL 已 lock。
- 尚不能宣稱兩張 DE5a 已完成 White Rabbit 時間同步。
- 尚不能把 `UCNT=2` 單獨解讀為已完成同步。

## Next Step

1. 保留目前 `aa0825a` Slave SOF 與 `f19bea8` Master diagnostic baseline，不再加入會改變大量 timing/resource 的 32-bit counter。
2. 先使用現有 16-bit `clock_activity_probe` 做短時間、唯讀、低風險的相對活動觀測，不重新燒錄；它只能回答「DCO step 前後 clock activity 是否改變」，不能直接提供精準頻率。
3. 若仍要新增硬體觀測，只加入最小的 16-bit probe，並先 compile，再以單一變因做新的 burn experiment；不能把多個 counter、clock domain 或功能修改混在同一次。
4. 下一個功能實驗再針對 Slave `time_valid=0 / spll_locked=0` 的 gating 或 SI5340 feedback 路徑，但必須維持 Master `9f848ec` role baseline 不變。

## 原始檔案雜湊

```text
program.log          5a7cc90f29937eb378006560bd95bd045df41f481649ef34c78280bc8342fe39
runtime_snapshot.log 898b2d5bc339f79af2758c162a5909134646d302f433dab28ad2c346fa401014
dco_state.log        f01c00f7227f2473625bcde57a34364b86bba3b18d3381f3fdc32a88f05f7909
dco_readback.log     788cea19918bf5c61e8876db0778d92d55237d16304f5a7ca541a03b026a54b5
clock_activity.log   e8436b82f3962948124ae22eb3ad12ebbed5f54eb360e69e70e461c24042e169
runtime_timeseries.log 6113213e014121fd24c666ed54992d425eac52b8b74d107380ac00eeeb6e965a
```

# 實驗紀錄：clean-9f Slave 加入 DCO 唯讀觀測

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only compile/burn/runtime A/B
- Git branch：`exp/master-9f-observability`
- 實驗紀錄建立前 commit：`a161b2a`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

上一輪的 clean-9f Slave 已重新收到 Master `LOCK` 並進入 `WRS_S_LOCK`，但歷史 SOF 沒有 DCO observability instance，無法直接區分：

```text
SoftPLL 沒有產生 DCO request
        vs.
DCO request 有產生，但 SI5340 I2C transaction 沒完成
```

本輪只在 clean-9f 的 Slave top/controller 上增加唯讀 DCO state、step count、busy/error 與 load pulse probe；不改原本的 WR parser、role、PHY、DDMTD、servo、SoftPLL 設定或 SI5340 transaction state machine。

## 相較 baseline 的唯一變因

- Master：維持 exact historical `9f848ec` SOF，不重新燒錄。
- Slave：以 clean-9f source/MIF/function baseline 為基礎，只增加 DCO observability output 與 altsource probe。
- 不重新產生 firmware MIF；沿用已知 clean-9f Slave MIF。
- 不改功能性 acceptance、startup command、PHY、DCO 控制流程或 clock polarity。

## 預定產物與成功判準

- 預定 Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 預定 clean-9f baseline Slave SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- 新 diagnostic Slave SOF/MIF/QSF、compile log 與 hash 於 compile 後補入。
- 第一層 runtime 判準：仍需看到 `rx_msg=0x1001`、`fail_state=2`、`WR_LOCK polls` 活動。
- 觀測判準：DCO probe 能清楚顯示 step/load/busy/error；這不等於同步成功。
- 最終同步仍必須看到 Slave `spll_locked=1、time_valid=1、pps_valid=1` 並長時間穩定。

## 編譯結果

待 source patch 與 pain Quartus compile 完成後補入。

## 燒錄結果

尚未燒錄。若 compile 成功，燒錄後立即補 programmer raw log、SOF checksum、JTAG ID 與 configuration result。

## JTAG/runtime 原始結果

尚未執行。

## Observation

待 compile/burn/runtime 結果補入。

## Conclusion

在尚未 compile、燒錄與觀測前，不對 DCO/SoftPLL 根因下結論，也不宣稱同步成功。

## Next Step

先完成 source-level single-variable patch 與 Quartus compile；若 compile 成功，再由 pain 使用明確 commit 編譯/燒錄，不改 Master。

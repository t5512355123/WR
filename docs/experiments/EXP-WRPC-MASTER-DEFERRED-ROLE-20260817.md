# EXP-WRPC-MASTER-DEFERRED-ROLE-20260817

## 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-DEFERRED-ROLE-20260817`
- 日期：2026-08-17
- 實驗名稱：鏈路建立後延遲設定 Master role
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`f1614cd`
- 基準版本：`e36a8b3`（正常 boot、Master/Slave 都為 mode 3）
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

確認完整 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 是否只能在 endpoint link-up 後安全執行。若能執行，觀察 Master mode 是否變成 2，並確認 Slave 是否開始 parent/servo/SoftPLL 流程。

## 相較 baseline 的唯一修改

1. 恢復 `wrc_initialize()` 內的初始 `WRC_MODE_SLAVE`。
2. 只在 `wrc_check_link()` 偵測到 link-up transition 後，於 Master 組態執行一次 `wrc_ptp_set_mode(WRC_MODE_MASTER)`。
3. 加入暫時 marker：`B2000001` 表示呼叫前，`B2000000|return_code` 表示呼叫返回。

沒有修改 PHY、QSFP、PTP filter、servo、SI5340、PPS 或 timing constraints。

## 編譯與來源完整性

- Master firmware build：成功
- Master MIF SHA-256：`5a8d8374ec4026cf424af0bb796bbd91ffb2d9443c8346ab4217217c6a0eaddb`
- Master Quartus full compilation：`COMPILE_RC=0`
- Master SOF SHA-256：`c8c01ccd8186949d9a170dcd72e197aaa69552294187798827eccac7a660404e`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave 維持上一輪 baseline SOF：`d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`

## 燒錄結果

- 燒錄時間：2026-08-17 15:56:37 至 15:56:56（Asia/Taipei）
- cable：`DE5 [1-11.1]`
- device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A31DBA`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`

以上燒錄結果已先寫入本紀錄。pain 原始證據：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-DEFERRED-ROLE-20260817/`

- `provenance.txt`
- `build_master_firmware.log`
- `master_mif.sha256`
- `quartus_master_compile.log`
- `master_sof.sha256`
- `program_master.log`

## Runtime 原始結果

同一 JTAG session 的 `t=0s`、`t=10s`、`t=60s` read-only observation 已完成；完整輸出寫入上述 artifact 目錄的 `runtime_readings.log`，摘要寫入 `runtime_summary.log`。

### Master：DE5 [1-11.1]

| 時間 | marker | status low byte | link_up/link_ok | WDIAGS_MODE | SSTAT/PSTAT | PTP RX/TX |
|---|---|---|---|---:|---|---|
| 0 s | `B004` | `0xE3` | `0/0` | 3 | `0/0` | `0x0/0x1` |
| 10 s | `B004` | `0xE3` | `0/0` | 3 | `0/0` | `0x0/0x2` |
| 60 s | `B004` | `0xE3` | `0/0` | 3 | `0/0` | `0x0/0x7` |

### Slave：DE5 [1-11.2]

Slave 維持上一輪 baseline bitstream；0/10/60 秒 status low byte 也是 `0xE3`、`link_up/link_ok=0/0`、`WDIAGS_MODE=3`、`SSTAT=1`、`PSTAT=0`、`UCNT=0`。PTP counter 仍有既有值，但沒有因本輪 Master 映像建立有效 link。

## Observation

1. `status_probe` 的低 8 bits 定義為 bit2=`tm_link_up`、bit3=`link_ok`；兩片在三個時間點都是 `0xE3`，所以 deferred role code 沒有被觸發。
2. Master marker 一直是 `B004`，沒有 `B2000001` 或 `B200xxxx`；這不是「API 返回錯誤」，而是 link-up event 根本沒有發生。
3. CPU fault=0、JTAG script 成功，但兩端 PHY/WR link 未建立；本輪不能判斷 `wrc_ptp_set_mode(MASTER)` 在 link-up 後是否安全。
4. Slave 沒有 `PSTAT.locked`、`time_valid=1` 或 `pps_valid=1` 的同步證據。

## Conclusion

本輪結論：deferred role switch 尚未被測到，因為燒錄後兩端 `tm_link_up=0/link_ok=0`。證據支持目前首要阻塞點是 QSFP/PHY link，不是 Master API 的 return code；不能宣稱 Master role 或兩端同步成功。

## Next Step

先用同一個已知 baseline 的 Master/Slave SOF 重新配置兩片，確認 `tm_link_up=1/link_ok=1` 後再重測 deferred role。若仍為 `0/0`，停止改 firmware，改做唯讀 PHY lane/polarity/optical/link 診斷；若 link 成立，才依 marker 判讀 deferred API 是否返回。

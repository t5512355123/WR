# EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817

## 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817`
- 日期：2026-08-17
- 實驗名稱：以歷史成功的 9f848ec Master role 建立最新診斷基準
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`c4bdc8dfeddaa375e6a727c4957804276e20c0bb`
- 歷史 Master role 基準：`9f848ec84b73328daca63b64d2725817e8802e60`
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

使用歷史上曾經成功的 Master 啟動流程，確認 Master 能否在不新增 role 切換方法的前提下恢復：

1. `debug marker = B004`
2. `WDIAGS_MODE = 2`
3. `WDIAGS_PTP = 6`
4. `status low byte = 0xFF`
5. PTP RX/TX counter 持續增加

上述五項只用來確認 Master diagnostic baseline；即使五項成立，也不直接宣稱 Slave 已完成時間同步。

## 相較前一實驗的唯一修改

恢復 `9f848ec` 的 Master startup command：

```text
vlan off;ptp stop;mode master;ptp start
```

移除後續實驗加入的 `CONFIG_FORCE_MASTER_AFTER_INIT`、延後 link-up role switch 與直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 路徑。`9f848ec` 當時已包含的 JTAG、clock、signaling 與 runtime observability 保留不變。沒有修改 Slave、PHY、QSFP、PTP filter、servo、SI5340 或 timing constraints。

## 編譯與來源完整性

- Master firmware build：成功
- Master Quartus full compilation：`Full Compilation was successful`
- Quartus fitter：`Successful`
- Master MIF SHA-256：`08a423a70bb6785e99e7d835c0b73b9d1cf039dbd2f8aaef55a6f98fb943a3c4`
- Master SOF SHA-256：`544de0cd16e001f0b691b5875155a2540712091fc2867a099211941db743343c`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Timing report：setup `-0.184 ns`、hold `-3.475 ns`；因此 compile 成功不等於 timing closure 成功
- Slave baseline MIF SHA-256：`e3e8c421e1ebcae881c1e27bdfe71261bd9e8e66937c8574e7e9d7962a96c65d`
- Slave baseline SOF SHA-256：`d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`

pain 原始來源與建置證據：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817/`

- `provenance.txt`
- `build_master_firmware.log`
- `quartus_master_compile.log`
- `master.wrc.mif`
- `master.sof`
- `hashes.sha256`

## 燒錄結果

### Master：`DE5 [1-11.1]`

- 燒錄時間：2026-08-17 16:14:51 至 16:15:10（Asia/Taipei）
- SOF checksum：`0x30A31DBA`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：Quartus Prime 17.0，`0 errors, 0 warnings`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817/program_master.log`

### Slave：`DE5 [1-11.2]`

- 燒錄時間：2026-08-17 16:15:47 至 16:16:06（Asia/Taipei）
- SOF checksum：`0x30A152A4`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：Quartus Prime 17.0，`0 errors, 0 warnings`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817/program_slave.log`

## JTAG/runtime 原始結果

待兩端完成燒錄後，以同一個 read-only JTAG session 於 `t=0s`、`t=10s`、`t=60s` 讀取 Master 與 Slave。原始輸出保存於：

`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-OBSERVABILITY-20260817/runtime_readings.log`

### Master 預期欄位

| 時間 | marker | status | WDIAGS_MODE | WDIAGS_PTP | PTP RX/TX | 結果 |
|---|---|---|---:|---:|---|---|
| 0 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |
| 10 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |
| 60 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |

### Slave 欄位

| 時間 | status | WDIAGS_MODE | WDIAGS_PTP | SSTAT/PSTAT | parent/foreign | UCNT/time_valid/pps_valid |
|---|---|---:|---:|---|---|---|
| 0 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |
| 10 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |
| 60 s | 待補 | 待補 | 待補 | 待補 | 待補 | 待補 |

## Observation

待燒錄後填入原始 JTAG 結果。`status` 的判讀只依現有 mapping：bit2=`tm_link_up`、bit3=`link_ok`、bit4=`time_valid`、bit5=`pps_valid`。

## Conclusion

在取得 configuration 與 runtime 原始證據前，不宣稱 Master baseline 或兩端同步成功。

## Next Step

若 Master 五項 baseline 證據全部成立，固定 Master 映像，不再修改 Master role；接著只讀取 Slave parent、SSTAT/PSTAT、UCNT、PPS 與 `time_valid/pps_valid`，逐步確認 Slave servo/SoftPLL 路徑。若 Master baseline 仍不成立，停止研究 Slave，先回到 startup/PHY 的證據鏈。

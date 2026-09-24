# EXP-WRPC-STEP2-D749392-PROGRAM-20260819

## 實驗資訊

- 實驗名稱：Step 2 fresh HEAD 啟動命令隔離候選版雙板燒錄
- 日期：2026-08-19
- Git branch：`exp/restore-c88cc05-baseline`
- Git commit：`d749392a6738b8a92940e2a2ae44cfec5807e11a`
- 目的：驗證最新 HEAD 在不使用 historical c88cc05 SOF 的前提下，能否以 fresh firmware、fresh Quartus SOF 重現 Step 2 Endpoint / MiniNIC / PTP packet path。

## 相較前一候選版的唯一修改

保留 built-in Master/Slave startup command，並新增 `STEP2_DISABLE_PERSISTENT_INIT`，讓 firmware 不執行板上 flash 內可能殘留的 init script。這是為了排除 stale board-local startup command 對 role 的影響；沒有修改 PTP、WR signaling、SoftPLL、PHY 或 SI5340 演算法。

## Fresh build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master MIF SHA256：`5aa3296dfd3291a283ccc2aaa02d797e3bee92d2b3f4cb147467cf793d564da3`
- Slave MIF SHA256：`d89611540b3513ac656d659baeba1d11196ed07f675473899d6e15d505cc03f6`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`d50cc56469657b3fc525b7eb3802e1f3ab1d447482a453c80b61e67009e58980`
- Slave SOF SHA256：`fdde4d847c809d9b58e9a44f5291bfc2e47227d948c083f0ac82c77db5b524bd`
- Quartus clean compile：Master/Slave 均成功；`TIMING_CLOSED=NO`
- Compile logs：`/home/b10504072/04_WR_step2_head/build/build_jtag_master.log`、`/home/b10504072/04_WR_step2_head/build/build_jtag_slave.log`

## 燒錄結果

- Master cable：`DE5 [1-11.1]`
  - programmer checksum：`0x309F7BEE`
  - 結果：`Configuration succeeded`、`0 errors`、`0 warnings`
- Slave cable：`DE5 [1-11.2]`
  - programmer checksum：`0x30A4AAA4`
  - 結果：`Configuration succeeded`、`0 errors`、`0 warnings`
- 完整原始輸出：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-D749392/program.log`

## JTAG / runtime 結果

燒錄約 45 秒後完成 JTAG snapshot；30--60 秒 time-series 仍待補做。結果欄位先依 snapshot 判定為 `FAIL`，不得將本實驗視為 Step 2 PASS。

- JTAG snapshot：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-D749392/runtime_snapshot.log`
- time-series：PENDING
- Step 2 gates A--G：FAIL（role/foreign gate）

### Snapshot 摘要

| Gate | Master | Slave | 判定 |
|---|---|---|---|
| CPU reset/fault/im_valid/marker | `0/0/1/B004` | `0/0/1/B004` | PASS |
| PHY/link、RX error | healthy、error=0 | healthy、error=0 | PASS |
| Endpoint MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS |
| MiniNIC WDIAGS_TX/RX | `0x00000001 / 0x000000FE` | `0x00000113 / 0x000000B5` | 有活動 |
| PPSI PTP RX/TX | `0x92 / 0x4A` | `0x4A / 0x8E` | 有活動 |
| PTP role/state | `MODE=3, PTP=4` | `MODE=3, PTP=4` | FAIL |
| Slave Foreign Master | `0000FF01` | `0000FF01` | FAIL；不是 `03000001` |

其他讀值：兩片 `cpu_marker=B004` 且 `seen=1`、`CPU fault=0`、`rx_enc_err=0`；Slave `UCNT=1`，但本輪不以此宣稱 SoftPLL lock。`time_valid`/SoftPLL 仍不屬於 Step 2 acceptance gate。

## Observation

fresh firmware、clean Quartus compile 與雙板 program 成功，但 runtime role/foreign gate 失敗。`TIMING_CLOSED=NO` 仍是建置限制，不能省略記錄。持久化 flash init 已被隔離，仍無法重現 Master=`PPS_MASTER`；因此不能把問題單獨歸因於板上 stale init script。

## Conclusion

目前證據支持「exact functional HEAD 已成功產生並燒錄到兩片 DE5a，Endpoint/MiniNIC/PTP packet counter 有活動」，但不支持 Step 2 完整 PASS，因為 Master 沒有進入 `MODE=2/PTP=6`，Slave 也沒有建立 `FOREIGN_META=03000001`。目前不可 merge。

## Next Step

保存至少 30--60 秒 runtime time-series，並比對 `c88cc05`、`9f848ec` 與目前 HEAD 的 startup/role functional delta；下一個實驗只處理 role reproduction，不修改 Step 3/4 的 SoftPLL 演算法。

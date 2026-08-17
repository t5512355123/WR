# EXP-WRPC-MASTER-SHELL-MARKER-PRESERVE-20260817

## 實驗資訊

- 日期：2026-08-17
- 實驗名稱：保留 Master 初始化命令診斷 marker
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`e36a8b3d2986e96436e6c229834f16640bd50a29`
- 基準版本：`0b4560d`（上一輪 marker 被 `B004` 覆寫的診斷實驗）
- 本次唯一修改：Master 組態在 `wrc_tasks_run_inits()` 返回後，若 marker 已為 `0xB1xx....`，就保留該 marker；否則維持原本 `B004`。不改 PHY、PTP 演算法、servo 或 SI5340。
- Quartus：Quartus Prime 17.0 Build 595 (04/25/2017 SJ Standard Edition)

## 想驗證什麼

取得可靠的 Master shell init command execution evidence，確認 `vlan off;ptp stop;ptp master;ptp start` 是否完整執行，以及是否有錯誤回傳。這是為了解釋前一輪 Master `WDIAGS_MODE` 仍為 3；本輪不直接把任何 mode 值當成同步成功。

## 編譯與來源完整性

- Master firmware：成功
- Master MIF SHA-256：`409ca7097696df2324a15c1cdd65e32f73766bc6c0a9f60a5b1feca5530ef4c6`
- Master Quartus full compilation：`0 errors, 272 warnings`
- Master SOF SHA-256：`74f0e9b27dfd6654913a11c3562f20ec75311fe82347c5ecf5708865311bede3`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave 維持上一輪已燒錄版本：MIF `e3e8c421e1ebcae881c1e27bdfe71261bd9e8e66937c8574e7e9d7962a96c65d`；SOF `d153b51ecf7de857f9a3e28fbceb08d94ee5e6020e54f7a78bc7617ff0ae10e1`。

## 燒錄結果

- cable：`DE5 [1-11.1]`
- device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A31DBA`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`

## Marker 定義

Master 每執行一個內建命令後寫入：

```text
0xB1<count><first_error_low16>
```

四個命令全部成功時預期為 `0xB1040000`。若仍為 `0xB004`，代表 shell init 沒有留下 marker 或實際燒錄映像不含本診斷。

## 原始證據位置

pain：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SHELL-MARKER-PRESERVE-20260817/`

- `build_master_firmware.log`
- `master_mif.sha256`
- `quartus_master_compile.log`
- `provenance.txt`
- `program_master.log`
- `runtime_readings.log`（觀測完成後補入）

## 初步結論

截至燒錄完成，只能確認本輪 Master SOF 已由指定 commit 成功編譯與 configuration；Master role、Slave servo、`time_valid` 與 `pps_valid` 尚未判定。

## 燒錄後 runtime 原始結果

本輪使用同一個 JTAG read-only session，在 `t=0s`、`t=10s`、`t=60s` 讀取 Master 與 Slave。完整原始輸出保存在 pain 的 `runtime_readings.log`。

### Master：DE5 [1-11.1]

| 時間 | marker | WDIAGS_MODE | SSTAT | PSTAT | PTP RX/TX | 其他觀察 |
|---|---|---:|---:|---:|---|---|
| 0 s | `0x0000B004` | 3 | 0 | 1 | `0x17 / 0x15` | CPU fault=0，PC 有效 |
| 10 s | `0x0000B004` | 3 | 0 | 1 | `0x1A / 0x1B` | CPU fault=0，PTP counter 有活動 |
| 60 s | `0x0000B004` | 3 | 1 | 1 | `0x35 / 0x33` | CPU fault=0，仍非 Master mode |

Master 的 `PPS_ESCR=0`、`WDIAGS_UCNT=0`；沒有取得 `WDIAGS_MODE=2` 的證據。

### Slave：DE5 [1-11.2]

| 時間 | marker | WDIAGS_MODE | SSTAT | PSTAT | PTP RX/TX | 其他觀察 |
|---|---|---:|---:|---:|---|---|
| 0 s | `0x0000B004` | 3 | 1 | 1 | `0x2D8 / 0x386` | foreign meta=`0x0000FF01` |
| 10 s | `0x0000B004` | 3 | 1 | 1 | `0x2DE / 0x38C` | CKO=`0x0BD8D641`，UCNT=0 |
| 60 s | `0x0000B004` | 3 | 1 | 1 | `0x2F6 / 0x3A4` | CKO=`0x0BD8D641`，UCNT=0 |

Slave 有 PTP 封包活動與 foreign master 記錄，但 `PSTAT.locked` 沒有成立、`UCNT` 沒有增加，且沒有 `time_valid=1` 或 `pps_valid=1` 的證據。

## Observation

1. Master 的 CPU 仍在執行，`fault=0`，PTP RX/TX counter 會增加；因此本輪沒有證明 CPU 已死機或 PHY 完全不通。
2. Master marker 沒有從預期的 `0xB104....` 出現，仍是 `B004`。即使 ELF 反組譯可看到 marker 程式與 init command 字串，實際 runtime 仍沒有留下 shell command execution evidence。
3. Master 長時間維持 `WDIAGS_MODE=3`，所以目前不能稱它為 Master，也不能用這輪資料宣稱 Slave servo 已經成功。
4. Slave 看到 PTP/foreign master，但 `PSTAT.locked=1` 的欄位並未出現；此處的 PSTAT 值 `1` 不是已證明的 SoftPLL lock，仍需依目前 register mapping 解讀完整欄位。

## 結論

本輪實驗失敗於「未取得 Master shell 初始化命令已執行且角色切換成功的證據」，不是同步成功。證據支持的最保守結論是：CPU/runtime 與 PTP 路徑仍有活動，但 Master 角色未被驗證，Slave 尚未被證明完成 servo/SoftPLL lock 或時間同步。

## 下一個單一變因

不再依賴 shell parser 作為角色切換入口。在 `wrc_tasks_run_inits()` 完成後，Master 組態直接呼叫 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 與 `wrc_ptp_start()`；保留本輪 marker 與 read-only register 觀測，其他 PHY、PTP filter、servo、SI5340 與時序設定不變。這樣下一輪可直接區分「shell init 未執行」與「PTP master API/後續流程本身有問題」。

## 下一步

完成上述單一變因後，重新 build、compile、燒錄並重做 0/10/60 秒 read-only observation；只有看到 Master mode、Slave parent/servo、`time_valid` 與 `pps_valid` 的連續證據，才進入同步成功判定。

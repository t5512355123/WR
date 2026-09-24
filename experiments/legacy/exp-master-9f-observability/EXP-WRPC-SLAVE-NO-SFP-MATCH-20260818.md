# 實驗紀錄：Slave 移除啟動時 SFP match

- Experiment ID：`EXP-WRPC-SLAVE-NO-SFP-MATCH-20260818`
- 日期：2026-08-18
- 實驗類型：Slave firmware 單一變因；compile、燒錄與燒錄後 JTAG runtime 觀測
- Git branch：`exp/master-9f-observability`
- Git commit：`502f099`（移除 Slave 啟動時 `sfp match`）
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

歷史 Master 成功 baseline 的關鍵差異之一，是 startup command 沒有先執行會阻塞的 `sfp match`。這次只在 Slave 做相同方向的最小化實驗，確認 Slave 是否能因此完成 PTP parent/SoftPLL 啟動，讓 `RCER`、有效 tag 與 TRR IRQ 開始活動。

## 相較 baseline 唯一修改

只修改：

```text
CONFIG_INIT_COMMAND="vlan off;ptp stop;sfp match;mode slave;ptp start"
```

改成：

```text
CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
```

沒有修改 Master firmware、Master role、Slave RTL、PHY、DDMTD reverse setting、SoftPLL PI/threshold 或 Quartus QSF/SDC。

## 建置與 provenance

pain 先從 GitHub fetch 並 checkout 明確 commit：

```text
git fetch origin exp/master-9f-observability
git checkout --detach 502f099
```

### MIF、SOF、QSF、SDC

| 項目 | SHA-256 |
|---|---|
| 新 Slave MIF `build/firmware/slave/wrc.mif` | `7da77f8bbd47be594668055f2e398f0b3b72bba970d384729bda75a55d4dbe94` |
| 新 Slave SOF `DE5a_wr_slave_jtag.sof` | `81d1f3444116a3aee4b5f31db0b0a83240fa9c422ece7e5f87f56f01572fbea2` |
| Slave QSF | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| Slave SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |

前一個已知 Slave baseline MIF/SOF 分別為 `f24527...` / `079fade...`；QSF/SDC hash 沒有改變。

### Compile 結果

使用：

```text
bash scripts/pain/pain_build_jtag_slave.sh
```

結果：

```text
WRPC slave MIF: /home/b10504072/04_WR/build/firmware/slave/wrc.mif
Slave Quartus build passed: /home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof (timing_closed=NO)
Info (293000): Quartus Prime Full Compilation was successful. 0 errors, 269 warnings
```

Quartus compile log SHA-256：`1f8d5a94df88d71ef870c07f438dd35f3aa545994dea5741f2dec0a6fc93c7d1`

注意：compile 成功，但 timing report 仍有負 setup/hold slack，因此不能把它描述為 timing closure 成功。

## 燒錄結果

第一次透過非互動 SSH 呼叫 `sudo` 時失敗，原因是：

```text
sudo: a terminal is required to read the password
```

這次沒有碰到 FPGA，原始失敗 log SHA-256：
`a7f80960f87887f27ca84f4a56a571ac4d5f52c8f3318bcaeb7012fc0a0ca33a`

第二次以授權的 `sudo -S` 重試，實際燒錄成功：

```text
Info: Version 17.0.0 Build 595
Info: Using programming cable "DE5 [1-11.2]"
Info: Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x309FA629
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

成功燒錄 log SHA-256：
`4bdd262dd41627d511f8987a93b600bae1a167e1adbcb9c494dec044f0a85781`

這次只重新燒錄 Slave；Master 沿用既有 `9f848ec` role baseline image，沒有重新燒錄。

## 燒錄後 runtime 觀測

執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 30 1000
```

runtime raw log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-NO-SFP-MATCH-20260818/runtime_after_program_30s.log
```

runtime log SHA-256：
`0b56efd617075346279aa3742117bae694953b035131c4ff9a0a09613c4788a8`

Quartus STP 結果：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

### Slave 原始觀測重點

燒錄後第一筆是重新啟動期間的暫態 `MODE=0`；後續進入 `MODE=3`。整段 30 秒觀測中：

```text
MODE=3
RCER=00000000
TAG_VALID=00000000
TRR_WRITE=00000000
IRQ=00000000
SSTAT=00000000
PTP_RX=00000000
```

`TAG_SOURCE` 在多數取樣點增加，但仍沒有 valid tag/TRR/IRQ。`PTP` 後段曾出現 `6`，`PARSE` 也增加；然而沒有 `PTP_RX`、`RCER`、`SSTAT` 或 valid tag 證據，不能把這個 `PTP=6` 單獨視為 White Rabbit Master/Slave synchronization 成功。`PSTAT` 可見 link bit，但 lock bit 沒有成立。

## Observation

1. 移除 Slave startup `sfp match` 沒有讓 `RCER` 從 0 變成有效值。
2. `TAG_SOURCE` raw activity 仍存在，表示 DDMTD source event 並非完全消失。
3. `TAG_VALID`、`TRR_WRITE`、`IRQ`、`SSTAT` 仍沒有活動，SoftPLL 沒有進入可證明的有效 tag/servo path。
4. Slave 的 PTP state 曾讀到 6，但 `PTP_RX=0`；這個組合不能證明它已選到 Master parent，必須保守解讀。

## Conclusion

證據支持：

- compile 成功且 Slave SOF 確實燒錄成功。
- 這個單一變因沒有解決目前可觀察的 Slave SoftPLL enable 缺口。
- 問題不能再單純歸咎於 startup command 中的 `sfp match`。
- Master role 仍應固定沿用 `9f848ec`，沒有理由新增 role switching。

證據不支持：

- 兩片 DE5a 已完成 WR time synchronization。
- Slave 已經建立有效 parent。
- `PTP=6` 單獨代表 Slave 已同步。
- `RCER=0` 的最終根因已被完全證明；它仍可能是 PTP parent/servo 初始化未完成的結果。

## Next Step

不要再改 Master。下一步先針對 Slave 做更直接的 runtime source audit：確認 `wrc_ptp_set_mode/start`、parent selection 與 `rts_lock_channel(0)` 是否在目前 PPSI/WR extension state 中實際被呼叫；必要時加入只讀的 firmware stage/parent-selection marker，再以一個新的 commit 重新 build。除非這個 audit 指向特定單一變因，不再盲改 PHY、FINC/FDEC、PI gain 或 DDMTD polarity。

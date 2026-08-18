# EXP-WRPC-SLAVE-READBACK-RESTORE-ACTIVE

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-READBACK-RESTORE-ACTIVE-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`6d31202`（執行燒錄時的 source/document checkout）
- 實驗類型：恢復既有 Slave readback SOF 的硬體 A/B
- 目的：以先前曾看見 PTP、parent 與有效 tag activity 的 `aa0825a` readback SOF，取代最近 `no-sfp-match` SOF，確認問題是否因最新 Slave 映像的 runtime 行為退化

## 為了驗證什麼

最近 `no-sfp-match` Slave 映像的唯讀結果為：

```text
PTP_RX/TX=0
RCER=0
TAG_VALID/TRR/IRQ=0
SSTAT=0
```

但較早的 `aa0825a` readback SOF 曾觀察到：

```text
PTP RX/TX 活動
foreign_count=1
parent_is_wr=1
parent_calibrated=1
SSTAT=1
TAG/TRR activity
```

本輪只驗證恢復該已保存 bitstream 是否能讓 Slave 回到可觀測的 PTP/parent/tag path。這不是同步成功判定；同步仍必須另外看到 `spll_locked=1`、`time_valid=1`、`pps_valid=1` 與穩定 parent/servo 證據。

## 相較 baseline 唯一修改了什麼

只重新燒錄既有 Slave readback SOF：

```text
目前 no-sfp-match Slave SOF
    -> aa0825a readback Slave SOF
```

Master 不重新燒錄、不修改 role、不修改 PHY、PTP、FINC/FDEC、PI、lock threshold 或 DDMTD polarity。沒有重新 compile。

## Bitstream provenance

### Master（保持不動）

- 歷史 role：`9f848ec`
- SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`
- MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- 前次 programmer checksum：`0x30A46449`
- Cable：`DE5 [1-11.1]`

### Slave（本輪重新燒錄）

- 來源：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`
- MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

## 燒錄結果

### 第一次嘗試

第一次命令因 Windows PowerShell 與遠端 shell 的 quoting 使 `sudo` 沒有收到密碼，結果為：

```text
sudo: no password was provided
sudo: 2 incorrect password attempts
```

這次沒有進入 Quartus Programmer，也沒有改變 FPGA；不能當作硬體失敗。

### 修正 quoting 後的正式燒錄

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-ACTIVE-20260818/program_slave.log
```

原始 log SHA-256：

```text
8a9105eb99f15835d4b2164dc203e79f428512a4aff0acbcb47bb95d921ea59c
```

Quartus Programmer 原始結果：

```text
Info: Version 17.0.0 Build 595
Info: Using programming cable "DE5 [1-11.2]"
Info: ... checksum 0x309FA629 for device 10AX115N2F45@1
Info: Device 1 contains JTAG ID code 0x02E660DD
Info: Configuration succeeded -- 1 device(s) configured
Info: Successfully performed operation(s)
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

燒錄結果：成功。這只證明 Slave SOF 已載入，不代表 White Rabbit 已同步。

## 燒錄後 runtime 狀態

### 30 秒觀測

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-ACTIVE-20260818/runtime_after_program_30s.log
```

原始 log SHA-256：

```text
5b91fd47eb68d737bcf7fb275b4e26886702b32edc26bca9afc423d81eb93a78
```

本輪 30 個 Slave sample 全部 accepted，但有效 frame 仍主要顯示：

```text
Slave wr_mode=3
time_valid=0
pps_valid=1
PTP_RX=0
PTP_TX=0
parent_is_wr=0
parent_calibrated=0
SSTAT=0
RCER=0
TAG_VALID/TRR/IRQ=0
```

Master 同一 session 維持 `wr_mode=2`、`status=0xFF`、`time_valid=1`、`pps_valid=1`；因此這次不是兩端都失去 role 的證據。

### 120 秒觀測

為排除短時間 acquisition 尚未完成，使用同一 bitstream 再做 120 秒唯讀觀測。

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-ACTIVE-20260818/runtime_after_program_120s.log
```

原始 log SHA-256：

```text
22bf3cc2eca5d06bf53c99c2f0b52fd26459a83893bd011e06f2068bef5c05bd
```

Slave 共有 108 個 accepted sample、12 個在 retry 後未 accepted。108 個 accepted sample 中，主要結果仍為：

```text
time_valid=0
PTP_RX=0
PTP_TX=0
parent_is_wr=0
parent_calibrated=0
SSTAT=0
RCER=0
TAG_VALID/TRR/IRQ=0
spll_locked=0
```

少數跨 mailbox read 邊界的 frame 出現不一致欄位，例如 `foreign_best=0` 或事件 counter 的 begin/end 不同；這些列未通過完整一致性判定，不能拿來宣稱 parent 或 tag activity。120 秒內沒有出現一筆完整的 Slave `time_valid=1 + spll_locked=1 + parent` 證據。

## Observation

1. `aa0825a` readback SOF 已成功載入 Slave。
2. 30 秒與 120 秒觀測都沒有穩定重現先前保存的 PTP/parent/tag activity。
3. Master 在同一時段仍維持 `MODE=2` 與有效時間旗標。

## Conclusion

目前只能下以下結論：

> Slave readback SOF 燒錄成功，但本輪 30/120 秒觀測沒有證明 PTP parent、SoftPLL 或兩片 DE5a 時間同步成功。先前 readback log 中的 parent/tag activity 目前無法在相同 bitstream 上重現，因此需要先排除雙板 runtime restart/啟動順序因素，再進行功能修改。

## Next Step

下一步先重新載入兩片完全相同的已保存 exact baseline：Master `9f848ec` SOF 與 Slave `aa0825a` readback SOF，並分別保存兩份 programmer log。這不是新的 Master role 方法，只是雙板 runtime restart；燒錄後立即另立實驗紀錄，再使用同一 JTAG session 讀取：

```text
MODE、status、PTP state、PTP RX/TX、foreign/parent flags、WR state、
SPLL sequence、RCER、TAG_VALID、TRR_WRITE、IRQ、PSTAT、SSTAT、time_valid、pps_valid
```

若 Slave 回到 PTP/parent/tag activity，再以現有 readback baseline 作為後續 Slave-only source/functional 實驗基準；Master role 維持 `9f848ec`，不新增切換方法。

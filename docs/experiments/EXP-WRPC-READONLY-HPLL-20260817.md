# EXP-WRPC-READONLY-HPLL-20260817：HPLL-only bitstream 的 60 秒唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-READONLY-HPLL-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：既有 bitstream 的唯讀 JTAG runtime 觀測
- 本輪沒有修改 RTL、沒有 compile、沒有燒錄 FPGA。

## 這次想驗證什麼

確認目前 Slave 的 HPLL-only bitstream 在不再寫入 SI5340 的情況下，
Slave 的 parent、PTP、SoftPLL raw event、servo update 與 `time_valid` 是否
持續活動，並區分「servo 有活動但尚未 lock」與「runtime 已停止」兩種狀態。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- 觀測工具 commit：`b05d1342b230db314ede46b153554e1fc1e8e659`
- 板上 Slave 硬體來源：`b8e1f855a5f75ad6fd748b1e36e464cbefac3163`
- pain checkout：detached HEAD，固定於 `b05d134`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- JTAG 腳本：`scripts/jtag/read_wb_timeseries_session.tcl`
- 設定：`60` samples、`1000 ms` 間隔、每筆最多 `5` 次 retry

## 板上 bitstream 與 provenance

本輪沒有重新燒錄，以下是觀測開始時板上的既有 bitstream：

- Master SOF SHA-256：`e629810b214379e283b4ef9aba0867126ffedcdc85a3e25134bb84eb0871ec8a`
- Slave SOF SHA-256：`b25af7514b54907e21ec891d7cb106a1b20cafe52d4b5736f1a830cc4fdf3204`
- Slave programmer checksum：`0x30A2A4DF`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

## 原始結果

- pain 原始 log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-READONLY-HPLL-20260817/runtime_60s.log`
- log SHA-256：`25d0ccffe93e54596aa17933e611c35d159e33d4d85154354caf2be548dabaca`
- Quartus script result：`SESSION_TIME_SERIES_DONE`
- Quartus STP result：`Info (23030): Evaluation of Tcl script ... was successful`
- Quartus STP errors/warnings：`0 errors, 0 warnings`
- 總樣本：Master `60`、Slave `60`
- frame accepted：Master `60/60`、Slave `10/60`
- Slave 其餘 `50` 筆被 mailbox consistency check 判為 invalid；這些列不納入同步結論。

## 有效樣本的 runtime 結果

### Master

- `60/60` 筆有效。
- `time_valid=1`、`pps_valid=1`、`wr_mode=2`、`link_up=1`。
- Master 不需要像 Slave 一樣等待 parent/SoftPLL lock，因此不能用 Master 的
  `time_valid=1` 代替 Slave 同步證據。

### Slave

10 筆 accepted frame 的共同結果：

- `link_up=1`
- `wr_mode=3`
- `spll_locked=0`
- `time_valid=0`
- `servo_state=0`
- `foreign_count=1`
- `foreign_best=0`
- `parent_wr_config=3`
- `parent_is_wr=1`
- `parent_calibrated=1`

在有效樣本中，`pps_valid` 曾為 `1` 也曾為 `0`，因此不能宣稱 PPS 已穩定。

### Slave activity evidence

- `WR_SPLL_ACTIVITY` 的 `REF_COUNT/TAG_COUNT/IRQ_COUNT` 在觀測期間持續增加。
- 有效樣本的 `UCNT` 從 `0x000000ED` 增加到 `0x0000013A`。
- `CKO` 由 `0x008A4E41` 變化到 `0x001DB961`。
- `WR_LOCK` 仍為 `result=1、spll_locked=0、seq_state=4、delock_count=0`。

## Observation

1. Slave 沒有完全停止：link、parent、PTP 與 SoftPLL raw event 仍有活動。
2. Slave servo 有更新活動，但沒有取得 `PSTAT.locked=1`，也沒有把
   `time_valid` 拉高。
3. Slave 的 JTAG mailbox frame accepted 比率只有 `10/60`，因此本輪不能用
   每秒連續狀態轉移做強結論；但所有 accepted frame 的 lock/time-valid 結果一致。
4. 本輪沒有改變 SI5340、PHY、PTP filter 或 servo 演算法，因此不能由本輪
   證明任何一個硬體 register 是唯一根因。

## Conclusion

本輪證據支持：

> Slave 的 WR parent/PTP/SoftPLL/servo 路徑仍在活動，但目前仍停留在
> `spll_locked=0`、`time_valid=0`；兩張 DE5a 尚未被證明完成 White Rabbit
> 時間同步。

本輪不支持：

> 不能把 Master 的 `time_valid=1`、Slave 的 parent metadata 或 UCNT 增加，
> 單獨解讀成 Slave 已同步。

## Next Step

下一個硬體實驗只處理一個變因：建立 DPLL-only、只執行一次 transaction 的
隔離 bitstream，禁止 HPLL transaction。目的不是直接宣稱修正，而是確認
DPLL→N0→125 MHz reference 路徑是否會使目前可活動的 Slave runtime 掉線。
若 DPLL-only 仍能維持 link，再以正式 SI5340 register semantics 檢查
FINC/FDEC direction 與 FSTEPW；若掉線，先 rollback 到本輪 HPLL-only 版本。

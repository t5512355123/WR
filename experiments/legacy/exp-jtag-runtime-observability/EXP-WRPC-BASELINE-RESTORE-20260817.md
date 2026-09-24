# 實驗紀錄：恢復已知 baseline 硬體映像

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-BASELINE-RESTORE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/jtag-runtime-observability`
- 硬體 source commit：`b8d4c3d0526f0c2ca282600ef06648dd9f0af595`
- pain checkout：detached HEAD，切回 `b8d4c3d`

## 這次想驗證什麼

前一個 `TAG-PIPELINE` 診斷版雖然 compile/burn 成功，但雙板 runtime 沒有 `link_up=1`，結果不具可比性。本次只恢復前一個已完成 WR runtime 觀測的 known-good hardware image，確認兩片板回到可測量狀態。

## 相較 baseline 唯一修改

沒有新的硬體功能修改；本次只把兩片 FPGA 重新燒錄成 commit `b8d4c3d` 建出的映像。這是恢復操作，不是新的診斷變因。

## 建置與識別資料

- Quartus：17.0.0 Build 595（2017-04-25，Standard Edition）
- Master QSF SHA-256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- Slave QSF SHA-256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`968e3863f2622fe67d468327bec1d8832e955344f74973cde7e2bc19fcf7347d`
- Slave MIF SHA-256：`88f5dce3198e17ad75933e353c9852fdd43069ebc92b7e94734c0db9c270cfef`
- 本次重新產生 Master SOF SHA-256：`25567908d38334491b1b7e25f5bd3a8c890743d541e2a3cf72ab2031a54e33be`
- 本次重新產生 Slave SOF SHA-256：`0d4528b3cb2a26ae3c20b3cc395481441ebb81385c87c9e93ff4923aec63edc5`
- Master/Slave `TIMING_CLOSED=NO`；worst setup slack 分別為 `-2.988 ns`、`-2.751 ns`

## 燒錄結果

### Slave

- Cable：`DE5 [1-11.2]`
- SOF checksum：`0x30A4E4B6`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`
- 原始 log：`build/artifacts/EXP-WRPC-BASELINE-RESTORE-20260817/program_slave.log`

### Master

- Cable：`DE5 [1-11.1]`
- SOF checksum：`0x30A46080`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Programmer：`0 errors, 0 warnings`
- 原始 log：`build/artifacts/EXP-WRPC-BASELINE-RESTORE-20260817/program_master.log`

## JTAG / runtime 原始結果

兩片板燒錄完成後立即建立本紀錄，並完成短版 JTAG smoke test：

- 使用 `scripts/jtag/read_wb_timeseries_session.tcl`
- 目標：少量有效 frame，先確認兩片 `link_up=1`、PTP 計數與 Slave `wr_mode=3`
- 原始 log：`build/artifacts/EXP-WRPC-BASELINE-RESTORE-20260817/runtime_smoke.log`
- Master Programmer log SHA-256：`5E3E6C8F1BD821E3A1CF73281419EB9D868457B03439CCA423CF400D0BFA4AEF`
- Slave Programmer log SHA-256：`03195023DD1982292552131B02C06A8064E050A9C562B4B5702F8F950FF0EB50`
- JTAG smoke log SHA-256：`1AF42F5BDDB0B81F8ED1C5E48AA8AB935C9FD66DD8FB7623E7EE06AF083E4918`

## Observation

smoke test 的 Master 與 Slave 都是 `3/3` accepted，JTAG Tcl/SignalTap 成功且 `0 errors, 0 warnings`。

- Master：`link_up=1`、`time_valid=1`、`pps_valid=1`、`wr_mode=2`。
- Slave：`link_up=1`、`time_valid=0`、`pps_valid=1`、`wr_mode=3`、`spll_locked=0`。
- Slave 仍可看到 foreign master、PTP RX/TX 與 parent WR flags；因此 baseline 恢復後，問題仍集中在 Slave servo/SoftPLL 到 `time_valid` 的路徑。

## Conclusion

已恢復到可比較的 baseline：兩片板的 link 與 JTAG runtime 都正常；但這次恢復沒有解決 Slave `time_valid=0`，所以不能宣稱 White Rabbit synchronization 完成。這也表示前一個 pipeline 診斷版的雙板 `link_up=0` 是該診斷版/該次燒錄後的 runtime failure，而非恢復後仍持續存在的 baseline 狀態。

## Next Step

保留此 baseline；下一次只加入一個最小化的 `tags_p` source counter，並先用短 smoke test 確認兩片 `link_up=1`，再進行長時間觀測。不要一次加入多個 counter 或把 raw 欄位放進 frame-valid 判斷。

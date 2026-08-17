# EXP-WRPC-MASTER-SIGNAL-OBS-COMPILE-20260818

## 基本資訊

- 實驗名稱：Master `9f848ec` 加入 signaling observability 的 compile preflight
- Experiment ID：`EXP-WRPC-MASTER-SIGNAL-OBS-COMPILE-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`d512add`
- Quartus：Quartus Prime 17.0 Build 595
- 結果：**compile preflight 失敗，沒有產生可宣稱的新 Full Compilation，也沒有燒錄**

## 這次想驗證什麼

在不改變 `9f848ec` Master role、startup command 或任何同步參數的前提下，重新建立包含最新 signaling observability 的 Master build，之後才進行 Master-only A/B。

## 唯一變因

本輪沒有修改 source 或硬體設定，只執行既有建置 wrapper。建置過程先產生了新的 firmware MIF，接著在 Quartus clean 階段失敗。

## 執行命令

```text
cd /home/b10504072/04_WR
./scripts/pain/pain_build_jtag_master.sh
```

保存的原始輸出：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/compile.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/quartus_compile.log
```

Quartus log SHA-256：

```text
b8fe59a200d02bc5a1358574f110a6aa23ff17ce4e2b5b67af4b5ffc849f1d77
```

## 原始錯誤

```text
Error: Cannot clean project /home/b10504072/04_WR/DE5a_wr_master_jtag: this project doesn't exist
Error (23031): Evaluation of Tcl script .../qsh_clean.tcl unsuccessful
Error: Quartus Prime Shell was unsuccessful. 2 errors, 0 warnings
```

原因是 `scripts/build/build_jtag_master.sh` 在 repository root 執行：

```bash
quartus_sh --clean "$PROJECT.qpf"
```

但 `DE5a_wr_master_jtag.qpf` 位於 `quartus/jtag_runtime_diag/`，因此 Quartus clean 階段找不到專案。這是建置 wrapper 的工作目錄錯誤，不是 FPGA role 或 WR runtime 證據。

## 產物判定

firmware build 已重新產生 MIF：

```text
MIF SHA-256: 87c1fcc2de6098333e0af5e43dd6b9a9210b360210f2a771c9412529ac3d7cd0
```

但 Quartus 沒有完成 clean/compile；artifact 目錄中同時存在的 SOF 是先前檔案，不能視為本輪產生，也不能燒錄使用。

## Conclusion

本輪只證明建置腳本在 Quartus clean 階段有路徑 bug；沒有新增可驗證的硬體結果，也沒有改變或驗證 Master role。

## Next Step

只修正 `build_jtag_master.sh` 的 Quartus project path，使 clean 與 compile 都在 `quartus/jtag_runtime_diag/` 執行；修正後重新 compile，保存新的 QSF/SDC/MIF/SOF/hash 與 timing 結果。compile 成功後才考慮 Master-only programming，且仍保留歷史 `9f848ec` SOF 作為 rollback/A-B 基準。

## 修正後編譯結果（2026-08-18）

上述 path bug 已在 commit `7e0117c` 修正：Quartus clean 與 compile 現在都先切換到 `quartus/jtag_runtime_diag/`。修正後產生的 build identity 為：

- Git commit：`7e0117cc62e9dc23b9abb40be32315d55327a87b`
- Quartus：Version 17.0.0 Build 595，Standard Edition
- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`dc08f066668a2bc56fcf1c6a60cb1a3002ef674298549ef812f5b54d3336ea8c`
- SOF SHA-256：`51d76eddf8f8a56b743f5d9f83885274e1706960b6dd9a73be545922a3f93b76`
- Fitter：Successful
- Full Compilation：successful，0 errors，272 warnings
- Timing：尚未閉合；worst setup `-0.462 ns`、hold `-3.493 ns`

保存位置：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/master_fixed.mif
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/master_fixed.sof
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/quartus_compile_fixed.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/compile_fixed.log
```

原始 Quartus log SHA-256：

```text
48b15e963c9faa19623e999f31392f8c07cadffee5c189422a7e13feb884410c
```

### 證據限制

本次修正後 log 與輸出檔在等待所有 Quartus 程序結束後完成核對；但本輪早先曾意外啟動過重疊的 Quartus process，因此這組檔案應視為「成功產生且可追溯的診斷 build」，不應過度宣稱為完全隔離的首次 clean build。未來若需要正式 release，應先確保沒有任何 Quartus process，再從乾淨目錄執行一次單一 build。

### 編譯結論

這次只證明 `7e0117c` 的 Master signaling observability 版本可以通過 Quartus Full Compilation 並產生可燒錄候選 `.sof`；它尚未證明 Master role、JTAG runtime 或 White Rabbit synchronization。下一步仍必須以 Master-only 方式燒錄，並用唯讀 JTAG 驗證 `marker=B004`、`MODE=2`、`PTP=6`、`status=0xFF`、PTP RX/TX 有活動與 `link_up=1`。

## Master-only 燒錄結果（2026-08-18）

### 實驗資訊

- Experiment ID：`EXP-WRPC-MASTER-SIGNAL-OBS-PROGRAM-20260818`
- Git branch：`exp/master-9f-observability`
- 硬體來源 commit：`7e0117cc62e9dc23b9abb40be32315d55327a87b`
- 紀錄推送 commit：`a1e1817`
- 唯一變因：只將 `7e0117c` 產生的 Master observability `.sof` 燒錄到 Master；Slave 與其設定不變

### 這次想驗證什麼

確認加入最新 JTAG / signaling observability 的 Master bitstream 可以被 DE5a 正常設定，並在後續唯讀 JTAG 中檢查它是否仍保留歷史成功的 Master role：`MODE=2`、`PTP=6`、`status=0xFF`。

### 燒錄產物

- MIF SHA-256：`dc08f066668a2bc56fcf1c6a60cb1a3002ef674298549ef812f5b54d3336ea8c`
- SOF SHA-256：`51d76eddf8f8a56b743f5d9f83885274e1706960b6dd9a73be545922a3f93b76`
- Quartus Programmer checksum：`0x30A3363C`
- Quartus：Version 17.0.0 Build 595，Standard Edition

### 原始燒錄結果

```text
Info: Using programming cable "DE5 [1-11.1]"
Info: Using programming file .../master_fixed.sof with checksum 0x30A3363C
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

原始 programmer log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/program_master_fixed.log
SHA-256: ba9d31ff2367b9a05139e83ffc424e2899714af80aec8378eae86e47b27cca13
```

### 目前結論

證據已支持：Master bitstream 成功完成 JTAG configuration。這還不能等同於 Master role 或 White Rabbit synchronization 成功；JTAG/runtime 讀值尚未在本段紀錄中完成。

### Next Step

立即對目前已燒錄的 Master 執行唯讀 JTAG 觀察，同時保持 Slave 不變。至少保存 `marker`、`status`、`WDIAGS_MODE`、`WDIAGS_PTP`、link/time/pps valid，以及 PTP RX/TX 活動；只有五項 Master baseline 條件全部具備，才凍結 Master 並轉向 Slave。

## Master 診斷版燒錄後唯讀結果（2026-08-18）

- Experiment ID：`EXP-WRPC-MASTER-SIGNAL-OBS-RUNTIME-20260818`
- 實驗來源 commit：`7e0117cc62e9dc23b9abb40be32315d55327a87b`
- 觀測方式：不寫入設定的 `read_wb_timeseries_session.tcl 10 1000 3`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/runtime_master_fixed_10x1s.log`
- 原始 log SHA-256：`690e710096a5b641bce97f93adfb480eab5c7673b101473c74c5dd2ee11a7d9c`
- JTAG 程式結果：`SESSION_TIME_SERIES_DONE`、Tcl evaluation successful、SignalTap successful，0 errors、0 warnings

### 原始 runtime 證據摘要

Master cable `DE5 [1-11.1]` 在 10 個 sample 中反覆讀到：

```text
status_low=EF
time_valid=0
pps_valid=1
wr_mode=3
link_up=1
spll_locked=0
WDIAGS_PTP=9
```

在同一 session 中，另一片 `DE5 [1-11.2]` 也維持 Slave `wr_mode=3`、`WDIAGS_PTP=9`。Master 端 PTP TX counters 有變化，但這不能取代 Master role 證據；目前 `WR_SIGNAL` 仍未提供可宣稱的 Master/Slave signaling handshake 成功證據。

### Observation

加入目前 observability 的新 MIF/SOF 雖然成功設定 FPGA、link 也維持 up，但它沒有重現歷史成功 Master 的 `MODE=2 / PTP=6 / status=0xFF`。因此本輪唯一修改的診斷 build 不可作為 Master baseline，也不能據此修改或發明另一套 role 切換方法。

### Conclusion

本輪證據支持：「目前新診斷版的 firmware/startup 組合沒有保留歷史 Master role」。證據不支持「Master role 已成功」或「Slave 根因已確定」。為避免污染後續 Slave 實驗，下一步必須恢復已知成功的歷史 `9f848ec` Master SOF，再重新確認五項 Master baseline 條件。

### Next Step

只燒錄歷史 Master artifact `/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof`，不改 Slave、不改 role source；燒錄完成後立即保存 programmer log，再執行唯讀 JTAG。若恢復後得到 `marker=B004`、`MODE=2`、`PTP=6`、`status=0xFF`、`link_up=1` 且 PTP RX/TX 有活動，便凍結 Master，所有後續修改只針對 Slave。

## 恢復歷史 Master 基線的燒錄結果（2026-08-18）

- Experiment ID：`EXP-WRPC-MASTER-9F-RESTORE-20260818`
- Git/source baseline：歷史已驗證的 Master artifact，對應 `9f848ec` 成功基線；本次沒有重新編譯或修改 role source
- 唯一變因：將 Master 從失敗的 signaling-observability SOF 恢復成歷史成功 SOF；Slave 保持原狀
- SOF：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof`
- SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Quartus Programmer checksum：`0x30A46449`
- Quartus：Version 17.0.0 Build 595，Standard Edition

原始 programmer log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/program_master_restore_9f.log
SHA-256: 14b40e89c822748047d6f9c3d62f35d86709130a3d152b46ec41a30b8883b40c
```

原始結果：

```text
Info: Using programming file .../master.sof with checksum 0x30A46449
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

目前這段只證明歷史 SOF 已成功重新設定 Master；JTAG role/runtime 驗證待下一段唯讀 session 完成後再下結論。

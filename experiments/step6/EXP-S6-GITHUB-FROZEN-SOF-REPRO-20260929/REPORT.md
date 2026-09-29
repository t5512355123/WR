# EXP-S6-GITHUB-FROZEN-SOF-REPRO-20260929

日期：2026-09-29（Pain / Asia-Taipei）  
分支：`feat/file_cleanup`  
測試前來源 HEAD：`1b57d98465bc8dcb501fcc323b57b1630738903c`

## 目的

確認 GitHub 工作目錄的 Step6 frozen milestone 是否因複製/版本差異而無法通過，並以同一份 frozen SOF 做受控 runtime recovery。

本輪沒有修改 production RTL、firmware、控制參數或 SDB；沒有 power-cycle。唯一額外硬體動作是對 Slave 重新配置同一個 frozen SOF。雙板 scheduled-trigger / re-arm 僅寫入 Step6 測試模組的 target/ARM 暫存器。

## 版本與映像核對

`/home/b10504072/04_WR`（唯讀）與 `/home/b10504072/04_WR_github` 在測試前都位於同一 commit：`1b57d98465bc8dcb501fcc323b57b1630738903c`。

兩目錄內實際使用的 frozen milestone SOF 完全相同：

| Image | SHA-256 |
|---|---|
| Master `artifacts/milestones/step6_global_time/master.sof` | `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901` |
| Slave `artifacts/milestones/step6_global_time/slave.sof` | `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450` |

Quartus Programmer 首次配置及 Slave recovery reprogram 均記錄相同檔案 checksum：Master `0x30B18F28`、Slave `0x30B1E229`；配置成功，0 errors / 0 warnings。

注意：clone 內 `source/quartus/output_files_*` 的編譯輸出 SHA 分別為 Master `ebc6c219163bfceb7596b0d402328748616c2a8651109b32b3442c338bf95b2e`、Slave `76842d99d15487515f6dd5700e298f016991473b862f5422da0828bca25dd271`，與 frozen milestone SOF 不同。本輪硬體測試沒有燒錄這兩個編譯輸出；因此本報告驗證的是兩目錄相同的 frozen milestone 映像，不把 fresh-build 輸出宣稱為已驗證。

## 觀測結果

### 首次配置：Step6 未通過

首次使用上述 frozen SOF 後，Master 的 Step6 有效，Slave 的 Global-Time gate 未有效。Slave runtime 曾停在 `WAIT_OFFSET_STABLE`；連續觀測到的 phase offset 約在 `-3861 ps .. +2342 ps` 間變動，`TIME_VALID/PPS_VALID` 未成立。Link 與 JTAG/Wishbone transport 正常，沒有觀測到 reset-generation 改變。

### 同一 Slave SOF 重新配置後

Slave 重新燒錄的仍是完全相同的 `slave.sof`（Programmer checksum 仍為 `0x30B1E229`），沒有換映像、改參數或重啟主機。之後：

- Dashboard 立即顯示兩板 Global Time 有效。
- Slave 的 300 秒 Step5 time-series：301/301 samples accepted、301/301 valid、301/301 locked、0 invalid、0 unlocked，observer verdict 為 `STABLE_LOCK_CANDIDATE`。
- 300 秒後的 same-PPS capture：5 個共同 TAI 標籤全部 cycle 完全相同；最大差值 0 tick、0 mismatch。
- 第一次雙板 scheduled trigger：兩板都在 TAI `5086`、cycle `62500000` 觸發，fire count 各 1，時間戳差 0 tick（0 ns）。
- Re-arm 後第二次觸發：兩板都在 TAI `5140`、cycle `62500000` 觸發，fire count 各 2，時間戳差 0 tick（0 ns）。
- 最終 read-only dashboard：Master 與 Slave 均為 `Step6=PASS`；Slave 的 Helper/MainFreq/MainPhase/MainLock/PSTAT 均為 1，Global-Time validity 與 snapshot 均有效，link/reset 健康。
- 最終 dashboard 的摘要欄仍顯示 `Step5Result=LOCK_ACQUIRED_NOT_STABLE`，雖然本輪獨立的 301-sample/300-second series 通過 `STABLE_LOCK_CANDIDATE`。保留此差異，不以 dashboard 的即時摘要覆蓋 time-series 證據，也不宣稱 timing closure。

## 判讀

**這次差異不是 GitHub clone 複製錯誤或 frozen SOF 內容不同。** 同一 commit、同一對 SOF 在首次配置時出現 Slave runtime failure；對 Slave 重新配置同一 SOF 後，Step5 300 秒觀測、same-PPS 對時、兩次 dual-board trigger/re-arm 與最終 Step6 gate 都通過。最符合證據的判斷是 Slave 的 runtime/startup/servo 狀態具有時序依賴，重新配置使其重新初始化後恢復。

目前只能把問題定位到「板上執行狀態／啟動時序」，**尚未證明更底層的唯一根因**（例如特定 servo transition 或開機順序）。SFP live query 在 recovery 後顯示 EEPROM checksum 有效，但本機 SDBFS lookup 回傳 `rc=-1`、active calibration 為零；由於重配置後 Step6 仍通過，且缺少失敗前的配對讀值，不能把這項診斷直接認定為故障原因。

## 結論

`GITHUB_CLONE_FROZEN_STEP6_MILESTONE = PASS`，已在與唯讀 `04_WR` 相同的 frozen SOF 上重現，並完成 300 秒 Step5 series、same-PPS consistency、scheduled trigger 及 re-arm repeatability。

本結果證明 frozen milestone 可在 GitHub clone 的目標板上通過；不等於已驗證上述不同 SHA 的 fresh-build SOF。完整原始輸出保存在本目錄的 `raw/program/` 與 `raw/observe/`。

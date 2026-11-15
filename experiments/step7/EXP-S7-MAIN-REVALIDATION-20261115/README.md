# EXP-S7-MAIN-REVALIDATION-20261115

## 目的
距離上次實機驗證（2026-10-05／10-07）已超過一個月，期間 Pain 的 Quartus license 曾過期並於 2026-11-09 更新。
本實驗不改動任何 FPGA／韌體邏輯，以 `main`（`d57d408c`）主程式重新 build、compile、燒錄兩台 DE5a，
確認目前硬體狀態下兩台是否仍可同步並維持 `STATUS_TIME_VALID=1` 300 秒。

## 唯一的程式變更
- `scripts/program/program_{master,slave}.sh`：`sudo` 改為 `${QUARTUS_PGM_PREFIX-sudo}`。
  預設行為不變（仍使用 sudo）；USB-Blaster II 已由 udev 設為 0666，設定 `QUARTUS_PGM_PREFIX=` 可在無 sudo 的情況下燒錄。
- `scripts/build/current_experiment.env`：`CURRENT_EXPERIMENT` 指向本實驗資料夾。

## 步驟
1. Pain：`git pull`，切到本 branch。
2. `bash scripts/build/build_current.sh`
3. `bash scripts/build/compile_current.sh`
4. `QUARTUS_PGM_PREFIX= bash scripts/program/program_current.sh`（Slave → Master）
5. `bash scripts/monitor/verify_time_valid_300s.sh`（等待 TIME_VALID，最長 1800 秒，然後每板 303 秒）

## 通過條件
與 Step6 相同：兩台各自在 ≥300 秒採樣窗內每筆皆 `STATUS_TIME_VALID=1`。

## 結果
（實驗後填寫）

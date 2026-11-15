# EXP-S7-MAIN-REVALIDATION-20261115 實驗報告

## 結論
**PASS：兩台 DE5a 皆維持 `STATUS_TIME_VALID=1` 超過 300 秒（`PASS_TIME_VALID_300S`）。**
以 `main` 主程式（`d57d408c` 的 FPGA／韌體邏輯，未修改）在 2026-11-15 重新 build、compile、燒錄後，
距離上次實機驗證一個多月，兩台仍可完成 WR 同步並取得 TIME_VALID。

## 環境
- 主機：Pain；Quartus Prime Standard 17.0 Build 595（license `LR-209097`，2026-11-09 更新）
- 板卡：Master `DE5 [1-11.1]`、Slave `DE5 [1-11.2]`；其中一片仍維持 Step7 拔離 PCIe、接 SMA 的配置
- 原始碼：branch `exp/step7-main-revalidation-20261115`，commit `62dfa78e`
  （相對 `main` 僅改燒錄腳本可省略 sudo、以及 `CURRENT_EXPERIMENT` 名稱）
- 控制參數：Slave 粗調起點 512、WR servo `/2 + /12`、60/120 ps（與 Step7 相同，未變更）

## 步驟與結果
| 步驟 | 指令 | 結果 |
|---|---|---|
| 韌體 build | `bash scripts/build/build_current.sh` | `CURRENT_FIRMWARE_BUILD=PASS` |
| Quartus compile | `bash scripts/build/compile_current.sh` | `CURRENT_COMPILE=PASS`（09:09 完成） |
| 燒錄 | `QUARTUS_PGM_PREFIX= bash scripts/program/program_current.sh` | Slave → Master 皆 `Programmer was successful`，各約 18–19 秒 |
| TIME_VALID 300 秒 | `bash scripts/monitor/verify_time_valid_300s.sh` | 兩台 `PASS_TIME_VALID_300S` |

### TIME_VALID 取得時間
燒錄完成後輪詢 9 次（elapsed 0 → 102 秒），約 **102 秒**內兩台同時出現 TIME_VALID，遠低於 1800 秒上限。

### 300 秒採樣
| 板卡 | 採樣數 | 跨度 | 最大間隔 | TIME_VALID 列 | 無效列 | 判定 |
|---|---:|---:|---:|---:|---:|---|
| Master 1-11.1 | 1193 | 302962 ms | 257 ms | 1193/1193 | 0 | PASS |
| Slave 1-11.2 | 1192 | 302755 ms | 256 ms | 1192/1192 | 0 | PASS |

兩台依序各觀測一個完整 303 秒窗；PPS_VALID、snapshot、Step1 link 在全部採樣中也都成立。

### 時序（未收斂，與先前相同）
| 設計 | 最差 slack | 負 slack 項數 |
|---|---:|---:|
| Master | −0.219 ns | 1 |
| Slave | −0.187 ns | 1 |

### SOF SHA-256
- Master：`dac9ad0a8234a433717e6d9408d31fcfe47af292b66efd3fc2d33dceca79e478`
- Slave：`d2c61e2026e8ea3bfe0610ca934af293ea5e6c5f732349dc9e58b34017133e33`

## 限制
- 本實驗只驗證 TIME_VALID 維持能力，**不代表** CKO 已穩定在 ±60 ps、實體 PPS 邊緣精度、時序收斂，或每次冷啟動都成功。
- 本次未做 CKO 時間序列分析與示波器量測。

## 下一步建議
先前（2026-10-04）關閉相位修正時，CKO 估計值峰對峰約 0.93 ns；
10-05 觀測 Slave CKO 峰對峰 949 ps、標準差 171 ps。下一步應判斷這是**真實時鐘相位抖動**還是 **CKO 估計／timestamp 量測雜訊**：
1. 用示波器同時量 Master／Slave PPS（或 CKO 輸出）邊緣時間差的分布，與同時段 JTAG 讀到的 CKO 估計值比對。
2. 若實體邊緣差遠小於 CKO 估計的跳動，則問題在量測鏈（timestamp／相位偵測），應從估計器下手，而不是繼續調 servo gain。

## 證據
- `analysis/20261115T011038Z-current-time-valid-300s.json`
- `raw/observe/`（readiness 輪詢與 303 秒完整紀錄，含 sha256）
- `raw/program/`、`raw/build/`

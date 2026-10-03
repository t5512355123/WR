# Current-image TIME_VALID-only 300s — completed, then stopped

## 結論

本輪依使用者 2026-10-03 最新指示，把驗收目標改為 **TIME_VALID 保持 300 秒**，不以 CKO <60 ps / <=120 ps 作為額外驗收門檻。只觀測當時正在運行的映像，沒有修改程式、編譯、燒錄、調參、切換角色、reset 或斷電。

**Master 通過；Slave 未通過，因此雙板 TIME_VALID 300s 未成立。** 本輪已停止，不因失敗而重試或開始下一個實驗。

| Board | 觀測樣本跨度 | 樣本數 | TIME_VALID=1 | TIME_VALID=0 | 結果 |
|---|---:|---:|---:|---:|---|
| Master DE5 [1-11.1] | 302921 ms | 1192 | 1192 | 0 | PASS_TIME_VALID_300S |
| Slave DE5 [1-11.2] | 302887 ms | 1192 | 758 | 434 | TIME_VALID_300S_NOT_ESTABLISHED |

兩板最大樣本間隔皆為 257 ms。完整捕捉、板號、樣本順序與 DONE 計數核對均通過，沒有 capture error；Slave 的失敗不是讀取程式未完成，而是原始紀錄確實包含 TIME_VALID=0。

## 本輪目標與限制

- 唯一通過信號：每板完整 >=300000 ms 觀測窗的所有 `STATUS_TIME_VALID` 樣本均為 1。
- 每板至少 301 筆；樣本間隔必須為正且 <=1000 ms；不得刪除無效樣本、截取較好片段或平均掉失效。
- PPS、snapshot、link、PLL locks、TAI/cycles 只作診斷，不增加通過門檻。
- 僅改本輪驗收目標，沒有停用映像內既有的 validity protection，也沒有強制寫入 valid bit。
- 此結果是取樣下的 bit retention，不能證明每一個硬體 clock 都有效、CKO 精度、物理 SMA skew 或雙板同時的 300 秒窗口。
- 既有 observer 依序觀測 Master、Slave，各 303 秒；不是同一個同時觀測窗。

## 執行與映像身分

- Pain checkout / Laptop checkout：`7dccbebda69545183832203dde0422a4552bafb2`，branch `feat/file_cleanup`。
- 目前 output metadata 的 compile source：`359984a54d41a488006050c6c406fd43f2fd3fbe`。
- 本輪 capture 開始：`2026-10-03T21:00:16+08:00`；capture / verdict 結束：`2026-10-03T21:10:24+08:00`。
- Observer process exit：0；analyzer exit：1，對應正確的 NOT_ESTABLISHED 結果，不是 transport crash。
- 上一輪已完成的 programming provenance 所對應 SOF：Master `cb6db8c0967ac2c083850ffd03abafd4c58e8c99e0e2b041195e056a847fe8fa`；Slave `b122cd448be472ae05e36dfd30728251776b48beea69b2b21fefa859945eb943`。

Output metadata / disk artifact identity 不是硬體已載入 SOF bytes 的獨立 readback。本輪沒有新的 programming event，不應將 checkout HEAD、compile source 與新燒錄事件混為一談。

唯一 capture：

```sh
timeout --signal=INT --kill-after=5s 900s \
  /mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t \
  scripts/jtag/read_step6_global_time_observability.tcl 303000 250 "" \
  > experiments/step6/EXP-S6-CURRENT-IMAGE-TIME-VALID-300S-ONLY-20261003/raw/observe/current-time-valid-303s.log 2>&1
```

既有 analyzer 未修改，在 Pain 與 Laptop 各自重算相同原始檔：

```sh
python3 scripts/analysis/step6_time_valid_300s.py \
  experiments/step6/EXP-S6-CURRENT-IMAGE-TIME-VALID-300S-ONLY-20261003/raw/observe/current-time-valid-303s.log \
  --required-duration-ms 300000 --max-sample-gap-ms 1000 \
  --minimum-samples 301 --boards 1-11.1,1-11.2
```

Laptop 與 Pain JSON 結果語意完全一致。執行前既有 validator 的 7 項離線測試通過。

## 診斷讀值，不作根因推論

Master 與 Slave 的 `PPS_VALID` 都為 1192/1192；Step1 link-ready 亦皆為 1192/1192。Slave 的 PPS snapshot valid / snapshot time-valid 為 693/1192，live time-valid 為 758/1192；兩者是不同時間點的信號，不可混用為本輪驗收。

本輪沒有同窗 CKO 或 servo-state 紀錄，因此不能由這個 capture 斷言 TIME_VALID 失效必定由 CKO、jitter、Ki 或某個 servo branch 造成。既有 firmware protection 未改動，這不等於已證明哪項 protection 在本輪觸發。

## 原始紀錄與完整性

已從 Pain 原樣回傳 Laptop，未裁切或改寫 raw；下列 SHA256 均與 Pain 一致：

| 檔案 | SHA256 |
|---|---|
| `PLAN.md` | `6dfb5870904c75f40636046001fd3e9494148d54bae0088c1c1959a97e7684e0` |
| `raw/observe/current-time-valid-303s.log` | `c6bc9eba253b9fc830e948e97aa5799b4cf95827a49e6f1ee18223fc71c4e5f8` |
| `analysis/time-valid-300s.json` | `4df253fafd1733aaea7568099a4a837b8ac611d28161412359735a790c3619e4` |
| observer `scripts/jtag/read_step6_global_time_observability.tcl` | `8b00e98cb0b74c43e59638135f342c4629204e0bbff5b25387ab3e243862fdca` |
| analyzer `scripts/analysis/step6_time_valid_300s.py` | `3fe5387b309a5b42c22b248155ac52349ae98fac76b77e589c8578574c44e54b` |

Raw 與 result 各保留對應 `.sha256` sidecar。

## 停止狀態

硬體 observer 已結束；後續僅保存與發布這份紀錄，沒有再次讀取硬體、重燒、重試、顧問詢問、下一輪候選、milestone promotion 或 main merge。原有其他 build/output 修改與未發布實驗檔保留；frozen milestones 與 `/home/b10504072/04_WR_archive_step6_pass/` 未修改。

本輪最終分類：`TIME_VALID_300S_NOT_ESTABLISHED`。依使用者指示停止實驗，不把舊的 strict-offset 目標標記為完成。

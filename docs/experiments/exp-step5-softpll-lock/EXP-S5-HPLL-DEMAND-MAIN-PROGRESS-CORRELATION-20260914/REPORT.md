# EXP-S5-HPLL-DEMAND-MAIN-PROGRESS-CORRELATION-20260914

## Verdict

`DEMAND_RESULT = INCONCLUSIVE`  
`STEP5_COMPLETE = NO`  
`MERGE_APPROVED = NO`

本輪是依「實作WR Astra」最新建議執行的唯讀關聯觀測，不是功能修改輪。唯一正式硬體 capture 使用 source commit `eb3d1a515b8076f9f8d518180b92131d990fd70a`，目標為 Pain 的 `DE5 [1-11.2]` Slave。沒有修改 timeout、PI、production C/RTL，也沒有觸發 Helper PI snapshot 或開第二個 reader。

## Procedure and provenance

- Laptop 修改並 push：`eb3d1a515b8076f9f8d518180b92131d990fd70a`
- Pain pull/fetch 後切到相同 commit：通過
- Master full build：0 errors，timing closed = NO
- Slave full build：0 errors，timing closed = NO
- Master program：成功，0 errors / 0 warnings
- Slave program：成功，0 errors / 0 warnings
- WB preflight：352/352 三路比對、0 timeout、0 invalid、0 address cross-contamination，`JTAG_WB_DIAGNOSTIC_PATH = TRUSTED`
- Observer：single session，`gap_ms=100`，smoke 5 samples，實際時間上限 240000 ms；實際因資料停止條件於約 28.5 s 結束

SOF SHA-256：

```text
Master  4e68250bc0e30c1637d3536e1db0f8987209d2e3c4506c833cdd31a40512db01
Slave   2ece5c7964b7c513bd32bcdd14755a375c9932cfd33739d3849b33c0022d921c
```

原始檔案位於本資料夾；Pain 端 bundle SHA-256 為：

```text
e00be1a1078612885ec1420ca2089517ee5a2f6963480f315be8e50476a9bde0
```

## Observer validity

正式修正版結果：

```text
SMOKE_VALID = 1
SAMPLES = 85
CORRELATION_SAMPLES = 82
HELPER_MEASUREMENT_VALID = 85
POSITION_VALID = 82
L2_VALID = 85
SAMPLE_WINDOW = 0..28228 ms
STOP_REASON = PERSISTENT_GROUP_INVALID_OR_BANK_CONFLICT
```

第 83、84、85 筆的 42/43/44/49 position/accounting group 連續失效，因此依實驗規則停止；這不是把不完整資料硬延長成 240 秒。Boot generation 維持 `1 → 1`，CPU/WR/SI reset shadow 也沒有變化。

修正前的第一次 observer 嘗試也保留在 `observer-initial-invalid.log`。它因舊版一次讀取 23 個 Main seqlock 欄位而在 live publisher 下無法形成穩定窗口；該次不作硬體 verdict。修正版將 Main causal core 縮為一致性必要欄位，optional 欄位仍讀出但不宣稱同一 publication，之後 smoke 才通過。

## Observed facts

在 82 筆可信 correlation samples 中：

```text
Main trace valid                 85/85
Main trace update_count          0 → 0
Main sample_n_advanced           0
Main enabled/frequency/phase     0/0/0
Helper measurement valid         85/85
Helper measurement residual      82/82 (observer residual flag)
Helper target/applied            5/5 in all 82 valid position groups
Helper position residual         0/82
Helper pending                   0/82 (instantaneous status)
Helper lock                      0 throughout the valid Main samples
```

L2 的 counter 在 capture 末段開始變化，但這些變化發生在 position group 已失效的尾端；因此不能拿它們與 Main update 宣稱單 cycle 因果。相同理由，`HELPER_ADMISSION_ELIGIBLE` 保留為 `UNKNOWN`；不得把 `HELPER_MAX_WAIT=1` 解讀成仲裁沒有阻塞。

## Interpretation

本輪足以確認觀測器 transport 與大部分資料組可用，也確認此 session 中 Main 沒有「先持續更新、再因 Helper 失鎖而停止」的可信事件序列：Main 從 capture 開始就是 disabled、`update_count=0`。Helper measurement 的殘差／輸出 rail 訊號存在，但可信 position group 顯示 target 與 applied 尚未分離；在 normal-demand counters 開始變化的尾端，position group 又連續失效。因此無法判定是 Helper admission、服務阻塞，或 Main phase acquisition 的 downstream 問題。

依 Astra 的診斷規則，本輪為 `INCONCLUSIVE`，不是 Step5 PASS，也不自動調參。下一個功能修改仍需等待新的、資料一致的因果觀測；本輪完成報告後停止。

## Evidence files

- `observer-retry.log`：正式修正版 capture
- `observer-initial-invalid.log`：修正前失效嘗試，僅作觀測器修正證據
- `preflight-wb-runtime-retry.log`：正式 capture 前 WB transport preflight
- `build-master-retry.log`, `build-slave-retry.log`
- `program-master-retry.log`, `program-slave-retry.log`
- `sof-sha256-retry.txt`
- `remote-metadata.txt`


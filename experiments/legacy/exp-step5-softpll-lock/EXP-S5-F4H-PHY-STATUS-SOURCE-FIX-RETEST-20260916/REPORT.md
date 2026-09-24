# EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916

日期：2026-09-16（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
實驗目的：修正 F4G 將 WB `WDIAGS_CTRL` 誤當成 PHY status 的觀測來源，重新取得可信的 direct JTAG probe0 PHY gate，並確認 Step 5 的真正 inactive boundary。

## Verdict

```text
SOURCE_SCHEMA = PASS
PHY_SOURCE_FIX_CONFIRMED = YES
DIAGNOSTIC_PASS = YES
CLASSIFICATION = MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

本輪不是 Step 5 pass。它成功證明 F4H 的 PHY source mapping 正確，而且正式
120 秒資料窗內 Master/Slave 的 direct probe0 PHY gate 都通過；在此可信前提下，
Main service 持續前進，但 phase lock 從未成立。因此 F4G 的 `PHY_SOURCE` 疑點
已排除，Step 5 的目前邊界是 Main phase acquisition/lock，而不是 PHY gate。

## 實驗範圍與唯一修改

只修改 host-side observer、offline replay、測試與文件：

- `WDIAGS_CTRL_RAW` 獨立記錄，只解碼 DATA_VALID bit 0 與 DATA_SNAPSHOT bit 8。
- 以既有 single-reader context 的 `probe_read 0` 保存完整 64-bit
  `PHY_STATUS_PROBE0_RAW`。
- 以 required mask `0x000000CF` 解碼 bit 0、1、2、3、6、7，並記錄
  `PHY_STATUS_SOURCE=JTAG_PROBE0`、role/source ID、instance 0、width 64、failure bits。
- invalid/timeout/non-hex/short frame 只判 UNKNOWN；舊 F4G 沒有 probe0 的 raw 不回填、
  不升級。

Production C/RTL、PI/gain/boost、threshold、timeout/retry、bootstrap、arbiter、
mailbox、reset 與控制映像內容均未修改。本輪沒有送出 mode/reinit/control write，
也沒有做實體斷電；只重新編譯並燒錄 observer 所需的既有 runtime image。

完整 source/mapping 定義見 [phy_status_source_mapping.md](phy_status_source_mapping.md)。

## Laptop → GitHub → Pain

```text
SOURCE_COMMIT = 898b041afa2fcd6ca48a84eb7326eebc419ac4a3
PAIN_CHECKOUT = 898b041afa2fcd6ca48a84eb7326eebc419ac4a3
RUN_ROLE = f4h
MASTER_TARGET = DE5 [1-11.1]
SLAVE_TARGET = DE5 [1-11.2]
```

Pain 端 Master 與 Slave clean build 均成功，Quartus 17.0 Build 595；兩次
programmer 均回報 `Configuration succeeded`、`0 errors, 0 warnings`。

```text
MASTER_SOF_SHA256 = fe73fe54e702e974ed4452e517751ebf8a1cbcd93d7a19207839ed13e3a9bed7
SLAVE_SOF_SHA256  = 30c78989caa9496b5a34bc771f4c0a238ebd9c271045f55c6a7d4963c13df7bc
TIMING_CLOSED = NO
```

`TIMING_CLOSED=NO` 是本次 build 的 implementation caveat；不把它誤判成
本輪的 Step 5 verdict。

## Smoke

短 smoke 使用同一 observer、同一 reader 與同一 source schema，實際通過：

```text
SMOKE_RC = 0
SOURCE = JTAG_PROBE0
PHY_STATUS_WIDTH_BITS = 64
PHY_GATE_REQUIRED_MASK = 000000CF
Master PHY_STATUS_VALID = 1, PHY_GATE_FAILURE_BITS = NONE
Slave  PHY_STATUS_VALID = 1, PHY_GATE_FAILURE_BITS = NONE
PSTAT_LOCKED = 0
```

Smoke 只驗證讀取與格式，不作 Step 5 判定。

## Formal capture

觀測命令為：

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 240 500 "" 120000 130000 f4h
```

正式窗正常到達目標時間，沒有觸發 timeout、transport failure 或 terminal stop：

```text
session_elapsed_ms = 120090
target_duration_ms = 120000
hard_duration_ms = 130000
slave_cycles = 100
master_samples = 34
run_end_reason = TARGET_REACHED
stop_reason = NONE
single_reader = PASS
observer_step5_pass = NO
```

## Offline replay evidence

獨立 replay 輸出位於 [verdict.json](analysis/replay-898b041-f4h-jtag-runtime/verdict.json)、
[bins.csv](analysis/replay-898b041-f4h-jtag-runtime/bins.csv)、
[counter_support.csv](analysis/replay-898b041-f4h-jtag-runtime/counter_support.csv)、
[phy_gate.csv](analysis/replay-898b041-f4h-jtag-runtime/phy_gate.csv) 與
[cycles.csv](analysis/replay-898b041-f4h-jtag-runtime/cycles.csv)。

| 證據 | 結果 |
|---|---:|
| Source schema rows | 134 |
| Direct probe0 valid rows | 134/134 |
| PHY required-gate pass rows | 134/134 |
| PHY gate failure rows | 0 |
| Slave / Master source rows | 100 / 34 |
| Fresh 10-second bins | 12/12 qualified |
| Slave Helper locked records | 100/100 |
| Slave Main frequency-locked records | 97/100 |
| Slave Main phase-locked records | 0/100 |
| Slave phase-qualified records | 96/100 |
| Slave PSTAT locked records | 0/100 |
| Slave terminal/reset stop records | 0 |
| Main completed trusted delta | 84216 |
| Helper completed trusted delta | 10369 |
| Main failed trusted delta | 0 |
| Helper failed trusted delta | 0 |

Service counters each have 99 trusted same-field deltas over approximately
`435..119420 ms`; Main and Helper both progressed. This supports service liveness,
not same-cycle causality and not closed-loop lock.

All 12 ten-second bins show trusted Main/Helper completion and start deltas, while
`phase_locked_count=0` in every bin. The resulting diagnosis is therefore:

```text
MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK
```

這個結果不支持「PHY source 仍然錯誤」、也不支持「Step 5 已通過」。`PSTAT_LINK=1`
與 `PSTAT_LOCKED=0` 必須維持分開解讀；frequency lock 與正的 service counter 也
不能取代 phase lock。

## Reproducibility artifacts

Pain 原始資料與執行紀錄完整保留於
[raw/attempt-898b041-f4h-jtag-runtime](raw/attempt-898b041-f4h-jtag-runtime)，
壓縮封存為
[attempt-898b041-f4h-jtag-runtime/](raw/attempt-898b041-f4h-jtag-runtime/)。

```text
OBSERVER_LOG_SHA256 = ecda10c94009513d27129f06217b51c600990f663680a4d87ab9b559809b7f84
SMOKE_LOG_SHA256    = 0b7b9889169a6a22d57f7796f7f05d896bebb2e8cede6134a58f0a1583353b95
RAW_ARCHIVE_SHA256  = a525dfd0202ed42e1c1eccb4234d4505bc4c286ac89ebeff2d63b3b149d87352
```

## Verification

```text
F4H_TESTS_PASS = 11 tests
F4G_TESTS_PASS = PASS
PY_COMPILE = PASS
TCL_SOURCE_DIFF_CHECK = PASS
```

## Next boundary

F4H 已完成它的 source-validity 診斷目的，但沒有達成 Step 5。下一輪只能針對
可信 PHY gate 下的 Main phase path 做新的單一假設驗證；在沒有新的控制變因、
明確 replay 證據與 fresh-program reproducibility 之前，不調參、不放寬 gate、
不 merge 到 main。

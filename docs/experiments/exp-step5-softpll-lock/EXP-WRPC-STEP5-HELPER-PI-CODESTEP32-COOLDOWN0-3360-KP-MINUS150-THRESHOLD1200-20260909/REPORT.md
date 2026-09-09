# EXP-WRPC-STEP5-HELPER-PI-CODESTEP32-COOLDOWN0-3360-KP-MINUS150-THRESHOLD1200-20260909

## 判定

本輪不是 Step5 pass，且觀測有效性本身退化：

```text
Step 1 PHY / Link              PASS
Step 2 Endpoint / PTP          PASS
Step 3 WR Handshake             PASS
Step 4B Slave SoftPLL Startup   PASS
Step 5 Closed-loop Lock         NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY   HELPER_LOCK
```

Preflight 的 Step1/2/3/4B 與 JTAG configuration 成功，但 600-sample PI audit 只有 287/600 frame 可用；不能用這輪資料宣稱 Step5。

## 實驗目的與唯一 firmware 變更

上一輪 cooldown=0、64 code/physical step 已進入穩定 near-zero operating point，但仍有 24 次 ±1200 band exit。本輪只把 Slave top-level：

```text
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP: 64 -> 32
```

並同步把 observer 的 position-accounting 常數改為 32。cooldown=0、`kp=-150`、`ki=-1`、threshold=1200、3360 reverse bootstrap、phase guard、Main、DMTD、PTP、PHY 與 reset policy 均保持不變。

## Build / program provenance

```text
SOURCE_COMMIT = 69d2bf64c0055e0bdf3e1e3678a69dac36562677
QUARTUS       = Intel Quartus Prime Standard 17.0.0 Build 595
MASTER_COMPILE= Full Compilation was successful; 0 errors, 299 warnings
SLAVE_COMPILE = Full Compilation was successful; 0 errors, 301 warnings
```

兩張板均以 JTAG configuration succeeded 燒錄成功，preflight 結果：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED   = YES
STEP4B_RESULT    = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

SOF SHA-256：

```text
master = b7eb86363ee7747937b25fe22ee22ee4c4c383be1b46b15a20fc31a3ed7f4036
slave  = 6f337f3c8906bef2aa0162e5c46b815cff1c89c49b08719c1c538e44ce2d358f
```

## 600-sample PI audit

```text
SAMPLES                       = 600
VALID_FRAMES                 = 287
INVALID_FRAMES               = 313
PI_TRACE_PRESENT             = 287
PI_SNAPSHOT_REJECTS          = 0
PI_ACCOUNTING_FAILS          = 0
MEASUREMENT_COHERENCE        = PASS
POSITION_ACCOUNTING          = CHECK
ATOMIC_SNAPSHOT_TRANSPORT_V3 = FAIL（因 frame validity/position context）
```

有效 frame 的控制結果已明確比 64-code baseline 差：

```text
HELPER_ERROR_MEAN            = 10517.8780488
HELPER_ERROR_RMS             = 134385.678616
HELPER_ERROR_MAX_ABS         = 150000
FRACTION_ABS_ERROR_LE_1200   = 0.348432055749 %
RAW_ERROR_MIN/MAX            = -607121 / 683997
LOW_RAIL_FRACTION            = 33.798 %
HIGH_RAIL_FRACTION           = 29.617 %
NO_RAIL_FRACTION              = 36.585 %
RAIL_TO_RAIL_CYCLE_COMPLETE  = 1
HELPER_LOCKED_FINAL           = 0
MAIN_ENABLED_FINAL            = 0
PSTAT_LOCKED_FINAL            = 0
RESET_STABLE                  = PASS
```

最前幾筆就出現 rail 往返，而上一輪 64-code image 在相同 cooldown=0 條件下是 error RMS 614、95.67% 在 ±1200 且全程無 rail。32-code 不是穩定化方向，反而使 normal transaction/plant tracking 進入無法可靠 accounting 的狀態。

## 結論與下一步

本輪否定「單純減半 DCO transaction code step 就能消除 Helper band exit」的假設。`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=32` 應回復 64；cooldown=0 則保留，因為上一輪已證明它把系統帶入可重現的 near-zero operating point。

下一輪回復 64 code，然後只處理另一個明確的 software boundary：目前固定 60 秒 phase guard/reseed 與實際 `bootstrap_done` 沒有同步。應讓 Helper phase history/PI admission 在 bootstrap 真正完成後再重置並開始累積，避免 guard 在 coarse bootstrap 尚未完成或在不同 startup elapsed 時刻釋放，造成 lock detector 每次 fresh run 的初始狀態不同。不得同時改 PI gain 或 threshold。

## 原始證據

本資料夾 `raw/` 保存：

```text
raw/preflight.log
raw/observer-pi-600.log
raw/program-master.log
raw/program-slave.log
raw/source-commit.txt
raw/sof-sha256.txt
raw/raw-transfer.tgz
```

Pain 端 archive SHA-256：

```text
1c026b0a4c4df002e68f41fad66cfbeedbceab04f7a5fcb5265dd38565f3baf7
```

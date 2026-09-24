# EXP-WRPC-STEP5-HELPER-PI-COOLDOWN0-3360-KP-MINUS150-THRESHOLD1200-20260909

## 判定

本輪仍不是 Step5 pass：`STEP5_CHAIN_RESULT = NOT_COMPLETE`。

```text
Step 1 PHY / Link              PASS
Step 2 Endpoint / PTP          PASS
Step 3 WR Handshake             PASS
Step 4B Slave SoftPLL Startup   PASS
Step 5 Closed-loop Lock         NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY   HELPER_LOCK
```

Step1/2/3/4B、量測 accounting、PI snapshot math 與 JTAG transport 都通過；但 Helper 未達成持續 lock，不能宣稱 Step5。

## 實驗目的與唯一 firmware 變更

上一輪 audit 發現實際 Slave image 仍是 `cooldown=32`，因此本輪只把 Slave top-level 的：

```text
STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 32 -> 0
```

其他 PI、bootstrap、DCO step、phase guard、Main、DMTD、PTP、PHY 與 reset policy 均未修改。這是為了取得真正 no-cooldown 的隔離 A/B。

## Build / program provenance

```text
SOURCE_COMMIT = f6c9acd12fe7dbeccdf531b0a4f506ff8491bd29
QUARTUS       = Intel Quartus Prime Standard 17.0.0 Build 595
MASTER_COMPILE= Full Compilation was successful; 0 errors, 299 warnings
SLAVE_COMPILE = Full Compilation was successful; 0 errors, 301 warnings
```

兩張板均以 JTAG configuration succeeded 燒錄成功。

SOF SHA-256：

```text
master = b75acd72caea79061b3c1d9d8cfd9410ff21304992ea95169953d64e7cc6650f
slave  = d0f12212db0e3713af72ba0e33d1a8d368c043086c7e16c5b85a6d98acba8d6f
```

新 image 的 preflight：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED   = YES
STEP4B_RESULT    = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

## 600-sample coherent PI audit

觀測 window 為 59.9 秒，600/600 frame 有效：

```text
VALID_FRAMES                  = 600
PI_TRACE_PRESENT              = 600
PI_SNAPSHOT_REJECTS           = 0
PI_ACCOUNTING_FAILS           = 0
PI_OUTPUT_MISMATCH_FAILS      = 0
ANTI_WINDUP_VIOLATIONS        = 0
MEASUREMENT_COHERENCE         = PASS
POSITION_ACCOUNTING           = PASS
TRANSACTION_ACCOUNTING        = PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3  = PASS
```

與上一輪 cooldown=32 的結果相比，控制迴路已進入非常不同且明顯較好的 operating point：

```text
HELPER_ERROR_MEAN             = 23.4266666667
HELPER_ERROR_RMS              = 614.157354972
HELPER_ERROR_MIN/MAX          = -2171 / 1977
FRACTION_ABS_ERROR_LE_1200    = 95.6666666667 %
FREQ_ERROR_MEAN               = 0.838333333333
FREQ_ERROR_RMS                = 10.8674590713
FREQ_ZERO_CROSSINGS           = 143
LOW_RAIL_FRACTION             = 0.000 %
HIGH_RAIL_FRACTION            = 0.000 %
NO_RAIL_FRACTION              = 100.000 %
ERROR_BAND_EXIT_EVENTS        = 24
ACTUATOR_HUNTING              = PASS（未完成 rail-to-rail cycle）
```

最早 sample 即在實際 target/applied 附近啟動，沒有上一輪的 rail collapse：

```text
sample=1  HELPER_ERROR=300    PI_OUTPUT=58085 TARGET=58113 APPLIED=58117
sample=2  HELPER_ERROR=323    PI_OUTPUT=58274 TARGET=58300 APPLIED=58309
sample=3  HELPER_ERROR=-964   PI_OUTPUT=58267 TARGET=58233 APPLIED=58245
sample=8  HELPER_ERROR=88     PI_OUTPUT=58309 TARGET=58312 APPLIED=58309
```

觀測結尾：

```text
HELPER_ERROR_FINAL             = -220
HELPER_OUTPUT_FINAL            = 61971
TARGET_FINAL                   = 61967
APPLIED_FINAL                  = 61957
HELPER_LOCKED_FINAL            = 0
HELPER_LOCK_COUNT_FINAL        = 0
MAIN_ENABLED_FINAL             = 0
PSTAT_LOCKED_FINAL             = 0
```

因此 cooldown=0 明確改善了 startup operating point 與 actuator 行為，但 60 秒內仍有 24 次離開 ±1200 band，尚未形成 Helper lock；Main/PSTAT 尚未被允許啟動。

## Reset / upstream stability

```text
SPLL_INIT_COUNT_FIRST/FINAL    = 1 / 1
SPLL_DELOCK_COUNT_FIRST/FINAL  = 0 / 0
RESET_BOOT_GENERATION_DELTA    = 0
RESET_CPU_DELTA                = 0
RESET_WR_CORE_DELTA            = 0
RESET_SI_CONFIG_DELTA          = 0
RESET_STABLE                   = PASS
```

## 結論與下一步

cooldown=32 確實是前一輪 PI 高 rail/大誤差行為的重要誘因；cooldown=0 使 phase error 降到 RMS 614，並使 actuator 全程離開兩端 rail。但 `kp=-150`、HPLL 每 physical step 64 code 的離散校正仍造成約 24 次 band exit，因此 Helper lock detector 沒有累積到 locked。

下一輪只改 Slave top-level 的 `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP`：`64 -> 32`，保留 cooldown=0、`kp=-150`、`ki=-1`、threshold=1200、3360 reverse bootstrap。目標是減半每次 DCO transaction 的相位擾動，檢驗是否能把 ±1200 band exit 消除並讓 Helper lock 建立。若仍未鎖，再處理 phase guard/reseed 與 bootstrap completion 的同步問題。

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
348094b15d430c3f75fd041fdc690210283e065f913d57395718bdff066bb708
```

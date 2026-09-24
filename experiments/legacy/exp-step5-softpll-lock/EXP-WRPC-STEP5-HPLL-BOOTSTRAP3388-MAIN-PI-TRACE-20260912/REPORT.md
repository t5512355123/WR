# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-PI-TRACE-20260912

## 判定

Step 5：NOT COMPLETE（尚未通過）。

本輪完成 Main PI trace 的 3600-sample diagnostic observation。Main frequency lock 成立，但 Main phase lock 從未成立；因此不能宣告 Step 5 PASS，也不能 merge。

## 實驗目的

前一輪 Helper PI trace 已確認 snapshot transport 可靠，且 Helper 在啟動後曾進入高側 PI clamp。本輪依 Astra 建議改觀察 Main phase branch，定位 Main phase lock=0 是由輸出飽和、phase error 超出 threshold，還是 lock transition 失效造成。

唯一程式變更是將既有 read-only Main PI prelock observer 的 experiment label 與 bootstrap metadata 從 3360 對齊目前 baseline 3388。沒有修改 SoftPLL 控制器、PI gain 或 lock semantics。

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：e4c75d3b9e0500828b8e450aa743087b7d33594e
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：5a3812a1979fb0bc351bf7d72bf3069c97121c54b15607bdd66af3ddf46cb80a
- Slave SOF SHA256：365f034c2358ccffc6c328dcda02a14918bd96ebf6178b0838168a04d4cc3576

## Programming 與 upstream

依 Master -> 45 秒 -> Slave 順序燒錄完成。等待 120 秒後的 settled preflight：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3 / Step4B：PASS
- Helper lock：1
- Main enabled：1
- Main frequency lock：1
- Main phase lock：0
- PSTAT lock：0
- first inactive boundary：MAIN_PHASE_LOCK

因此本輪 Main observer 是 upstream-ready 的有效 Step5 diagnostic window。

## 3600-sample Main PI observation

Observer 設定：

- samples = 3600
- cadence = 100 ms
- bootstrap = 3388
- Main Kp = 150
- Main Ki = 1
- Main PI shift = 12
- Main PI bias = 32768
- Main frequency threshold = 50
- Main frequency lock samples = 50
- read-only Main trace overlay

完整摘要：

    SAMPLES=3600
    ELAPSED_MS=6611880
    TRACE_VALID=3600
    TRACE_UNIQUE=397
    TRACE_DEDUP_SKIPPED=3203
    FRAME_VALID=3330
    INVALID=0
    FREQ_ERROR_SAMPLES=397
    FREQ_ERROR_MEAN=171.367758186
    FREQ_ERROR_RMS=1428.96678338
    FREQ_ERROR_MIN=25
    FREQ_ERROR_MAX=16431
    FREQ_ERROR_FIRST=47
    FREQ_ERROR_FINAL=38
    FRACTION_ABS_FREQ_ERROR_LE_50=0.67758186398
    PRELOCK_ERROR_MISMATCHES=9
    MEASUREMENT_FAILS=4
    PI_SAMPLES=397
    PI_LOW_RAIL_FRACTION=0.0
    PI_HIGH_RAIL_FRACTION=0.0
    PI_NO_RAIL_FRACTION=0.989924433249

Lock and stability result：

    MAIN_ENABLED_FRACTION=0.989924433249
    MAIN_FREQ_LOCK_COUNT_MAX_SEEN=50
    MAIN_FREQ_LOCK_COUNT_FINAL=50
    MAIN_FREQ_LOCK_COUNT_MAX_FINAL=50
    MAIN_FREQ_LOCKED_EVER=1
    MAIN_FREQ_LOCKED_FINAL=1
    MAIN_PHASE_LOCKED_EVER=0
    MAIN_PHASE_LOCKED_FINAL=0
    MAIN_LOCKED_EVER=0
    MAIN_LOCKED_FINAL=0
    HELPER_LOCKED_EVER=1
    HELPER_LOCKED_FINAL=1
    HELPER_LOCK_COUNT_MAX=64330
    HELPER_LOCK_COUNT_FINAL=1000
    PSTAT_LOCKED_EVER=1
    PSTAT_LOCKED_FINAL=0
    SPLL_DELOCK_FIRST=0
    SPLL_DELOCK_MAX=234
    SPLL_DELOCK_FINAL=0
    RESET_STABLE=PASS
    BOOT_GENERATION_FIRST=1
    BOOT_GENERATION_FINAL=1

Main PI final state：

    MAIN_DREF_DT_FINAL=16391
    MAIN_DOUT_DT_FINAL=16429
    MAIN_FREQ_ERROR_FINAL=38
    MAIN_PRELOCK_ERROR_FINAL=-760
    MAIN_PI_UNCLAMPED_FINAL=10906
    MAIN_PI_OUTPUT_FINAL=10906
    MAIN_PI_CLAMP_SIDE_FINAL=0
    MAIN_PI_KP_FINAL=150
    MAIN_PI_KI_FINAL=1
    MAIN_PI_SHIFT_FINAL=12
    MAIN_PI_BIAS_FINAL=32768
    MAIN_FREQ_THRESHOLD_FINAL=50
    MAIN_PI_Y_MIN_FINAL=5
    MAIN_PI_Y_MAX_FINAL=65531
    MAIN_PI_ANTI_WINDUP_FINAL=1
    MAIN_PI_X_FINAL=7838
    TELEMETRY_RESULT=FAIL
    STEP5_COMPLETE=NO

## Interpretation

本輪排除「Main phase lock=0 是因為 PI output 觸及 rail」：

- Main PI output 長時間位於合法範圍，high/low rail fraction 都是 0。
- Main frequency lock 已成立且最終 frequency error=38，在 frequency threshold 50 內。
- 但 Main PI input 最終為 7838，遠大於 phase lock threshold 1200；因此 phase lock detector 沒有理由累積到 1000 個合格樣本。
- Main phase lock ever/final 都是 0，Main lock 與 PSTAT lock 也都維持 0。
- reset stable=PASS，boot generation 沒有增加；問題不是 runtime reset。

這把目前瓶頸收斂為 Main phase operating point/phase authority：頻率已經接近，但實際 phase error 仍約數千 tics，且 PI output 約 10906 的工作點沒有把 phase error 拉入 ±1200 admission band。這不是再調 Helper Kp/Ki 可以直接解決的證據。

另外，observer 的 3600 次輪詢中只有 397 個新的 Main trace publication，其餘是重複 frame；這是低速 firmware trace publication，不影響「phase lock ever=0」的結論，但說明完整 closed-loop 判定仍應以原本 coherent observer 與 lock shadow 共同確認。

## 下一輪

下一輪只選一個功能變因：針對 Main phase actuator operating point 做受控的 startup bias/target A/B，保留 Main Kp=150、Ki=1、phase threshold=1200、lock samples=1000 與 Helper baseline 不變。變更前先固定以本輪 trace 的 Main PI input=7838、output=10906 作為 baseline，變更後必須同時確認：

- Main PI input 進入 ±1200，而不是只看到 frequency lock。
- Main phase lock counter 可累積並維持。
- Main/PSTAT lock、position accounting、reset stability 與 continuous 300 秒全部通過。

不要修改 phase threshold 來掩蓋實際 phase error，也不要再盲掃 Helper PI gain。

## 原始資料

- Raw archive：raw-observer.tar.gz
- Raw archive SHA256：caa1fa92c5584978e96491d7741341d3ff9c4e95d0cd87c833f9fe36bbf6e28c
- archive 內含 preflight、settled preflight、build、program 與 Main PI observer logs。

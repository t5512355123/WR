# EXP-WRPC-STEP5-MAIN-FREQ-PRELOCK-3360-CODESTEP64-KP-MINUS150-HELPERTHRESHOLD2000-20260909

## 判定

本輪 **不是 Step5 PASS**，因此不具備 merge 到 `main` 的條件。

```text
Step1 PHY / Link              PASS
Step2 Endpoint / PTP          PASS
Step3 WR Handshake             PASS
Step4B Slave SoftPLL startup   PASS
Helper lock gate               PASS
Main enabled                   PASS
Main frequency lock            NOT COMPLETE
Step5 Closed-loop Lock         NOT COMPLETE
```

目前第一個未通過邊界是 `MAIN_FREQUENCY_LOCK`。

## 本輪目的與流程

本輪只修正 Main-frequency pre-lock observer 的過時實驗標籤，控制 firmware 參數不變。依流程在 laptop 推送 observer commit 後，Pain 重新 pull、重建 Master/Slave firmware、Quartus compile、重新燒錄，fresh boot 後先跑不會 claim PI overlay 的 preflight，再執行 Main-frequency observer。

Source commit：

```text
a723d58d64a7c238a958f074cff0d625cbd7901d
```

SOF SHA-256：

```text
Master 54d8af0edafb185e9a9c99904704872329b33674d995b75eb474efa7829fbc2b
Slave  47cde482cc3a81b98a8f55b919a5154b2b6210c9657d10a57fdafe4e8be04ad7
```

Build、program、preflight 與 observer exit code 均為 0。

本輪實際控制條件：

```text
bootstrap_steps             = 3360
HPLL physical step          = 64
normal_hpll_cooldown_loads  = 0
Helper kp / ki              = -150 / -1
Helper threshold / samples  = 2000 / 1000
Main kp / ki                = -1100 / -30
Main frequency threshold    = 50
Main frequency lock samples = 50
```

## Preflight

```text
Master WDIAGS_PTP       = 6 MASTER
Slave WDIAGS_PTP        = 9 SLAVE
parentIsWRnode           = 1
STEP4B_ALLOWED           = YES
STEP4B_RESULT            = PASS
```

## Main-frequency observer 結果

觀測名義為 600 samples/100 ms；因為每次 probe 需要多個 Wishbone read，實際 elapsed 約 108.99 秒。Main overlay 在 PI snapshot 之前讀取，因此本輪的 Main trace 是有效來源。

```text
TRACE_VALID                    = 600
TRACE_UNIQUE                  = 58
TRACE_DEDUP_SKIPPED           = 542
FRAME_VALID                    = 573
INVALID                       = 0
MEASUREMENT_FAILS              = 0
```

Main frequency trajectory：

```text
MAIN_DREF_DT                  = 16394 (final)
MAIN_DOUT_DT                  = 17452 (final)
MAIN_FREQ_ERROR               = 1058 (final)
MAIN_FREQ_ERROR_MEAN          = 1059.5345
MAIN_FREQ_ERROR_RMS           = 1059.5944
MAIN_FREQ_ERROR_MIN/MAX       = 1039 / 1098
FRACTION_ABS_FREQ_ERROR_LE_50 = 0%
```

Main PI/actuator trajectory：

```text
MAIN_PI_KP                    = -1100
MAIN_PI_KI                    = -30
MAIN_PI_BIAS                  = 32768
MAIN_PI_OUTPUT_FINAL           = 65531
MAIN_PI_CLAMP_SIDE_FINAL       = 1
MAIN_PI_HIGH_RAIL_FRACTION     = 100%
MAIN_PI_LOW_RAIL_FRACTION      = 0%
MAIN_FREQ_LOCK_COUNT_MAX       = 0
MAIN_FREQ_LOCKED_EVER          = 0
MAIN_FREQ_LOCKED_FINAL         = 0
MAIN_ENABLED_FRACTION          = 100%
```

最後的 coherent sample 仍為：

```text
MAIN_PRELOCK_ERROR             = -21160
MAIN_PI_X                      = -21560
MAIN_PI_OUTPUT                 = 65531
MAIN_ENABLED                   = 1
HELPER_LOCKED                  = 1
MAIN_FREQ_LOCKED               = 0
MAIN_PHASE_LOCKED              = 0
MAIN_LOCKED                    = 0
PSTAT_LOCKED                   = 0
```

## 健康度與穩定性

```text
SPLL_DELOCK_COUNT              = 0
BOOT_GENERATION                = 1 -> 1
CPU_RESET                      = 1 -> 1
WR_CORE_RESET                  = 0 -> 0
SI_CONFIG_DROP                 = 0 -> 0
RESET_STABLE                   = PASS
HELPER_LOCKED_EVER/FINAL       = 1 / 1
HELPER_LOCK_COUNT_MAX/FINAL    = 1000 / 1000
PSTAT_LOCKED_EVER/FINAL        = 0 / 0
TELEMETRY_RESULT               = PASS
STEP5_COMPLETE                 = NO
MERGE_APPROVED                 = NO
```

## 解讀

這輪確認 Helper gate 已正常跨過，Main 也確實被啟動；所以問題已從「Helper 無法進 Main」縮小為 Main frequency branch。

Main frequency error 維持正值約 1059，遠高於 50-tic lock threshold；同時 Main PI output 在整個 observer 期間都是 high rail=65531，lock counter 始終為 0。這不是單純觀測時間不夠，也不是 Helper、DCO transaction 或 reset instability：Helper 已 locked、Main 已 enabled，且控制 transport/health 沒有異常。

目前最有力的假設是 Main pre-lock actuator polarity/plant response 不一致，或 Main DAC high-rail 對目前的正 frequency error 沒有提供負回授。這仍需 A/B 證明，不能只從 high-rail 現象直接宣告 polarity bug。

## 下一輪建議

維持 Helper threshold=2000 與所有 HPLL/SI5340 設定不變，做一個單一 Main-frequency polarity A/B：將 `CONFIG_WR_NODE` 下 Main frequency PI 的 `kp/ki` 符號反轉，讓同一個正 frequency error 由 high-rail 驅動改為 low-rail 驅動。觀測時保留 Main-frequency overlay，先確認 `MAIN_FREQ_ERROR` 是否由約 +1059 朝 0 移動；若移動方向正確，再等待 50 samples lock 與後續 Main phase/PSTAT lock。若仍 rail 且 error 不動，下一步就應回到 Main DAC/plant wiring 或 `DAC_SEL`/actuator path 的 source audit，而不是繼續掃 gain。

在 Main frequency、phase、PSTAT 及穩定窗口全部通過前，不應宣告 Step5 或 merge 到 `main`。

## Raw evidence

Pain 原始 build、program、preflight、Main-frequency observer log 與 source/SOF checksum 已保存於同資料夾的 `raw/`；同一份 raw archive 已保存於 `artifacts/`。

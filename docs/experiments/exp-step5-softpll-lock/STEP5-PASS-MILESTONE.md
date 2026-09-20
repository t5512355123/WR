# Step5 Functional PASS Milestone

## 判定

依 2026-09-20 的專案決定，Step5 的 functional milestone 以同一個可信的
coherent observer window 同時確認下列四個結果為 PASS：

```text
HPLL / Helper lock        = 1
Main frequency lock      = 1
Main phase lock          = 1
PSTAT.locked              = 1
```

在這個 functional milestone 定義下，Step5 已通過：

```text
STEP5_FUNCTIONAL_PASS    = PASS
STEP5_PASS_MILESTONE     = 2026-09-20
TIMING_CLOSED             = NO  # timing closure 不作為本 milestone 的 gate
```

這是對 2026-09-12 硬體 evidence 的正式 policy reclassification。原始實驗報告
仍保留當時的 `STEP5 = NOT PASS`，因為它採用的是「完整 lock chain 連續 300 秒」
舊門檻；本文件不改寫原始報告，只依 2026-09-20 的 milestone 定義重新判定：

```text
HELPER_LOCK_FINAL       = 1
MAIN_FREQ_LOCK_FINAL    = 1
MAIN_PHASE_LOCK_FINAL   = 1
PSTAT_LOCK_FINAL        = 1
STEP5_FUNCTIONAL_PASS   = PASS
```

`FULL_CHAIN_300S`、lock reacquisition 次數與 `TIMING_CLOSED` 都是附帶觀測／
implementation status，不是本 functional PASS 的必要條件。

這個 milestone 不宣稱 300 秒連續 lock、零 lock reacquisition、零 timing
violation 或完整 Quartus timing closure；那些屬於後續 stability / implementation
hardening 工作。

## 選定的最穩定 functional 版本

本 milestone 固定在已完成實體 build、program 與 coherent observation 的版本：

| 欄位 | 值 |
|---|---|
| Experiment | `EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912` |
| Validated source commit | `17f20ad32c619212133e6134205cf017212d7dd8` |
| Build branch | `exp/step5-softpll-lock` |
| Main SOF SHA-256 | `d58873136bfa41afdf40225421f5a26f6602187ab7fe0547820dacc92b3eae98` |
| Slave SOF SHA-256 | `3cda3f9b65db4b388f3f1087d7b225227541f12599e7b230e3a1dd5e5ea7a555` |
| Main Kp / Ki | `+300 / +1` |
| Helper Kp / Ki | `-150 / -1` |
| Bootstrap | `3388` |
| Actual HPLL cooldown | `8` loads; the folder name's `cooldown0` is historical provenance, not the fitted image setting |

這是目前已保存候選中最穩定的一個：完整 lock chain 最長 113.791 秒；其他
同系列候選的最長完整 chain 約為 12.685 秒與 18.006 秒。這裡的「最穩定」是
根據已保存的同類 observer evidence 比較，不是新的硬體重測宣稱。

## 同一 coherent window 的證據

來源報告：

[`EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912/REPORT.md`](EXP-WRPC-STEP5-TRUE-BASELINE-ACCOUNTING-FIX-3388-KP-MINUS150-COOLDOWN0-20260912/REPORT.md)

```text
SAMPLES                         = 3600
ELAPSED                         = 427965 ms
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
MEASUREMENT_COHERENCE           = PASS
POSITION_ACCOUNTING             = PASS
RESET_STABLE                    = PASS

HELPER_LOCKED_SEEN              = 2918
HELPER_LOCKED_FINAL             = 1
MAIN_ENABLED_FINAL              = 1
MAIN_FREQ_LOCKED_FINAL          = 1
MAIN_PHASE_LOCKED_FINAL         = 1
MAIN_LOCKED_FINAL               = 1
PSTAT_LOCKED_FINAL              = 1

FULL_CHAIN_MAX_SECONDS          = 113.791
SPLL_DELOCK_COUNT_FIRST         = 0
SPLL_DELOCK_COUNT_FINAL         = 0
RESET_BOOT_GENERATION_DELTA     = 0
RESET_CPU_DELTA                 = 0
RESET_WR_CORE_DELTA             = 0
RESET_SI_CONFIG_DELTA           = 0
```

## 重要限制

觀測窗仍記錄到 `ERROR_BAND_EXIT_EVENTS=393`、`LOCK_COUNT_FALL_EVENTS=160`、
`SPLL_DELOCK_COUNT_MAX=5`，且 `FULL_CHAIN_300S=0`。因此這個文件只把版本標成
**Step5 functional PASS milestone**；若未來要宣稱 long-duration stable lock，仍需
另行完成穩定性實驗，不能回頭修改本次 evidence。

同樣地，2026-09-20 的 timing audit 仍顯示 `TIMING_CLOSED=NO`。這不會撤銷本
functional milestone，但必須在 release / implementation 文件中保留。

2026-09-20 的新鮮重驗證另記於
`EXP-S5-FUNCTIONAL-MILESTONE-PSTAT-LOCK-REVALIDATION-20260920/REPORT.md`。
該輪使用新編譯的 SOF，未重現這組歷史 lock evidence，因此不取代本 milestone
的 exact source／SOF provenance，也不能把該輪結果誤寫成新的 PASS。

## Merge provenance

本文件與主說明文件放在最新的 `exp/step5-softpll-lock` branch；functional
milestone 的可重現硬體版本仍以 `17f20ad32c619212133e6134205cf017212d7dd8`
與上列 SOF hashes 為準。較新的 timing/diagnostic commits 不得被倒填成這次
硬體觀測所使用的 source identity。

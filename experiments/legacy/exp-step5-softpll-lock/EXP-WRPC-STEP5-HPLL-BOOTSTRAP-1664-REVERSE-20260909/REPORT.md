# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-1664-REVERSE-20260909

## 判定

本輪以 1024/3072 的 phase bracket 內插出 1664-step reverse/FINC operating
point，並同步修正 observer 的 bootstrap boundary。第一次 Slave→Master
載入與 power-cycle recovery 後仍未建立 link；最後以同一組 SOF 做
Master→Slave recovery，preflight 通過後取得正式觀測。Step5 仍未完成，不能
merge。

```text
SOURCE_COMMIT = 0b32c62d3fa97dd90be792312fffaffa4d168136
INITIAL_PREFLIGHTS = UPSTREAM_INVALID
VALID_PREFLIGHT = preflight-4-master-first-recovery
STEP1_TO_STEP3 = PASS (valid recovery window)
STEP4B = PASS (valid recovery window)
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 變更

```text
Slave STEP5_BOOTSTRAP_STEPS: 5632 -> 1664
Slave STEP5_BOOTSTRAP_REVERSE: 1 (FINC, unchanged)
observer bootstrap_steps: 5632 -> 1664
```

其餘 PI、HPLL step size、page/mask sequence、Main、DMTD、PTP、PHY 與 reset
policy 均未改變。

## Build / program provenance

Pain 從本輪 source 完整編譯 Master/Slave，兩個 full compilation 均成功：

```text
MASTER_SOF_SHA256 = 7e7efd4c62bf605437bca9c9c4e95411298dde31e8b4dade9bbcceee039302e0
SLAVE_SOF_SHA256  = 9369644706826959bf0b721ec237848a611b0629f025a29d75cdc4f6db0843e6
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.192
TIMING_CLOSED = NO
```

初次 Slave→Master program 與 power-cycle 後的同順序 program 都成功，但
upstream link 未恢復；同一組 SOF 之後採 Master→Slave recovery，兩端仍為
configuration succeeded、0 errors、0 warnings，並在 recovery preflight 通過。

## Valid upstream window

recovery 後的有效 preflight 確認：

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
WR_RX_SIGNAL_DEBUG = LOCK
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

前面三個 preflight 的 `RX delta=0`、`LISTENING` 與 `UNKNOWN` 屬於 upstream
recovery evidence，不納入 Step5 控制判定。

## Coherent closed-loop observation

valid recovery window 後完成 1200 筆、約 135.2 秒 observer；RTL 與 observer
均使用 1664 bootstrap boundary，所有 accounting 與 reset stability 通過：

```text
SAMPLES = 1200
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
POST_BOOTSTRAP_BASELINE_SET = 1
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_STABLE = PASS
SPLL_DELOCK_COUNT_FIRST/MAX/FINAL = 0/0/0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

1664 沒有落在前兩個 coarse point 的 phase basin，反而回到高 rail：

```text
FREQ_ERROR_MEAN = -446.7075
FREQ_ERROR_RMS = 446.836195751
FREQ_ERROR_MIN = -478
FREQ_ERROR_MAX = -416
FREQ_ERROR_FIRST = -447
FREQ_ERROR_LAST = -467
PRECLAMP_FIRST = -197832660
PRECLAMP_FINAL = -434697787
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 1.0
NO_RAIL_FRACTION = 0.0
HELPER_LOCK_COUNT_MAX = 3
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 1664
BOOTSTRAP_DONE_FINAL = 1
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`PRECLAMP_ERROR` 持續變得更負，表示 phase error 正在累積而非進入 lock
window；`HELPER_LOCK_COUNT_MAX=3` 遠低於 10000，不能視為短暫 lock。這輪
因此否定了「只靠 1024/3072 線性內插即可同時命中 frequency 與 phase」的
假設，也顯示 operating point 對 recovery/startup 時序敏感。

## 下一輪

目前更可能的瓶頸不是 coarse 數值本身，而是 bootstrap 與 Helper phase
accumulator 的時序耦合：coarse steps 執行時 Helper 已在累積 phase，完成後
PI 只看到飽和的歷史誤差。下一輪應先把 bootstrap completion 與 Helper phase
measurement 做明確同步／重置，再以 3072 附近的 frequency point 重新閉迴路；
不應繼續盲掃 bootstrap 數值或 PI。

## Raw evidence

本資料夾 `raw/` 保存 build、program、power-cycle/recovery、preflight、
coherent observer 與 SOF hash。遠端 raw archive SHA-256：

```text
056052dca20f615c012156b3b41e8842a3e48112b23524dace5ca2328d8dd0e3
```

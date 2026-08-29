# EXP-WRPC-STEP5-HPLL-POLARITY-AB-20260830

## 結論

本輪在兩次 fresh-program 的相同 Slave SOF 上，對 forced HPLL burst 只切換 polarity selector：

```text
POLARITY_A: forced_rt_dir = hpll_dir
POLARITY_B: forced_rt_dir = ~hpll_dir
```

結果如下：

```text
STEP4B = PASS
JTAG_TRIGGERED_8_STEP_BURST_A = PASS
JTAG_TRIGGERED_8_STEP_BURST_B = PASS
ACTUATOR_TO_MEASUREMENT_COUPLING = OBSERVED
POLARITY_CAUSALITY = NOT PROVEN
STEP5_CLOSED_LOOP_LOCK = NOT PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

A/B 都確實執行了 8 個 forced HPLL requests，且 helper update 都在 burst completion 後被觀察到；但兩者的 pre-clamp error 都仍往負方向移動，沒有形成可判定的相反 response。因此不能把 B 的「負漂移較小」解讀成 polarity 已證明，也不能宣稱 Step5 完成。

## 固定版本與產物

```text
branch = exp/step5-softpll-lock
source/SOF/reader commit = af60b03809e263dea045ebe424e2064d0ef161f1
experiment = EXP-WRPC-STEP5-HPLL-POLARITY-AB-20260830
controller burst size = 8
```

兩次執行前都重新 program Slave，以清除前一輪 sticky state 與 counters。兩次使用相同的 Slave SOF：

```text
Slave SOF SHA256 = 2ffe1287763ef0cee0a0dea8b9671e8a1e219ad802725ba8af77321e91b0cbe4
programmer = success, 0 errors
TIMING_CLOSED = NO
```

## Acceptance：A/B 直接交易證據

兩個方案的 `B_BEFORE -> B001` 都符合 branch5 指定 acceptance：

```text
                             A              B
POLARITY_SOURCE             0              1
POLARITY_ACTIVE after burst 0              1
DELTA_STEP                  8              8
DELTA_BURST_TRIGGER_COUNT   1              1
DELTA_FORCED_PENDING_COUNT  8              8
DELTA_FORCED_COMPLETED_COUNT 8            8
DELTA_RT_STATE_ENTER_COUNT  8              8
DELTA_RUNTIME_START_COUNT  24             24
DELTA_BUS_DONE_COUNT        24             24
```

這證明 selector 已被正確送入 burst path，而且 A/B 的唯一 functional difference 確實生效。

## A：`forced_rt_dir = hpll_dir`

`B_BEFORE -> B001`：

```text
PRECLAMP_ERROR: -31671172 -> -36312973
DELTA_PRECLAMP_ERROR = -4641801
DELTA_RAW_TAG = -414729
TAG_DELTA: 15244 -> 15248
DELTA_HELPER_UPDATE_COUNT = 4098
```

burst completion 後第一個 helper-update sample：`B001 -> H007`。

```text
PRECLAMP_ERROR: -36312973 -> -40949717
DELTA_PRECLAMP_ERROR = -4636744
DELTA_HELPER_UPDATE_COUNT = 4098
TAG_DELTA: 15248 -> 15269
```

## B：`forced_rt_dir = ~hpll_dir`

`B_BEFORE -> B001`：

```text
PRECLAMP_ERROR: -579685846 -> -583723584
DELTA_PRECLAMP_ERROR = -4037738
DELTA_RAW_TAG = -416874
TAG_DELTA: 15401 -> 15370
DELTA_HELPER_UPDATE_COUNT = 4061
```

burst completion 後第一個 helper-update sample：`B001 -> H005`。

```text
PRECLAMP_ERROR: -583723584 -> -587769809
DELTA_PRECLAMP_ERROR = -4046225
DELTA_HELPER_UPDATE_COUNT = 4061
TAG_DELTA: 15370 -> 15385
```

## 判讀

A 與 B 的 pre-clamp response 都是負值：

```text
A burst window:       -4,641,801
B burst window:       -4,037,738
A helper window:      -4,636,744
B helper window:      -4,046,225
```

B 的負漂移幅度較小，但沒有反向朝 0 的 response；因此 A/B 尚未證明 polarity causality，也不能選定一個 polarity 作為 functional fix。背景 drift 或 actuator-to-measurement latency/映射仍可能混入這個觀測窗。

## 穩定 runtime dashboard

B fresh-program、burst 及等待 20 秒後的穩定重讀為：

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4B Slave SoftPLL Startup pass
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

HELPER locked=0 cnt=0/10000 threshold=200
MAIN enabled=0 locked=0
PSTAT_locked=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此使用目前最新穩定 evidence 判定：Step4B 已完成；Step5 尚未完成。舊的畫面若仍顯示 Step4 error，應視為不同時間點或未穩定完成 handshake 的 stale/transient snapshot，不覆蓋本輪固定 SOF 的重讀結果。

## 原始證據

- [polarity A raw log](raw/EXP-WRPC-STEP5-HPLL-POLARITY-AB-20260830/polarity-a/jtag-polarity-a.log)
- [polarity B raw log](raw/EXP-WRPC-STEP5-HPLL-POLARITY-AB-20260830/polarity-b/jtag-polarity-b.log)
- [stable dashboard after polarity B](raw/EXP-WRPC-STEP5-HPLL-POLARITY-AB-20260830/polarity-b/dashboard-after-wait.log)
- [bounded-burst reader](../../../scripts/jtag/read_step5_jtag_hpll_bounded_burst_ab.tcl)


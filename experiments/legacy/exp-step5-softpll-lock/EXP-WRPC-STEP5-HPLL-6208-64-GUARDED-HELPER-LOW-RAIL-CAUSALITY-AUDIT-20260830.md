# EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830

## 判定

本輪完成的是 Step5 的 Helper/PI 低軌因果稽核，不是 Step5 lock pass。

```text
STEP4B_COMPLETE = YES
LOW_RAIL_CAUSALITY_AUDIT = PASS
LOW_RAIL_SATURATION = CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = CONFIRMED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 實驗範圍

- Branch: `exp/step5-softpll-lock`
- Baseline: `a53a7ea`
- Telemetry commit: `32830b5ef67d1d0fabdf9d9772b9a4c0734e4400`
- Functional settings preserved: idempotent guard enabled, bootstrap `6208`, code-per-physical-step `64`, `kp=-150`, `ki=-2`, threshold `200`, `lock_samples=10000`
- Experiment: `EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830`

目的，是用唯讀 telemetry 區分「PI 偏置/設定點問題」與「致動器輸出範圍或需要負向控制權限」。本輪沒有修改控制參數、DMTD、phase setpoint、Main PLL、sequencer、reset、額外 FINC/FDEC 或 guard 行為。

## 唯讀觀測實作

在 WDIAGS persistent map `0x158..0x1dc` 新增 Helper/PI trace packet，使用 epoch seqlock 發布下列欄位：raw error、LD error、integrator before/new/after、prop term、pre-round、unclamped output、上下限、clamp side、final output、lock state 與相關設定值。`task-diags` 以約 500 ms 的寬封包更新頻率發布，避免 35 個 Wishbone 欄位讀取跨越 measurement epoch；控制迴路本身未改動。

JTAG observer 只接受 coherent epoch，並驗證：

```text
RAW_ERROR = (TAG + P_ADDER) - P_SETPOINT
PI_FINAL_OUTPUT = clamp(PI_UNCLAMPED_OUTPUT, Y_MIN, Y_MAX)
```

## Build / program 證據

兩張板均以 commit `32830b5` fresh build、fresh program：

- Slave: Full Compilation successful, 0 errors；SOF checksum `0x30B42C35`
- Master: Full Compilation successful, 0 errors；SOF checksum `0x30B897E6`
- Programmer：Slave 與 Master 均 0 errors、0 warnings
- Quartus 保留既有 timing caveat：`TIMING_CLOSED=NO`

完整輸出：

- [Slave build info](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/build_info_jtag_slave-final.txt)
- [Master build info](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/build_info_jtag_master-final.txt)
- [Slave build log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/build_jtag_slave-final.log)
- [Master build log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/build_jtag_master-final.log)
- [Slave program log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/program-jtag-slave-final2.log)
- [Master program log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/program-jtag-master-final2.log)

## 有效 1800 筆觀測

有效 full run 為 179.9 秒：

```text
SAMPLES=1800
VALID_FRAMES=1800
INVALID_FRAMES=0
PI_TRACE_PRESENT=1800
PI_SNAPSHOT_REJECTS=233
PI_ACCOUNTING_FAILS=0
PI_OUTPUT_MISMATCH_FAILS=0
ANTI_WINDUP_VIOLATIONS=0
MEASUREMENT_COHERENCE=PASS
POSITION_ACCOUNTING=PASS
TRANSACTION_ACCOUNTING=PASS
RESET_STABLE=PASS
```

`PI_SNAPSHOT_REJECTS=233` 是 coherent read 的重試次數，不是最後被接受的 invalid frame；最後仍為 `1800/1800` 有效 frame。先前立即讀取、尚未暖機或舊 image 的 smoke logs 不列入結論；本輪正式證據是 [pi-trace-1800.log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/pi-trace-1800.log)，暖機後 smoke 則是 [pi-trace-smoke-final.log](raw/EXP-WRPC-STEP5-HPLL-6208-64-GUARDED-HELPER-LOW-RAIL-CAUSALITY-AUDIT-20260830/pi-trace-smoke-final.log)。

## 結果與因果判定

```text
RAW_ERROR_SAMPLES=1800
RAW_ERROR_MEAN=517703409.882
RAW_ERROR_MIN=352081485
RAW_ERROR_MAX=893702633
RAW_ERROR_POSITIVE_FRACTION=100.0
HELPER_ERROR_MEAN=150000.0
UNCLAMPED_BELOW_MIN_SAMPLES=1800
LOW_RAIL_SAMPLES=1800
LOW_RAIL_FRACTION=100.000
HIGH_RAIL_SAMPLES=0
NO_RAIL_FRACTION=0.000
LOW_RAIL_SATURATION=CONFIRMED
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY=CONFIRMED
CAUSALITY_CASE=A
```

最後樣本的 PI chain 為：

```text
RAW_ERROR=893702633
LD_ERROR=150000
PI_INTEGRATOR_BEFORE=22510150
PI_I_NEW=22210150
PI_INTEGRATOR_AFTER=22510150
PI_PROP_TERM=-22500000
PI_Y_PREROUND=-287802
PI_UNCLAMPED=-66
PI_CLAMPED=5
PI_CLAMP_SIDE=-1
```

所有 1800 筆都呈現正向 raw error；PI 未箝位輸出低於最小值，最後輸出被固定在 `Y_MIN=5`。integrator 在低側 anti-windup 下沒有持續累積，且輸出等式與 raw-error 等式全部通過。因此本輪已確認：目前觀測到的是穩態正偏差加上低軌飽和，屬於「致動器範圍不足或需要負向 authority」這一類原因，而不是單純觀測器不一致。

## 為何仍不是 Step5 pass

本輪沒有 lock：

```text
HELPER_LOCKED_FINAL=0
HELPER_LOCK_COUNT_FINAL=0
MAIN_ENABLED_FINAL=0
MAIN_FREQ_LOCKED_FINAL=0
MAIN_PHASE_LOCKED_FINAL=0
MAIN_LOCKED_FINAL=0
PSTAT_LOCKED_FINAL=0
```

同時沒有重新初始化或 reset：

```text
SPLL_INIT_COUNT_FIRST=1
SPLL_INIT_COUNT_FINAL=1
POST_INITIAL_SPLL_INIT_DELTA=0
HELPER_EPOCH_RESET_COUNT=0
RESET_BOOT_GENERATION_DELTA=0
RESET_CPU_DELTA=0
RESET_WR_CORE_DELTA=0
RESET_SI_CONFIG_DELTA=0
```

所以這輪證明了 Step4B 的 event-processing 路徑仍然穩定，也完成了 Step5 未 lock 的低軌因果分類；但它沒有證明 closed-loop lock，不能把 Step5 標為完成，也不能據此 merge 到 `main`。

## 下一步請分支5裁決

請分支5只依本報告與 raw evidence 判定，並提出下一個單一變因的 headroom experiment。除非分支5明確回覆：

```text
STEP5_COMPLETE = YES
MERGE_APPROVED = YES
```

否則維持不 merge。

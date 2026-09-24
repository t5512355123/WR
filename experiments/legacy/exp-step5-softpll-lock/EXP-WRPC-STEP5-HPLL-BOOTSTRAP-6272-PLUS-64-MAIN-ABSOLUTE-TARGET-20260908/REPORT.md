# EXP-WRPC-STEP5-HPLL-BOOTSTRAP-6272-PLUS-64-MAIN-ABSOLUTE-TARGET-20260908

## 結論

本輪在目前 page/mask isolation 與 Main absolute target tracker 版本上，測試
Slave `bootstrap=6272`、HPLL `64 code/physical step`。Step4B 成功，但 Helper
沒有收斂，反而長時間落在低 rail；因此 Step5 未完成。

```text
SOURCE_COMMIT = c0472620039b06f010c5235f4e4a2877ebe12928
STEP1_TO_STEP3 = PASS (preflight 2)
STEP4B = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 唯一功能變因

相較上一輪，只修改 Slave：

```text
STEP5_BOOTSTRAP_STEPS = 5632 -> 6272
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16 -> 64
```

保留 Main DPLL absolute target/applied tracker（`16 code/step`）、page/mask
四筆 runtime sequence、PI、lock detector、DMTD、PTP/PHY 與 reset policy。

## 編譯與燒錄

Pain 已從 GitHub 拉取 `c047262`。Master/Slave firmware 與完整 Quartus fit
均成功，兩張板子 programming 均成功且 0 errors；timing 仍未 closed。

```text
MASTER_SOF_SHA256 = 057321edb0f1988424e85b9052da08f335dbb1fed5bfbe7cf98e0e598edd17a1
SLAVE_SOF_SHA256  = e37af6fcdbb8a0f3d22914949d788faaa4cba6618cd4845f63887a0abe3c43da
TIMING_CLOSED = NO
PROGRAM_ORDER = SLAVE_THEN_MASTER
```

## Upstream gate

第一次 preflight 的 Link/endpoint 已恢復，但 Slave 尚在 `UNCALIBRATED`；等待
後的 preflight 2 是有效窗口：

```text
Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, PTP_RX delta > 0
Slave  PTP = SLAVE, PTP_RX delta > 0
Slave  WR_RX_SIGNAL = LOCK
Slave  LOCK_ENABLE_COUNT = 4
Slave  SPLL_INIT_COUNT = 1
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
```

## 1200-sample coherent Step5 observation

正式 observer 取得 1199 個 coherent measurement snapshots，實際時間約
120 秒；position、transaction、DCO 與 reset accounting 均通過。

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 1199
REJECTED_EPOCH_SNAPSHOTS = 1
REJECTED_ACCOUNTING_CANDIDATES = 124
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

Bootstrap 已完成，HPLL normal tracker 也確實有完成交易：

```text
BOOTSTRAP_COMPLETED_FINAL = 6272
BOOTSTRAP_DONE_FINAL = 1
TARGET_FINAL = 65531
APPLIED_FINAL = 65477
EXPECTED_APPLIED_ABSOLUTE = 65477
NORMAL_REQ_DELTA_OBSERVED = 1023
NORMAL_COMPLETED_DELTA = 1023
FINC_DELTA = 0
FDEC_DELTA = 1023
```

這確認 64-code quantized residual path 會執行，不是「tracker 沒有動」。

## Helper 結果

```text
HELPER_ERROR_MEAN = 120008.451209
HELPER_ERROR_RMS = 149971.002918
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
HELPER_OUTPUT_FINAL = 65531
LOW_RAIL_FRACTION = 0.899916597164
HIGH_RAIL_FRACTION = 0.0975813177648
NO_RAIL_FRACTION = 0.00250208507089
LOCK_COUNT_MAX = 3
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 242
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

與隔離版 `bootstrap=5632, HPLL=16` 的上一輪相比，本輪 error 由固定低 rail
演變為以低 rail 為主、偶爾高 rail 的大幅擺動，沒有形成 Helper lock。歷史上
6272+64 的接近零誤差結果來自不同的舊映像／不同 runtime path，不能用來宣告
目前隔離版已具備相同 operating point。

## 判定與下一步

本輪不能宣稱 Step5 PASS，也不能 merge。它證明目前控制介面雖能完成 6272 次
bootstrap 與 1023 次 HPLL FDEC，但 6272/64 並非目前隔離版的可鎖工作點。

下一輪應回到目前隔離版已知較佳的 `bootstrap=5632`，只測 HPLL tracker 64
（不再同時改 bootstrap），以分離 coarse origin 與 fine tracker mapping 的
影響；若仍 rail，則停止盲掃 PI，進入獨立的 N0/N1 physical response/頻率量測。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

本資料夾 `raw/` 保存：

- `preflight-1.log`、`preflight-2.log`
- `observer-coherent-1200.log`
- `program-slave.log`、`program-master.log`
- `build_info_jtag_master.txt`、`build_info_jtag_slave.txt`
- `sof-sha256.txt`

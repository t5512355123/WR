# EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830

## 判定

```text
STEP4B_SLAVE_SOFTPLL_STARTUP = PASS
STEP5_CLOSED_LOOP_LOCK        = NOT PASS
STEP5_MERGE_READY             = NO
```

本輪的目標是驗證 branch5 指定的最小 A/B：當 Slave 的 HPLL absolute target code 與前一次相同時，是否只強制放行一次 `hpll_pending`，並觀察它能否走完 runtime DCO transaction、產生新的 `STEP`，以及改變 helper error。

本輪沒有修改 gain、threshold、polarity、SoftPLL lock 判定、DMTD、PHY、PTP、reset tree 或 static-FSM one-line fix。唯一的實驗性 functional change 是 Slave image 的一次性 same-code request guard；Master image 維持停用。

## 實驗設定

```text
branch       = exp/step5-softpll-lock
source       = 59fe95205a3232978605136a1782e4bd7749798a
experiment   = EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830
programming  = paired fresh-program, Master then Slave
correlation  = 120 samples/board, 1000 ms interval
fixed_sof    = yes
```

實驗性參數配置如下：

```text
Master: ENABLE_SAME_CODE_TEST = 0
Slave : ENABLE_SAME_CODE_TEST = 1
```

Slave 端只在 `static_controller_ready=1`、`hpll_prev_valid=1`、HPLL data 與 previous data 相同，且 one-shot 尚未觸發時，放行一次 `hpll_pending`，之後永久 disarm。此 latch 由 `SAME_CODE_TEST_FIRED` 暴露給 JTAG decoder。

## Build / image identity

兩個 Quartus project 都完整編譯成功；但 timing 尚未 closed：

```text
Master SOF SHA256 = 4c653885cc09ca31b3e19a3ec504b6d556a2a621f336020d61931104aad6b0b2
Slave  SOF SHA256 = 1531f3d2ff9b1bee08b242427889cce14598c89ecaecbc2675021dd987492c08

Master TIMING_CLOSED = NO, WNS = -0.177 ns
Slave  TIMING_CLOSED = NO, WNS = -0.167 ns
```

兩張板均成功 build/program。先前單獨重燒 Slave 後取得的 `same-code-correlation-60s.log` 是啟動不同步、Slave 尚未完成初始化的 invalid capture；它保留在 raw 目錄中，但不列入本輪主要判定。主要證據是配對重燒後的 `same-code-correlation-120s-paired.log`。

## Paired correlation 結果

主要 log 每張板各有 120 筆 sample，合計 240 筆：

| 欄位 | Master `DE5 [1-11.1]` | Slave `DE5 [1-11.2]` |
|---|---:|---:|
| `SAME_CODE_TEST_FIRED` | 0（全程） | 1（全程） |
| `HPLL_PREV_VALID` | 1（全程） | 1（全程） |
| `HPLL_PENDING`（取樣瞬間） | 0（全程） | 0（全程） |
| `RT_STATE`（取樣瞬間） | 0（全程） | 0（全程） |
| `STEP` | 253（全程固定） | 954（全程固定） |
| `HELPER_ERROR_SIGNED` | -150000（全程） | -150000（全程） |
| `HELPER_OUTPUT` | `0xFFFB`（絕對 DAC code） | `0xFFFB`（絕對 DAC code） |
| `DCO_BUSY` | 0（全程） | 0（全程） |
| `DCO_ERROR` | 0（全程） | 0（全程） |

`HPLL_LOAD` 是短暫的瞬時 bit，1 秒取樣不會可靠地撞到 pulse；本輪新增的 `HPLL_LOAD_COUNT_MOD16` 在兩張板都遍歷多個值，證明取樣窗內 HPLL load 持續發生。因而不能把每筆 `HPLL_LOAD=0` 解讀成「沒有 HPLL load」。

## A/B 結果解讀

### A：現行行為

先前固定 SOF 的 correlation 已證明：HPLL load 持續發生、`HPLL_PREV_VALID=1`，但 absolute target code 維持不變；現行 data-change guard 因此不會為 same-code target 產生新的 incremental DCO request。

### B：Slave 一次性 same-code 放行

本輪結果：

```text
Slave SAME_CODE_TEST_FIRED = 1
Slave HPLL_PREV_VALID       = 1
Slave HPLL_PENDING sampled  = 0
Slave RT_STATE sampled      = 0
Slave STEP                  = 954 → 954（本窗口無可觀察增量）
Slave HELPER_ERROR          = -150000 → -150000
```

這證明 Slave 的 one-shot guard 已實際觸發，而不是只停留在 source-level。paired capture 同時可見非零的 sticky `T_RUNTIME_START` 與 `T_BUS_DONE`，但這些 timestamp 沒有在 one-shot 觸發前建立可比較的 baseline；因此不能嚴格證明該 transaction 是由這一次 forced pending 造成，也不能用它宣稱已完成 one-step causal proof。

最保守且可重現的結論是：

```text
same-code test fired                 = PROVEN
HPLL load activity                   = PROVEN
one-shot → new STEP delta            = NOT PROVEN
one-shot → helper error convergence  = NOT OBSERVED
```

本輪因此沒有證明 `hpll_pending → RT_STATE → BUS_DONE → STEP+1 → helper error change` 的完整鏈路。Step5 仍停在 helper lock 之前，不能判定 closed-loop lock pass。

## 即時 Runtime 診斷交叉檢查

同一 pain、同一 paired image 的 dashboard-after raw 顯示：

```text
Master: Step1 pass, Step2 pass, Step4A pass
Slave : Step1 pass, Step2 pass, Step3 pass, Step4B pass
Slave : STEP5_LOCKDET_BEFORE helper locked=0, PSTAT_locked=0
        STEP5_LOCKDET_AFTER  helper locked=0, PSTAT_locked=0
        STEP5_RESULT = NEVER_LOCKED
        STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

所以使用者看到的 Step4B error 不是這次 paired fixed-SOF capture 的結果；本次即時 raw 明確顯示 Step4B pass。但 Step5 仍然是 `NEVER_LOCKED`，這也是本輪不 merge 的直接理由。

## 下一步給 branch5 判定

請 branch5 讀取本報告與主要 raw log，重新判定：

1. `SAME_CODE_TEST_FIRED=1` 是否足以確認 one-shot guard 的 source-to-image 生效。
2. 在沒有 pre-trigger baseline 的情況下，sticky runtime timestamps 是否只能算輔助證據。
3. 下一輪是否應改做 absolute HPLL target 到 incremental FINC/FDEC translation 的 functional A/B，並要求直接的 `STEP` delta 與 helper error delta。

在 branch5 明確回覆 `STEP5 = PASS` 且另外明確回覆 `MERGE_APPROVED = YES` 以前，不得 merge 到 `main`。

## Raw data

- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/build-master.log`
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/build-slave.log`
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/build-info-master.txt`
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/build-info-slave.txt`
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/dashboard-after.log`
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/same-code-correlation-120s-paired.log`（primary）
- `raw/EXP-WRPC-STEP5-HPLL-SAME-CODE-ONE-STEP-AB-20260830/same-code-correlation-60s.log`（invalid startup capture，保留但不納入判定）

# EXP-WRPC-STEP5-HPLL-SI5340-BIDIRECTIONAL-ACTUATOR-STEP-RESPONSE-IDENTIFICATION-LANE2-20260902

## 實驗目的

依分支 5 最新建議，在已通過 Step4B gate 的 Slave 映像上，對 SI5340 HPLL actuator 施加等量 FINC/FDEC 脈衝，確認：

- actuator 是否確實接受並完成指定步數；
- FINC/FDEC 對 `FREQ_ERROR` 的瞬時方向與幅度是否相反；
- 是否造成 RX error、reset 或其他非預期副作用；
- 是否足以推進 Step5 closed-loop lock。

本實驗只使用固定、等量、有限的 128-step burst；normal HPLL tracker 與 bootstrap 均關閉。

## 版本與執行環境

- Git branch：`exp/step5-softpll-lock`
- FPGA image source commit：`21b3491` (`exp: add bidirectional SI5340 actuator identification`)
- 最終診斷腳本 HEAD：`7857165` (`fix: allow sequential actuator diagnostics`)
- Programming order：Master ready 後再 program Slave
- Master SOF SHA-256：`a8a075545d1bf735b7d8d2cdabfd85565fe7808cf398b23660852dd6cdb30c72`
- Slave SOF SHA-256：`79c8cca15550db0002559759eea548027556650c45c41e9853c69c913e1eefa2`
- Master/Slave compile：PASS；timing closed：NO
- Master/Slave programming：PASS，Quartus Programmer 均為 0 errors、0 warnings

## 啟動與 Step4B gate

重新依 Master → Slave 順序燒錄後，120 秒 startup timeline 顯示兩張板均可建立鏈路：

- Master：`core_link_ok=1`、`PTP=MASTER`
- Slave：`core_link_ok=1`，約 109 秒後進入 `PTP=SLAVE`
- 兩張板的 JTAG/WB transport 無錯誤

穩定 preflight 結果：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
RXERR_DELTA = 0
```

Step5 當時仍未 lock：

```text
PSTAT_LOCKED = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## Actuator 量測設定

```text
baseline_seconds = 5
burst_size = 128
settle_updates = 5
window_updates = 10
sample_gap_ms = 100
direction_encoding = 0:FDEC, 1:FINC
normal_hpll_tracker = 0
bootstrap = 0
```

## 實際結果

| Phase | 完成步數 | `FREQ_ERROR` before | after | 瞬時 Δ | settled Δ | settling time |
|---|---:|---:|---:|---:|---:|---:|
| FINC | 128/128 | -1033 | -1006 | +27 | 0 | 482 ms |
| FDEC | 128/128 | -994 | -1021 | -27 | 0 | 479 ms |

其他觀測：

- FINC completion：128 steps，123 ms；FDEC completion：128 steps，122 ms。
- FINC/FDEC 的瞬時 `FREQ_ERROR` 方向相反且幅度相同（`+27/-27`），表示 actuator 方向編碼與硬體響應方向一致。
- settled `FREQ_ERROR` 變化均為 0；因此本輪沒有證明可維持的頻率誤差校正量。
- `HELPER_ERROR` 瞬時 Δ 均為 0。
- `NORMAL_REQUEST_DELTA=0`、`NORMAL_COMPLETED_DELTA=0`。
- `RXERR_DELTA=0`。
- `BOOT_GENERATION_DELTA=0`、`CPU_RESET_DELTA=0`、`WR_CORE_RESET_DELTA=0`、`SI_CONFIG_DROP_DELTA=0`。

診斷腳本的保守摘要為：

```text
ACTUATOR_ACCOUNTING = PASS
DIRECTION_RESPONSE = INCONCLUSIVE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

`INCONCLUSIVE` 是因為兩個方向的瞬時反應雖然已被量到，但 settled response 都回到 0，且 `PSTAT_LOCKED` 仍為 0；不可把這輪誤報成 Step5 pass。

## 結論

本輪確認了 Step5 所需的 SI5340 actuator 基本 plant response：FINC/FDEC 都能完成 128 steps，且對 `FREQ_ERROR` 產生等幅反向瞬時反應；同時沒有 RX error 或 reset 副作用。

但是本輪沒有達成 closed-loop lock，因此：

```text
STEP4B = PASS
STEP5 = NOT COMPLETE
MERGE = NOT APPROVED
```

下一步交由分支 5 判斷是否接受此結果，以及指定下一個 Step5 實驗。

## 原始紀錄

原始 build、program、startup、preflight 與 actuator log 位於：

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-SI5340-BIDIRECTIONAL-ACTUATOR-STEP-RESPONSE-IDENTIFICATION-LANE2-20260902/`

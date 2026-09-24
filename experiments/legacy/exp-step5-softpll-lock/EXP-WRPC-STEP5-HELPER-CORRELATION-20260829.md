# EXP-WRPC-STEP5-HELPER-CORRELATION-20260829

## 結論

本輪固定既有 programmed bitstream，只做 read-only correlation；Step5 仍未
通過：

```text
STEP4B = PASS
STEP5  = NOT PASS
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
ROOT_CAUSE = NOT_YET_PROVEN
```

但已把 helper blocker 再縮小：helper update、TAG/TRR/IRQ event 都持續增加，
而 helper error 與 output 在整個 correlation window 幾乎固定；同時 actuator
transaction fields 顯示沒有新的 DCO step/load event。這符合分支5提出的 Case A
方向，但仍需 source-level actuator path audit 才能正式宣告 root cause。

## 實驗身份

| 項目 | 值 |
|---|---|
| Branch | `exp/step5-softpll-lock` |
| Repository commit | `210add0` (`exp: record Step5 helper-lock baseline`) |
| Programmed firmware / decoder identity | `60037a1bf87971f59a12286dafd51c88977d49a5` |
| 實驗日期 | 2026-08-29 |
| Functional source change | 無；固定既有 SOF，只執行觀測 |
| Dashboard | `read_wb_runtime.tcl --raw` |
| Correlation | `read_hpll_helper_correlation.tcl 120 500` |
| Time-series | `read_wb_timeseries_session.tcl 60 1000 3` |

本輪不重新 compile，因為執行的是固定 bitstream 上的 read-only Tcl
diagnostics；其 SOF SHA-256 與前一輪 baseline 相同。

## Upstream regression gate

最新 correlation 前 dashboard 的穩定觀測顯示：

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave : Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS
```

Slave 的正式 dashboard 結果為：

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此本輪不是被 Step1–4B prerequisite 擋住。

## Helper correlation evidence

Correlation script 對兩張板各取 120 samples。關鍵結果：

| Board | Helper error | Helper output | Actuator fields | Helper state |
|---|---:|---:|---|---|
| Master `DE5 [1-11.1]` | `+150000` (`0x000249F0`) | `+5` | `STEP_DELTA=0`, `STEP_EVENT=0`, `HPLL_LOAD=0`, `BUSY=0`, `ERROR=0` | active, not locked |
| Slave `DE5 [1-11.2]` | `-150000` (`0xFFFDB610`) | `-5` (`0x0000FFFB`) | `STEP_DELTA=0`, `STEP_EVENT=0`, `HPLL_LOAD=0`, `BUSY=0`, `ERROR=0` | active, not locked |

兩張板的 helper lock threshold 是 `±200`，lock sample target 是 `10000`；
兩張板的 helper error 都遠超過 threshold，且 helper error delta 為 0。

同一個 window 中，Slave 仍有：

```text
SPLL_STATE = 0x00030004
SPLL_MODE = 3 (SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
HELPER_UPDATE_COUNT: continuously increasing
TAG / TRR / IRQ counters: continuously increasing
HELPER_STATE = 0x00000000
MAIN_STATE = 0x00000000
PSTAT.locked = 0
```

因此 event delivery 到 helper update 已成立，但 helper 沒有累積 qualified
lock samples，也沒有進入 main loop。

## 同時間序列判讀

### 已證明的部分

- `helper_update_count` 持續增加，並非 helper task 沒有執行。
- `TAG`、`TRR`、`IRQ` 與 DMTD-related counters 持續活動，Step4B 沒有 regression。
- helper output 在 Master 約為 `+5`、Slave 約為 `-5`，各自維持固定值。
- `STEP_DELTA=0`、`STEP_EVENT=0`、`HPLL_LOAD=0`、`BUSY=0`、`ERROR=0`，沒有觀察到新的 DCO step transaction / load completion。
- Slave 的 helper error 維持 `-150000`，沒有朝 `0` 收斂；Master 對應為 `+150000`。
- 60 秒 fixed time-series 中，兩張板都是 `valid_samples=60`、`NEVER_LOCKED`，boundary 全程是 `HELPER_LOCK`。

### 尚不能直接宣告的部分

`DAC_HPLL` raw readback 在 sample 間會變化，但這個變化沒有伴隨
`STEP_EVENT`、`HPLL_LOAD` 或 `STEP_DELTA`；不能只憑 DAC raw variation 宣告
DCO actuator 已完成有效 transaction。需要再對照 source-defined：

```text
dac_hpll_load
  -> si5340a_controller_dco
  -> I2C request / busy / done
  -> step_count / completed-step shadow
```

所以本輪最準確的分類是：

```text
CASE_A_DIRECTION = LIKELY
ACTUATOR_ROOT_CAUSE = NOT_YET_PROVEN
```

不能直接把它寫成 polarity、threshold 或 PI gain 問題。

## Time-series closure

```text
DE5 [1-11.1]  valid_samples=60  STEP5_SERIES_RESULT=NEVER_LOCKED
DE5 [1-11.2]  valid_samples=60  STEP5_SERIES_RESULT=NEVER_LOCKED
```

Slave 每一個有效 sample 都保持：

```text
boundary=HELPER_LOCK
helper locked=0
helper cnt=0/10000
main enabled=0
main frequency lock=0
main phase lock=0
PSTAT_locked=0
delock_count=0
```

這確認 Step5 尚未開始 main/phase lock；不能把下游 `PSTAT_locked=0` 當作
第一個 blocker。

## 下一步建議

依分支5的判定，本輪之後應先做 DCO actuator handshake 的 source-backed
audit / observability，仍然不要：

- 放寬 helper threshold；
- 修改 PI gain、DCO gain 或 polarity；
- 修改 Main PLL / phase loop；
- 修改 DMTD 或 PTP/WR functional behavior。

下一個實驗應回答：`helper_output` 是否真的觸發 DCO request、request 是否被
SI5340 controller 接收、I2C/bus 是否完成，以及 completed step shadow 為何仍為
0。只有這條 path 被證明正常後，才有足夠證據選擇下一個單一變因 functional A/B。

## 原始證據

- [dashboard before correlation](raw/EXP-WRPC-STEP5-HELPER-CORRELATION-20260829/dashboard-before.log)
- [helper correlation, 120 samples](raw/EXP-WRPC-STEP5-HELPER-CORRELATION-20260829/helper-correlation-60s.log)
- [fixed Step5 time-series, 60 samples per board](raw/EXP-WRPC-STEP5-HELPER-CORRELATION-20260829/step5-timeseries-60s.log)
- [Step5 baseline report](EXP-WRPC-STEP5-BASELINE-20260829.md)
- [Step5 source audit](STEP5-SOURCE-AUDIT.md)


# EXP-WRPC-STEP5-HPLL-PENDING-CORRELATION-20260829

## 判定

```text
STEP4B_SLAVE_SOFTPLL_STARTUP = PASS（沿用前一輪 branch5 已核准的固定 SOF 證據）
STEP5_CLOSED_LOOP_LOCK        = NOT PASS
FIRST_INACTIVE_BOUNDARY       = HPLL_DATA_CHANGE_TO_PENDING
```

本輪沒有修改 RTL、SoftPLL、DCO、I2C、PHY、reset tree 或功能程式碼；也沒有重新編譯或燒錄。只在目前已燒錄的固定 SOF 上使用唯讀 JTAG probe 與既有診斷 mailbox 取樣。

## 實驗設定

```text
branch       = exp/step5-softpll-lock
decoder      = scripts/jtag/read_step5_hpll_pending_correlation.tcl
decoder_commit = a315f72
samples/board = 120
sample_gap   = 1000 ms
boards       = DE5 [1-11.1], DE5 [1-11.2]
total samples = 240
fixed_sof    = yes
```

固定 SOF build identity：

```text
Master SHA256 = f729ad5a5ef481092da27d9c1ec1c2055692bf6c9d5ca870cce3ea588f091fb2
Slave  SHA256 = 5c54f005795786920e55394026cca5484fa593d68f4e7f4ef9c0ef371e2df811
```

## 觀測結果

每張板均有完整 120 筆 sample，且修正後 decoder 沒有 `INVALID` DCO 欄位。

| 欄位 | Master `DE5 [1-11.1]` | Slave `DE5 [1-11.2]` |
|---|---:|---:|
| `STATIC_READY` | 1（全程） | 1（全程） |
| `HPLL_PREV_VALID` | 1（全程） | 1（全程） |
| `HPLL_PREV_DATA_LOW11` | 5 | 2043（低 11 位，代表 `0xFFFB` 的低位） |
| `HPLL_LOAD` | 0（取樣窗內） | 0（取樣窗內） |
| `HPLL_PENDING` | 0（全程） | 0（全程） |
| `RT_STATE` | 0（全程） | 0（全程） |
| `DCO_BUSY` | 0（全程） | 0（全程） |
| `DCO_ERROR` | 0（全程） | 0（全程） |
| `STEP` | 956（無增量） | 1902（無增量） |
| `HELPER_ERROR_SIGNED` | +150000 | -150000 |
| `HELPER_OUTPUT` | +5 | -5 |

取樣窗內的 sticky 事件：

```text
Master:
  T_DAC_LOAD     = 03EF5E47
  T_RUNTIME_START= 03EF5F2E
  T_BUS_DONE     = 03EF9941
  T_STATIC_DONE  = 03EF9B42

Slave:
  T_DAC_LOAD     = C79575CB
  T_RUNTIME_START= C7957968
  T_BUS_DONE     = C795B341
  T_STATIC_DONE  = C795B542
```

兩張板的 `T_STATE_LEAVE_ZERO`、`T_READY_DROP`、`T_SI_CONFIG_DROP`、`T_WR_CORE_RESET`、`T_CPU_RESET`、`T_SYSTEM_START` 都保持 `00000000`；live correlation 也保持 `RUNTIME_STATE_LIVE=0`、`BUS_STATE_LIVE=0`。這表示取樣窗內沒有新的 runtime DCO transaction，也沒有新的 reset/drop 事件。

## 邊界分析

`HPLL_PREV_VALID=1` 加上非零 `T_DAC_LOAD` 證明至少有 HPLL DAC load 已經到達 DCO wrapper，並不是完全沒有 top-level load。可是目前 decoder 在兩張板上都觀察到：

```text
HPLL_PREV_VALID = 1
HPLL_LOAD       = 0（取樣窗內沒有新的 pulse）
HPLL_PENDING    = 0
RT_STATE        = 0
STEP            = constant
```

現行 RTL 的 request capture 條件是：

```verilog
if (hpll_prev_valid && (iHPLL_DATA != hpll_prev_data)) begin
    hpll_pending <= 1'b1;
end
```

因此本輪將第一個 inactive boundary 定位為：

```text
HPLL output/data-change → hpll_pending
```

更精確地說：目前實測 helper output 已停在 Master `+5`、Slave `-5`，而 DCO 保存的 HPLL previous data 也維持固定；在沒有新的 data change 時，`hpll_pending` 不會被設起來，runtime state 不會離開 0，後續自然不會有 `runtime_start`、I2C bus transaction 或新的 step。

這一輪不能單獨證明「第一個 load 的 initialization guard 就是唯一根因」，但已排除以下判斷：

```text
不是 static_controller_ready 不成立
不是 runtime I2C bus 已開始但未完成
不是 DCO error
不是取樣時剛好漏掉唯一一個 completed step
```

## Raw data

- `raw/EXP-WRPC-STEP5-HPLL-PENDING-CORRELATION-20260829/hpll-pending-correlation-120s.log`
- `raw/EXP-WRPC-STEP5-HPLL-PENDING-CORRELATION-20260829/dashboard-live-20260830.log`

## 即時總覽交叉檢查（2026-08-30）

在同一 pain、同一固定 SOF 上重新執行 `read_wb_runtime.tcl --raw`，得到：

```text
Master: Step1 pass, Step2 pass, Step4A pass
Slave : Step1 pass, Step2 pass, Step3 pass, Step4B pass
Slave : STEP5_RESULT = NEVER_LOCKED
        STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此使用者貼出的 `Step1 PHY / Link error`、`Step4 SoftPLL Startup error` 不符合本次即時讀取結果；它應屬於舊畫面、舊 raw snapshot 或不同診斷入口。這不改變 Step5 的判定：Slave 仍卡在 Helper lock，尚未達成 Step5。

## 下一步建議給 branch5

請 branch5 依照上述 evidence 判定 Step5，並指定下一個最小 A/B。下一輪仍應先區分：

1. SoftPLL 是否只輸出一次固定 HPLL code，後續沒有 data-change；或
2. HPLL load 有變化但沒有被 DCO capture；或
3. 需要針對 `hpll_prev_valid && data-change` guard 做一次明確的 functional A/B。

在 branch5 明確批准前，不修改此 guard、不調整 gain/threshold/polarity，也不 merge 到 `main`。

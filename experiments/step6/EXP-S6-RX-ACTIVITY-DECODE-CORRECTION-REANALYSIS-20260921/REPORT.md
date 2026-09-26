# EXP-S6-RX-ACTIVITY-DECODE-CORRECTION-REANALYSIS-20260921

## 結論

本輪是 offline evidence-correction，未進行任何新的硬體 sampling。結果如下：

```text
RX_ACTIVITY_DECODE_CORRECTION = PASS
RECOVERED_RX_CLOCK_ACTIVITY   = PRESENT
PREVIOUS_FAILURE_CLASS        = INVALIDATED

LINK_ATTRIBUTION              = PASS
POST_SLAVE_LINK_ESTABLISHMENT = FAIL
FAILURE_CLASS                 = FAIL_PHY_PCS_INPUT_INTEGRITY

S_LOCK                        = NOT_REACHED
STEP6A                        = NOT_PASS
STEP6B                        = NOT_RUN
```

上一輪 `FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED` 是 analyzer/observer decode
bug 造成的錯誤分類，已撤回；本輪沒有改變 DUT 或硬體狀態。

## Evidence 與 correction

RTL source mapping 定義 instance 7：

```text
bits [0:15]   = REF activity
bits [16:31]  = DMTD activity
bits [32:47]  = recovered-RX activity
```

上一版 observer 使用：

```tcl
field32 $clock 32 16
```

但 `field32()` 先以 `word32()` 截取低 32 bits，所以這個表達式永遠無法讀到
bits `[47:32]`。本輪改用真正的 64-bit extraction；contract vector：

```text
CLOCK_ACTIVITY_RAW = 002EBD9D9E3300DA
corrected RX activity = 0xBD9D
```

另外確認這是 16-bit wrapping counter。重新分析使用 raw 值的跨 sample 變化，
不把 after<before 當成 failure，也不從 500 ms 間隔估算精確頻率。

## Corrected result

| Board | valid | corrected RX activity sequence | data lock | control | syncstatus=0 | enc err | errdetect | corrected class |
|---|---:|---|---:|---:|---:|---:|---:|---|
| Master `DE5 [1-11.1]` | 6/6 | `BD9D → 304B → A1C5 → 1337 → 82ED → F3E1` | 6/6 全為 1 | 6/6 PASS | 6 | 0 | 0 | `FAIL_PHY_PCS_INPUT_INTEGRITY` |
| Slave `DE5 [1-11.2]` | 6/6 | `13E8 → 820B → F0A3 → 5FF0 → CD2E → 3BFE` | 6/6 全為 1 | 6/6 PASS | 6 | 3 | 3 | `FAIL_PHY_PCS_INPUT_INTEGRITY` |

兩板所有有效 raw sample 都有：

```text
PHY_RST        = 0
PHY_TX_DISABLE = 0
ECR.TX_EN      = 1
ECR.RX_EN      = 1
RX_LOCKED_TO_DATA = 1
```

因此目前 causal chain 應改寫為：

```text
RX data lock = present
        ↓
recovered RX clock activity = present
        ↓
RX_SYNCSTATUS = 0
Slave additionally sees RX encoding/errdetect events
        ↓
Endpoint link = 0
        ↓
PTP/WR handshake and S_LOCK not reached
```

目前不把它更細命名為 `PCS_SYNC_NOT_ACQUIRED`，因為 `wr_rx_syncstatus` 在此
Arria transceiver wrapper 的精確語意，以及 word alignment/8b10b boundary，
仍需下一輪 source audit 或專門實驗確認。

## Hardware and workflow audit

- Laptop correction source：`280d3165`
- Pain 已 pull 到 `280d3165`
- 沒有 compile、firmware build、program、power cycle、PHY reset、PTP restart、
  fiber replug、SI5340 change、MDIO write
- 本輪只重新分析上一輪 `2f683cb5` 已保存的 raw log

## Raw integrity

本輪使用的 raw 是上一輪已驗證的檔案，SHA-256 不變：

```text
master-endpoint-link.log  B8C642FDCC0B52C9F959BA8E142E2EECDE0409B1FDE5FFAEEE55AB55B1283132
slave-endpoint-link.log   B2967AD00202A10F362BE28510DDC706BAC6F6AFCCDA3AB5309F45DD9173E48E
```

完整 corrected analysis 在 `analysis/summary.json`；原始 raw 位於前一輪實驗
資料夾並由 correction notice 連結說明。

## Stop condition

decoder correction 已由 RTL mapping、contract vector、Master/Slave 各 6 筆
raw activity 變化共同確認，因此本輪停止。不可在同一輪接著 reset PHY、改
polarity/transceiver、MDIO debug 或重新 programming；下一步硬體實驗要等新的
診斷建議後再指定。

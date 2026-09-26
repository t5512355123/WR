# EXP-S6-RX-ACTIVITY-DECODE-CORRECTION-REANALYSIS-20260921

## Objective

修正並重新分析 `EXP-S6-POST-SLAVE-ENDPOINT-LINK-ATTRIBUTION-20260921`
的既有 raw evidence。上一輪把 instance 7 的 64-bit `CLOCK_ACTIVITY_RAW`
用 `field32(..., 32, 16)` 解碼；`field32` 先截低 32 bits，因此把真正的
bits `[47:32]` 誤判為 0。本輪只確認這個 evidence/decode boundary，撤回舊的
`FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED` 歸因。

## No-hardware contract

本輪只讀取本機已保存的：

```text
.../EXP-S6-POST-SLAVE-ENDPOINT-LINK-ATTRIBUTION-20260921/raw/
```

不做新的 hardware sampling，也不做：

- compile、firmware build、Master/Slave programming
- power cycle、PHY reset、PTP restart、mode command、fiber replug
- SI5340 change、MDIO write、transceiver/polarity change

## Allowed changes

- `scripts/jtag/read_step6_post_slave_endpoint_link_attribution.tcl`
- offline analyzer/test scripts
- 本實驗的 plan、analysis、report

禁止修改 DUT RTL、vendor WR core、firmware、SOF/MIF。

## Correction contract

1. 使用 64-bit field extraction 讀取 `CLOCK_ACTIVITY_RAW[47:32]`。
2. instance 7 的 RX activity 是 16-bit wrapping counter；不要把 after<before
   當成 failure，也不要用 500 ms sample interval 推算精確頻率。
3. 以跨 sample 的 raw activity 值變化證明 recovered-RX clock activity presence。
4. contract vector：

```text
CLOCK_ACTIVITY_RAW = 002EBD9D9E3300DA
RX_ACTIVITY        = 0xBD9D
```

## Stop/pass contract

若 RTL mapping、old observer truncation、以及兩板至少 5 筆 raw activity 變化
全部成立：

```text
RX_ACTIVITY_DECODE_CORRECTION = PASS
RECOVERED_RX_CLOCK_ACTIVITY   = PRESENT
PREVIOUS_FAILURE_CLASS        = INVALIDATED
```

若 corrected evidence 同時保留 RX data lock、Endpoint control enabled，且
`RX_SYNCSTATUS=0` 或 direct encoding/error evidence 存在，新的 boundary 分類為：

```text
FAIL_PHY_PCS_INPUT_INTEGRITY
```

本輪仍不是 S_LOCK、Step6A 或 Step6B PASS；完成 reanalysis 後停止，等待下一個
硬體實驗建議。

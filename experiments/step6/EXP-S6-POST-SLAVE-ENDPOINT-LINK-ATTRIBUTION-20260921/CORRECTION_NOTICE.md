# Correction notice

`REPORT.md` 的原始 online attribution 曾將本輪分類為
`FAIL_SERDES_RX_STREAM_NOT_ESTABLISHED`。在
`EXP-S6-RX-ACTIVITY-DECODE-CORRECTION-REANALYSIS-20260921` 中，確認該分類
來自 instance 7 64-bit probe 的 decoder truncation：`field32()` 無法讀取
bits `[47:32]`。raw log 本身的 RX activity 並未為 0。

因此原 attribution 已撤回；請以 correction experiment 的正式分類
`FAIL_PHY_PCS_INPUT_INTEGRITY` 為目前有效結論。raw evidence 未被修改。

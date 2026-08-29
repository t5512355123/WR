# EXP-WRPC-STEP5-BASELINE-20260829

## 結論

本輪是 Step5 的第一個 source-backed baseline，結論為：

```text
Step4B = PASS
Step5  = NOT PASS
```

最新穩定觀測不是單純的 dashboard 顯示錯誤。Slave 的 SoftPLL 確實停在
`SEQ_WAIT_HELPER`，helper lock detector 沒有取得 lock，因此尚未進入 main
frequency / phase lock，也不能宣告 Step5 pass。

## 實驗身份

| 項目 | 值 |
|---|---|
| Branch | `exp/step5-softpll-lock` |
| Firmware / decoder commit | `60037a1bf87971f59a12286dafd51c88977d49a5` |
| 日期 | 2026-08-29 |
| 實驗性質 | Step5 observability baseline；未修改 SoftPLL functional semantics |
| Master SOF SHA-256 | `f729ad5a5ef481092da27d9c1ec1c2055692bf6c9d5ca870cce3ea588f091fb2` |
| Slave SOF SHA-256 | `5c54f005795786920e55394026cca5484fa593d68f4e7f4ef9c0ef371e2df811` |
| Timing | `TIMING_CLOSED=NO`；Master setup WNS `-0.177 ns`，Slave setup WNS `-0.272 ns` |
| Programming | Master / Slave 均成功，Quartus checksum 分別為 `0x30B00EC4` / `0x30B7AD8B` |

Timing 尚未 closed，列為 implementation caveat；本輪功能判定仍以同一個已成功
program 的 SOF 與 runtime evidence 為準。

## 實驗流程

初次 fresh-program 後曾出現短暫 link/PTP 尚未恢復的觀測，這些樣本標記為
`NOT_USABLE_FOR_STEP5`，不拿來判定 Step5。之後以 Slave → Master 順序重新
program，等待 link/PTP 穩定，再進行 dashboard 與 60 秒 time-series 觀測。

最新可用 dashboard 是：

`raw/EXP-WRPC-STEP5-REPEAT-20260829/dashboard-recheck-raw.log`

固定 decoder 的 60 秒有效 time-series 是：

`raw/EXP-WRPC-STEP5-REPEAT-20260829/timeseries-60s-fixed.log`

## 最新穩定 dashboard

Master：

```text
Step1 PHY / Link       PASS
Step2 Endpoint / PTP   PASS
Step4A SoftPLL startup PASS
```

Slave：

```text
Step1 PHY / Link       PASS
Step2 Endpoint / PTP   PASS
Step3 WR Handshake      PASS
STEP4B_ALLOWED          YES
STEP4B_RESULT            PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

同一份穩定 dashboard 的 Slave Step5 source-backed snapshot：

```text
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK

HELPER locked=0 changed=0 cnt=0/10000 threshold=200 ref_src=0
MAIN enabled=0 locked=0 freq=0 phase=0 freq_cnt=0/50 phase_cnt=0/1000
PSTAT_locked=0

SPLL_MODE=3 (SLAVE)
SPLL_SEQ_STATE=4 (SEQ_WAIT_HELPER)
SPLL_INIT_COUNT=4
```

這表示 Step4B 的 event-processing chain 已經能運作，但 helper lock 所需的
連續 qualified samples 尚未累積完成。因為 main sequencer 只會在 helper lock
transition 後啟動，所以 `MAIN enabled=0`、frequency/phase lock 為 0、
`PSTAT_locked=0` 是一致的 downstream 結果。

## 60 秒有效 time-series

固定後的 reader 不再要求 live DAC/counter 必須在同一個 snapshot 完全相等，
而是依 source-backed control、sequence、helper、main 與 PSTAT 欄位判定 sample
是否可用。結果如下：

```text
DE5 [1-11.1]  valid_samples=60  STEP5_SERIES_RESULT=NEVER_LOCKED
DE5 [1-11.2]  valid_samples=60  STEP5_SERIES_RESULT=NEVER_LOCKED
```

兩張板合計 120 個有效 sample 的 first-inactive boundary 全部是：

```text
HELPER_LOCK
```

未觀察到 helper lock acquisition、main lock progression 或 lock-then-loss。
因此這不是「已 lock 但 dashboard 沒顯示」；在完整有效觀測窗內，sequencer
沒有越過 helper-lock boundary。

## 判定

本輪可以正式確認：

1. Step4B 在穩定 link/PTP 條件下仍為 PASS。
2. Step5 尚未達成，且 blocker 已從原本的泛化 `error/NA` 收斂到
   `HELPER_LOCK`。
3. `PSTAT.locked=0` 目前符合 source FSM 預期，不能單獨拿來推論硬體故障。
4. 因 helper 從未 lock，本輪沒有證據顯示 main loop、phase detector 或 final
   lock path 已被執行。

舊版 `timeseries-60s.log` 的 `valid_samples=0` 是 reader 對 live
counter/DAC equality 的過嚴判定；它不再作為本輪結論。修正後的
`timeseries-60s-fixed.log` 已取得每秒有效 sample，並仍得到
`NEVER_LOCKED / HELPER_LOCK`，所以目前 Step5 未通過的結論是有效的。

## 建議分支5判定的下一步

下一輪不要直接修改 main lock 或 phase lock。應先針對 helper-lock boundary
做 source-backed correlation：

- 對照 helper lock detector 的 qualified error、threshold `200`、lock sample
  target `10000` 與實際 helper update / accepted event delta。
- 同步保存 helper error/output、`ref_src`、TAG/TRR/IRQ/helper-update counter
  的 delta，確認 helper update 是否真的持續收到正確的 DMTD error。
- 檢查 helper error 是否超出 threshold、是否沒有更新、或 reference source
  是否錯誤；未完成這個分辨前不應把 Step5 標成硬體 fail。

## 原始證據

- [Step5 source audit](STEP5-SOURCE-AUDIT.md)
- [runtime reader](../../../scripts/jtag/read_wb_runtime.tcl)
- [time-series reader](../../../scripts/jtag/read_wb_timeseries_session.tcl)
- [settled dashboard raw log](raw/EXP-WRPC-STEP5-REPEAT-20260829/dashboard-recheck-raw.log)
- [fixed 60-second time-series raw log](raw/EXP-WRPC-STEP5-REPEAT-20260829/timeseries-60s-fixed.log)
- [Master build identity](build/build_info_jtag_master.txt)
- [Slave build identity](build/build_info_jtag_slave.txt)

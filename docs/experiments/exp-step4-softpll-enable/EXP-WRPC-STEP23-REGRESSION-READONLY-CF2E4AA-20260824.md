# EXP-WRPC-STEP23-REGRESSION-READONLY-CF2E4AA-20260824

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 唯讀回歸閘門與 JTAG 特殊值可靠性重測
- 日期：2026-08-24
- Git branch：`exp/step4-softpll-enable`
- JTAG Tcl commit：`cf2e4aa322d252ff44ea05a0306d24bcd74755f3`
- 本次是否修改 FPGA functional code：否
- 本次是否 firmware build：否
- 本次是否 Quartus compile：否
- 本次是否 program FPGA：否
- Quartus runtime：Quartus Prime 17.0.0 Build 595

本次只將 GitHub 的 `cf2e4aa` checkout 到 pain，然後執行 read-only JTAG diagnostics。實機映像沒有在本輪重新燒錄；JTAG 觀測到的是先前 control A 實驗所燒錄的 exact `7dd298bb` fresh SOF。這一點必須與本次 Tcl commit 分開記錄，不能把 Tcl checkout 誤寫成硬體重新建置或重新燒錄。

## 想驗證什麼

1. `WDIAGS_PTP`、由 `WDIAGS_PTP_META` 解出的 `WDIAGS_MODE`、`FOREIGN_META`、`PARSE_META`、WR state、`LOCK_ENABLE`、`SPLL_STATE`、RCER、OCER 等 critical read 在 stale/filler 或 mailbox 不一致時，是否會被 retry/reject，而不是變成硬體 FAIL。
2. PTP TX 單一短窗口為零時，是否不會單獨使 Step 2 regression 失敗。
3. counter decrease/reset 是否會被標成 retest/inconsistent，而不是直接宣稱硬體錯誤。
4. 在不燒錄、不 compile 的情況下，使用 focused repeated sampling 重新確認 Step 2 / Step 3。

## 相較前一版本唯一修改

只修改 `scripts/jtag/read_wb_runtime.tcl`：

- 新增集中式 `numeric_value`、`numeric_equal` 保護。
- 固定值、正值與 delta 判定在進入 Tcl `expr` 前先確認是整數。
- `TIMEOUT`、`INVALID`、非數值資料不再進入數值比較。
- `DECREASED` 保留為資訊/重測狀態。
- RXERR 的零 delta 比較改由安全的 numeric helper 執行。

沒有修改 role switching、PTP、WR signaling、SoftPLL、DDMTD、PHY、DCO、SI5340 或任何 Wishbone control 行為。

## 實驗命令

### focused Step 2 / Step 3

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl \
  20 500 25
```

參數意義為 20 個 sample、每次間隔 500 ms、每筆 mailbox transaction 最多 25 次 poll。此腳本只讀取 JTAG probe 與 Wishbone mailbox，不寫入 control register，也不寫 `DATA_SNAPSHOT`。

### dashboard

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

### 輔助 reliability script

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step23_register_reliability.tcl \
  20 500 all 25
```

此輔助腳本在第一張板的 `WR_TX_SIGNAL` 讀取後長時間沒有繼續輸出，因此停止該 read-only process。partial log 保留作為診斷工具執行層問題，未拿來作為硬體 regression gate。

## JTAG raw evidence

- focused 完整輸出：`raw/EXP-WRPC-REGRESSION-READONLY-20260824-focused.log`
- dashboard 完整輸出：`raw/EXP-WRPC-REGRESSION-READONLY-20260824-dashboard.log`
- reliability partial 輸出：`raw/EXP-WRPC-REGRESSION-READONLY-20260824-reliability-partial.log`

## focused 結果

### Master：DE5 `[1-11.1]`

- `valid_samples=20`
- `invalid_samples=0`
- `counter_decreased=0`
- MAC：`02:00:22:33:44:01`
- MODE：`2`
- PTP：`6`
- PTP TX delta：`61`
- MiniNIC/PTP counters 持續增加
- RXERR：`0`
- `STEP2_REGRESSION=PASS`

Master 不適用 Slave-specific Step 3，因此 focused script 輸出 `STEP3_REGRESSION=NA`。

### Slave：DE5 `[1-11.2]`

- `valid_samples=20`
- `invalid_samples=0`
- `counter_decreased=0`
- MAC：`02:00:22:33:44:02`
- MODE：`3`
- PTP：20 個 sample 都是 `9`
- PTP TX delta：`7`
- MiniNIC/PTP counters 持續增加
- RXERR：`0`
- Foreign Master：`1/0`
- parent flags：`parentIsWRnode=1/parentWrModeOn=0/parentCalibrated=1`
- WR RX message：`0x1001 LOCK`
- WR TX message：`0x1000 SLAVE_PRESENT`
- `LOCK_ENABLE=4`
- `STEP2_REGRESSION=PASS`
- `STEP3_REGRESSION=PASS`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- `POST_STEP3_LOCK_STAGE=TIMEOUT`

Slave 的 `WRS_IDLE` sample 與已觀測到的 `LOCK`、`SLAVE_PRESENT`、`LOCK_ENABLE=4` 同時存在。依 focused script 的 source-backed 判定，這屬於後續 lock stage / live state 的不一致證據，不否定 Step 3 已達成的 signaling handoff gate。

## dashboard 結果與限制

dashboard 在兩板都完整執行成功，沒有 Tcl exception，Step 1 與 Step 2 均顯示通過，Slave Step 3 也顯示通過。Slave Step 4 顯示：

- `LOCK_ENABLE=4`
- `SPLL_STATE` mode=`3`
- RCER=`1`
- OCER=`TIMEOUT`
- DMTD、TAG、TRR、TRR_POP、IRQ、HELPER_UPDATE 的短窗口 delta 為 `0`

這些 Step 4 欄位不能在本次直接解讀成 hardware/firmware failure，原因是本輪沒有重新生成或燒錄 Step 4 functional image；實機仍是 `7dd298bb` control A SOF，而 dashboard 的 Step 4 extended observability map 是為後續 diagnostics tree 準備的。這一列結果應分類為：

```text
JTAG/DASHBOARD_MEASUREMENT_LIMITATION
```

它不是 Step 2 / Step 3 focused regression 的失敗證據，也沒有允許本輪開始任何 Step 4 functional experiment。

## Regression barrier 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_MEASURED
```

`STEP4_ALLOWED=YES` 只表示本次 read-only evidence 已通過進入下一階段前的 Step 1～3 barrier；它不代表 SoftPLL Step 4 已通過，也不代表 `spll_locked=1`、`time_valid=1` 或 closed-loop 已完成。

## Observation

1. Completed focused repeated sampling 沒有 invalid mailbox sample，也沒有 counter decrease；Step 2 / Step 3 的判定證據一致。
2. 本次沒有重現 `WDIAGS_PTP=0xA5A51330` 這類 stale/filler 值，因此 invalid retry code path 沒有被實機資料觸發；但腳本完成執行且所有 critical read 均通過 source-backed validation。
3. dashboard 顯示的 Step 4 zero/timeout 欄位與 control A image 的 provenance 不足以支撐功能失敗結論。
4. 輔助 `read_step23_register_reliability.tcl` 存在執行 hang，應另開診斷工作修正其 bounded transaction/overall timeout；不應覆寫或降低 focused regression gate。

## Conclusion

本次證據支持：

- Step 1 PHY/link regression：PASS。
- Step 2 Endpoint/MiniNIC/PTP regression：PASS。
- Step 3 WR parent/signaling regression：PASS。
- 沒有證據支持硬體或 firmware 在 Step 2/3 失敗。
- 沒有完成 Step 4 的功能測量。

## Next Step

依 reviewer barrier，下一步才可在保留 exact 7dd control A 行為的前提下，設計一個最小、單一的 read-only SoftPLL/TRR_POP observability B 版本；但那會涉及 firmware/MIF/SOF provenance，必須先獨立 commit，再 clean build、compile、program，並另寫一份完整燒錄實驗紀錄。本紀錄本身不宣稱 Step 4 通過，也不自動 merge main。

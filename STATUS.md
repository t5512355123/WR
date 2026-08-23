# DE5a White Rabbit 目前狀態

## 最新 Step 4 HIGH qualification abort 回繞計數實驗（2026-08-24，source `3b42769`）

本輪由 exact source commit `3b427696d94afc927db8ce8e3a73a46570589d41` 完成 fresh firmware、
Quartus 17 clean compile、雙板 program 與 read-only runtime 量測。唯一變因是把既有
32-bit HIGH qualification-abort 診斷由 saturating 改成 free-running wrapping arithmetic；
functional trigger condition、deglitch FSM 與 WR/SoftPLL 行為均未修改。

- Master/Slave programmer checksum：`0x30ADC41E / 0x30AD7EE3`；兩片均 configuration
  succeeded、0 errors、0 warnings。
- Step 1/2：兩片 PASS；Step 3：Slave PASS。Master/Slave focused samples 均為 30/30
  valid，Slave `MODE=3/PTP=9`、foreign=`1/0`、RX=`0x1001`、TX=`0x1000`、
  `LOCK_ENABLE=4`。
- Slave live WR state 與其他握手證據仍衝突，保留 `STATE_EVIDENCE=READ_INCONSISTENT`，
  不當成 Step 3 regression。
- Step 4 T0：Slave REF/FB HIGH-abort modulo-32 delta=`344,766,461 / 344,367,796`；
  T1=`344,677,586 / 344,253,442`。
- Slave T0/T1 都是 `GOT_EDGE/GOT_EDGE`；sampled transition 每視窗約增加 `6.89e8`，
  但 accept、tag/TRR、IRQ、state transition、helper delta 全為 0。
- 本輪證明 HIGH qualification abort 正在持續發生，並排除舊 32-bit counter 飽和造成的
  measurement invalid；尚未證明 DDMTD polarity、threshold、timing 或其他特定項目是根因。
- Master/Slave compile 成功但 `TIMING_CLOSED=NO`；只列為 implementation caveat。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_HIGH_QUAL_ABORT_ACTIVE = YES
SLAVE_CURRENT_DEGLITCH_STATE = GOT_EDGE/GOT_EDGE
SLAVE_ACCEPT_AND_DOWNSTREAM_ACTIVITY = NONE_OBSERVED
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824.md`

## 最新 Step 4 HIGH qualification abort 唯讀回讀（2026-08-24，diagnostics `51f874a`）

本輪沿用 source commit `126dda8550db3f8de33c9e37303e4a16aa730350` 的現有 Master/Slave SOF，只以 diagnostics commit `51f874ab052c770d8e35e678f535892c38502847` 執行 read-only JTAG；沒有 firmware build、Quartus compile 或 FPGA program。

- Step 1/2：兩片 PASS；Step 3：Slave PASS，20/20 focused samples 有效。
- Slave REF/FB deglitch state 在 T0/T1 都是 `GOT_EDGE/GOT_EDGE`；sampled transition 持續大量增加，但 accept 與 downstream chain 仍無 sustained activity。
- Slave REF/FB 32-bit HIGH qualification-abort counter 在 T0/T1 的所有 accepted samples 都是 `0xFFFFFFFF`。
- 因 counter 已飽和，`delta=0` 不能判定目前沒有 HIGH qualification abort；這是診斷動態範圍不足，不是 JTAG read failure，也不是已證明的 hardware functional failure。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_HIGH_ABORT32_READBACK = SATURATED
SLAVE_HIGH_ABORT_SUSTAINED_ACTIVITY = MEASUREMENT_INVALID
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-HIGH-ABORT-READBACK-20260824.md`

## 最新 Step 4 LOW qualification abort 實驗（2026-08-24，HEAD `126dda8`）

本輪由 exact source commit `126dda8550db3f8de33c9e37303e4a16aa730350` 完成 fresh firmware、Quartus 17 clean compile、雙板 program 與 read-only runtime 量測。唯一變因是把既有 LOW qualification abort 診斷擴成 32-bit，並分別讀回 REF/FB；functional abort 條件、deglitch FSM 與所有 WR/SoftPLL 行為均未修改。

- Master/Slave programmer checksum：`0x30A84EF1 / 0x30B13132`；兩片均 configuration succeeded、0 errors、0 warnings。
- Step 1/2：兩片 PASS；Step 3：Slave PASS，30/30 focused samples 有效。
- Step 4 T0/T1：sampled transition 每個視窗約增加 `6.85e8`，但 WAIT_EDGE entry、accept、event、tag/TRR、IRQ、state transition、helper 全部 delta=0。
- Slave REF/FB LOW-abort 累計值與 T0/T1 delta 都是 0；不支持 LOW qualification 反覆累積後被中斷的假設。
- Slave current deglitch state 在兩個視窗都是 `GOT_EDGE/GOT_EDGE`，所以不能沿用上一輪 `WAIT_STABLE_0` 的 current-state 定位。
- Master FB LOW-abort 已飽和為 `0xFFFFFFFF`，其 delta=0 不代表沒有活動；Master REF 為 0。
- Slave T0 sampled counter 跨越 32-bit 邊界；modulo delta 與 T1 一致，記為 counter wrap，不當成硬體 reset。
- Master/Slave compile 均成功但 `TIMING_CLOSED=NO`；這仍只列為 caveat。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_LOW_QUAL_ABORT_ACTIVE = NO_EVIDENCE
SLAVE_CURRENT_DEGLITCH_STATE = GOT_EDGE/GOT_EDGE
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824.md`

## 最新 Step 4 WAIT_EDGE 入口實驗（2026-08-24，HEAD `5dcc361`）

本輪由 exact commit `5dcc36190093369f36eee81207ae8e10399360ff` 完成 Master/Slave fresh firmware build、Quartus 17 clean compile、雙板 fresh SOF program，以及 Step 1～4 read-only runtime 量測。唯一變因是新增 REF/FB `WAIT_STABLE_0 -> WAIT_EDGE` 唯讀飽和計數器；沒有修改 WR signaling、PTP、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 firmware 功能行為。

- Master/Slave programmer checksum：`0x30A9E382 / 0x30AA1EE1`；兩片均 configuration succeeded、0 errors、0 warnings。
- Step 1/2：兩片 PASS；Master `MODE=2/PTP=6`，Slave `MODE=3/PTP=9`。
- Step 3：Slave PASS；30/30 valid samples、foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`。
- Step 4 T0/T1：兩板 sampled transition 每個視窗約增加 `6.85e8`，但 WAIT_EDGE entry、accept、event、tag/TRR、IRQ、state transition、helper 全部 delta=0。
- Slave 兩路 deglitch state 都固定為 `WAIT_STABLE_0`，因此目前第一個 source-backed inactive boundary 是 LOW qualification；Master 固定於 `GOT_EDGE`，其 inactive side 不可誤寫成 LOW qualification。
- WAIT_EDGE/accept 累計值非零，表示啟動早期曾有活動；本輪只證明目前沒有 sustained activity。
- Master/Slave compile 均成功，但 `TIMING_CLOSED=NO`；worst setup slack 為 `-0.818 ns / -0.606 ns`，只列為 caveat，尚未證明是根因。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_FIRST_INACTIVE_BOUNDARY = WAIT_STABLE_0_LOW_QUALIFICATION
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-WAIT-EDGE-ENTRY-20260824.md`

## 最新 Step 1～3 唯讀回歸關卡（2026-08-24，diagnostics `9811e3c`）

本輪只修 JTAG Tcl reliability/dashboard 判定並在 current hardware 上執行 read-only regression；沒有修改 RTL/firmware functional behavior、沒有 Quartus compile、沒有 program FPGA。板上 image 沿用上一筆 `c9f1f15` D1 observability 燒錄紀錄，其 White Rabbit functional behavior 沿用使用者指定的 `51864b8` baseline。

- Dashboard 5 s：兩板 Step 1/2 PASS；Slave Step 3 PASS。
- Focused 30 x 1 s：兩板各 30/30 valid、0 invalid、0 counter decrease；Master Step 2 PASS，Slave Step 2/3 PASS。
- Independent register reliability：Step 2/3 critical registers 各 20/20 valid、0 invalid、0 decrease；Master Step 2 PASS，Slave Step 2/3 PASS。
- Slave 30/30 保持 foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。
- Slave live state 與 failure shadow 仍呈 `WRS_IDLE` / historical `WRS_S_LOCK` 衝突；保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，不把它誤判成 Step 3 regression。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
FAILURE_CLASSIFICATION = NO_FAILURE_EVIDENCE_FOR_STEP1_TO_STEP3
```

完整紀錄：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP23-REGRESSION-GATE-20260824.md`

## 最新 Step 4 D1 同步管線實驗（2026-08-24，HEAD `c9f1f15`）

本輪由 exact commit `c9f1f15005fa41b581736ec56c27e207178731ac` 完成 Master/Slave fresh firmware build、Quartus 17 clean compile、雙板 fresh SOF program，以及 Step 1～4 read-only runtime 量測。唯一變因是以同步域內的 `D1_PIPELINE_MISMATCH_COUNT` 取代上一輪會重複取樣非同步 `clk_in` 的 D0 shadow 診斷；沒有修改 WR signaling、PTP、SoftPLL、DDMTD polarity、PI、threshold、DCO、SI5340、PHY 或 firmware 功能行為。

- Master/Slave programmer checksum：`0x30AA777D` / `0x30ADDA10`；兩片均 configuration succeeded、0 errors、0 warnings。
- Step 1/2：兩片 PASS；Master `MODE=2/PTP=6`，Slave `MODE=3/PTP=9`。
- Step 3：Slave PASS；30/30 valid samples、foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`。
- D1 mismatch：Master/Slave、REF/FB、T0/T1 全為 `0`，支持 D0/en→D1 同步管線沒有觀測到不一致。
- Step 4：NOT PASS。兩個視窗中 sampled transition 大量增加，但 accepted DMTD、event、tag、TRR、IRQ、state transition、helper 全部沒有 sustained delta。
- 第一個未形成持續活動的觀測邊界已收斂到 deglitch acceptance；根因仍未證明。
- Master/Slave compile 均成功，但 `TIMING_CLOSED=NO`，worst setup slack 分別為 `-0.404 ns` / `-0.223 ns`。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-D1-PIPELINE-MISMATCH-20260824.md`

## 最新 Step 4 D0 shadow mismatch 實驗（2026-08-24，HEAD `4417411`）

本輪由 exact commit `441741129f160ea0535279d1ad0269540a73073d` 完成 Master/Slave fresh firmware build、Quartus 17 clean compile、雙板 fresh SOF program，以及 Step 1～4 read-only runtime 量測。唯一變因是 REF/FB 的 32-bit `D0_SAMPLE_MISMATCH_COUNT` 診斷，不修改 WR signaling、SoftPLL、DDMTD polarity、PI、threshold、DCO、SI5340、PHY 或 firmware 功能行為。

- Master/Slave programmer checksum：`0x30AC2C0F` / `0x30AC2FC7`；兩片均 configuration succeeded、0 errors、0 warnings。
- Step 1/2：兩片 PASS；Master `MODE=2/PTP=6`，Slave `MODE=3/PTP=9`。
- Step 3：Slave PASS；foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。保留 `POST_STEP3_LOCK_STAGE=TIMEOUT` 與 `STATE_EVIDENCE=READ_INCONSISTENT`。
- Step 4：NOT PASS。T0/T1 中 sampled counters 大量增加，但 accepted DMTD、event、tag、TRR、IRQ、helper 全部沒有 sustained delta。
- D0 mismatch T0/T1 delta：Master REF `28,219,398 / 28,217,927`、FB `23,900,259 / 23,978,711`；Slave REF `74,889,343 / 2,804,355`、FB `15,699,087 / 15,722,369`。
- interpretation caveat：功能 `clk_i_d0` 與 diagnostic `dbg_clk_in_d` 是兩顆獨立暫存器，取樣非同步 `clk_in` 時可能在轉換附近解析不同。counter 增加不能直接證明 functional RTL assignment 壞掉或已找到 Step 4 根因。
- Master/Slave compile 均成功，但 `TIMING_CLOSED=NO`；這仍只是 caveat，不是已證明根因。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
ROOT_CAUSE = NOT_PROVEN
```

完整紀錄與 raw evidence：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-D0-SAMPLE-MISMATCH-20260824.md`

## 最新 Step 2 / Step 3 regression barrier（2026-08-24，Tcl HEAD `f4d47d7`）

本輪只修正 `read_step23_register_reliability.tcl` 的 read-only state 統計保存，並在目前板上 bitstream 執行 repeated JTAG regression；沒有 program FPGA。Master/Slave 各取得 reliability `10/10 valid` samples，exact `f4d47d7` focused Step 2/3 各取得 `20/20 valid` samples；Slave focused gate 為 `signal_good=19`、`signal_bad=1`，仍判定 Step 3 PASS 並保留 state inconsistency。

- Step 1 PHY / Link：PASS
- Step 2 Endpoint / MiniNIC / PTP：PASS
- Step 3 WR Parent / Signaling：PASS；Slave 保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`
- Step 4：本輪未進行 functional experiment；dashboard 旁證仍為 event delta=0，因此不能宣稱 Step 4 已通過

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_EVALUATED_IN_THIS_REGRESSION
```

本輪沒有重新取得板上 SOF/MIF provenance；fresh compile 產物只作未燒錄參考，不能代表 current hardware。完整紀錄與 raw log：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP2-3-REGRESSION-20260824.md`

## 最新 Step 4 診斷摘要（2026-08-23，HEAD `ec3f7cc`）

本輪在 branch `exp/step4-softpll-enable` 由 exact HEAD `ec3f7cc19baec94afc3a98d2a162f9583ce67efd` 完成 Master/Slave clean build、Quartus compile、雙板燒錄與兩個時間點的 read-only regression。唯一變因是新增 `DMTD d0 LOW-run max` 觀測，沒有修改任何 White Rabbit functional behavior。

- Step 1：PASS
- Step 2：PASS
- Step 3：PASS（保留 `STATE_EVIDENCE=READ_INCONSISTENT` 作為 JTAG shadow consistency evidence）
- Step 4：NOT PASS
- Step 4 gate：`STEP4_ALLOWED=YES`，可繼續 read-only source audit；Step 4 尚未通過
- Master/Slave SOF programmer checksum：`0x30A8B5EC` / `0x30AA1736`
- Master/Slave build：均 `Full Compilation was successful`，但 timing `timing_closed=NO`

T0/T1 的 d0 LOW-run max：Master REF/FB=`65535/6`；Slave REF/FB=`7/1`。Slave FB 的 input LOW max=`133`，但 d0 LOW max=`1`、d1 HIGH max=`1`，因此目前把 unresolved region 優先縮小到 `clk_in -> clk_i_d0` sampling boundary；尚未證明 sampler、clock、polarity 或 PHY 是根因。accepted DMTD、tag、TRR、IRQ、helper 在本輪仍沒有 sustained activity，所以 Step 4 不能標示 PASS。

完整紀錄與原始證據：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-D0-LOW-RUN-20260823.md`

最後更新：2026-08-23

目前研究分支：`exp/step4-softpll-enable`

目前 diagnostics HEAD：`ec3f7cc19baec94afc3a98d2a162f9583ce67efd`

本頁只整理目前證據與下一個研究 gate。既有燒錄實驗與 raw log 保留在 `docs/experiments/`，沒有刪除或改寫任何既有實驗紀錄。

## 2026-08-23 Step 4 HIGH qualification max-depth fresh hardware experiment（8c3e039）

本輪從 GitHub exact commit `8c3e0393b9950501a56eb11cb20ce8d6067c7ef0` 重新建置 Master/Slave firmware、執行 Quartus 17 clean compile、燒錄兩片 fresh SOF，再執行 read-only regression。唯一變因是新增 DMTD HIGH qualification 中止前最大 stability depth 的 read-only observability；沒有修改任何 Master/Slave role、PTP、WR signaling、SoftPLL、DDMTD polarity、PI、lock threshold、DCO、SI5340、PHY 或 firmware functional behavior。

- Master / Slave compile 均 `Full Compilation was successful`，但兩份 timing report 都記錄 `timing_closed=NO`。
- Master programmer checksum：`0x309FC2A0`；Slave：`0x30A7D749`；兩片均 `Configuration succeeded`、0 errors、0 warnings。
- 早期 startup window 的 Slave `PTP=8` 只標為 transitional，沒有拿來作 final regression PASS。
- 等待後的 20 samples / 1000 ms focused window：Master `MAC=...01 / MODE=2 / PTP=6`；Slave `MAC=...02 / MODE=3 / PTP=9`、`FOREIGN=1/0`，PTP/MiniNIC activity 有增加，RXERR=0。
- Step 3 final focused gate：Slave `parent=1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`，因此 PASS；`STATE_EVIDENCE=READ_INCONSISTENT` 保留為 shadow/read consistency evidence。
- Step 4 T0/T1：REF/FB HIGH max depth 僅為 Master `0/3`→`0/5`、Slave `0/1`→`0/1`；sampled transition 有活動，但 accepted DMTD、DMTD event、tag、helper 沒有 sustained delta。Slave T0 曾有單次 TRR activity，T1 沒有持續增加，故不足以 PASS。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = STATE_SHADOW_INCONSISTENCY_RETAINED
```

完整 provenance、programmer log、Step 2/3 regression、T0/T1 raw output 與判讀：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-HIGH-MAX-STAB-20260823.md`

## 2026-08-23 Step 2/3 唯讀回歸關卡（本輪未燒錄）

本輪只在 pain 執行既有 JTAG read-only scripts，沒有 Quartus compile、沒有 program FPGA、沒有修改 RTL/firmware 或任何 White Rabbit functional behavior。pain 當時為 detached HEAD `688b152b2551ca51c58b8ec0a40967f5d7e8dca0`；本機目前 branch HEAD 為 `6c9fe1913e3acab41a3c2ffbe15f3bd88dc2582f`。本輪沒有重新量測板上 SOF/MIF hash，因此不能把本輪 runtime 直接宣稱為指定 `51864b874...` 的 fresh image reproduction。

- Step 1 PHY / Link：PASS。兩板 ready/link/RX/TX/CPU reset 正常，RX lock-to-data=1，encoding error=0。
- Step 2 Endpoint / MiniNIC / PTP：PASS。focused script 兩板各 20/20 valid samples；Master `MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`；Slave `MAC=02:00:22:33:44:02`、`MODE=3`、`PTP=9`、`FOREIGN_META=03000001`；PTP/MiniNIC counters 有活動，RXERR=0。
- Step 3 WR Parent / Signaling：PASS。Slave focused 20 samples 都有 `parent=1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。`local_state=0` 與 handshake evidence 不一致，保留 `STATE_EVIDENCE=READ_INCONSISTENT`，不直接改判 hardware failure。
- JTAG measurement：一支 register reliability script 出現跨欄位交錯輸出並標示 Slave Step 3 INVALID；同輪 focused repeated samples 沒有重現該失敗，因此記為 read-path measurement issue，不是已證明的硬體/韌體失敗。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
HARDWARE/FIRMWARE_FAILURE = NOT_ESTABLISHED
JTAG/DASHBOARD_MEASUREMENT_FAILURE = PRESENT_IN_ONE_READ_PATH
```

完整紀錄與 raw logs：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-REGRESSION-READONLY-20260823.md`

## 2026-08-23 Step 4 HIGH qualification-abort fresh hardware experiment（688b152）

本輪由 GitHub exact commit `688b152b2551ca51c58b8ec0a40967f5d7e8dca0` 建立 firmware 與 Quartus fresh SOF，完成雙板燒錄，再執行 focused Step 2/3 regression、Step 4 bounded time-series 與 dashboard。唯一 functional 變因是把既有 DMTD `GOT_EDGE` HIGH qualification-abort read-only counter 擴成 32-bit；計數條件、deglitch threshold、FSM、DDMTD、SoftPLL、WR signaling、PTP、PHY 與所有 control register 行為均未改變。

- Quartus：17.0.0 Build 595；Master/Slave build wrapper 均回報 passed，`timing_closed=NO`。
- Master/Slave MIF、QSF、SDC、SOF SHA256 與完整 build/program/JTAG raw log 見本輪實驗紀錄。
- Master SOF programmer checksum：`0x30A72F9D`；Slave：`0x30A7AF69`；重複燒錄均 `configuration succeeded`、0 errors、0 warnings。
- Step 1：dashboard 兩板 PASS。
- Step 2：最後一次 fresh-SOF focused 20 samples 兩板 PASS；Master `PTP=6`，Slave `PTP=9`、`FOREIGN=1/0`，PTP/MiniNIC counter 有活動，RXERR=0。
- Step 3：Slave focused 20 samples PASS；`parent=1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`，並保留 `STATE_EVIDENCE=READ_INCONSISTENT` / `POST_STEP3_LOCK_STAGE=TIMEOUT`。
- Step 4：NOT PASS。立即窗口中 Slave 的 sampled/accept/event 有短暫進展；接續 30 samples 中 Slave `sampled_delta` 約 `1.17e9`、`accept_delta=0`，HIGH qualification-abort delta 為 reference `584189670`、feedback `582950225`，tag/TRR/IRQ/helper 仍為 0。第一個有直接證據的 inactive boundary 是 `GOT_EDGE -> HIGH qualification abort -> deglitch accept`。
- JTAG/STP：所有 script 都完整結束，回報 `Evaluation ... successful` 與 0 errors/0 warnings；本輪沒有把 invalid mailbox sample 當成硬體錯誤。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = NOT_OBSERVED_FOR_KEY_SAMPLES
```

完整紀錄：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-HIGH-ABORT32-20260823.md`

## 2026-08-23 Step 4 JTAG bounded-group measurement round（64341ca）

本輪只修改 `scripts/jtag/read_step4_startup_focused.tcl` 的 read-only measurement reliability：將 register reads 改為 sample-major bounded groups；單一 mailbox timeout 只標記欄位並繼續其餘 group，最後輸出 `VALID/TIMEOUT/INVALID/PARTIAL`。沒有修改 RTL、firmware、MIF、register address、SoftPLL 或任何 control register；沒有 Quartus compile、沒有 program FPGA。

- `read_step4_startup_focused.tcl 10 500 events` 兩板完整結束，總耗時約 41 秒。
- DMTD boundary、tag arbitration、downstream、event timing 四個 group 在兩板均為 `VALID`，所有 series `timeout=0`、`invalid=0`。
- Master/Slave sampled transition 有活動，accept、DMTD event、tag、TRR、IRQ、helper update 仍為 delta=0；因此 Step 4 仍 `NOT_PASS`，但這次已是完整 measurement evidence。
- `read_wr_handshake_focused.tcl` 20 samples 兩板有效；Step 2 PASS、Slave Step 3 PASS。
- dashboard 完整執行且 Quartus STP 回報 successful、0 errors、0 warnings。

完整紀錄：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-JTAG-BOUNDED-20260823.md`

## 2026-08-23 Step 2/3 read-only regression barrier（c7c690b）

本輪 pain 由 GitHub exact commit `c7c690bc5588a039c6fdf26606f9699ec182c9d9` checkout；只執行既有 JTAG read-only scripts，沒有 Quartus compile，也沒有 program FPGA。因而本輪不能把 `c7c690b` 宣稱為板上 SOF；實際硬體仍沿用前一輪 `0c3fbea` fresh SOF，SOF/MIF provenance 請以 `EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823.md` 為準。

- Step 1：dashboard 兩板均 PASS；ready/link/RX/TX、RX lock-to-data 正常，encoding error=0。
- Step 2：focused script 兩板各 `valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`，Master `PTP_TX_DELTA=43`、Slave `PTP_TX_DELTA=4`，兩板 Step 2 PASS。
- Step 3：Slave focused 20 samples PASS；`FOREIGN=1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。`STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT` 保留為觀測資訊，不直接改判 Step 3 failure。
- Step 4：本輪只做 read-only focused 讀取。script 在 Master 已完成 sampled/accept/seen 與部分下游 series 後，於後續 mailbox 讀取超過三分鐘沒有完成；已停止並保存 partial log。這是 JTAG script timeout，不能當成硬體/SoftPLL failure。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
HARDWARE/FIRMWARE_FAILURE = NOT_ESTABLISHED
JTAG_MEASUREMENT_ISSUE = STEP4_FOCUSED_SCRIPT_TIMEOUT
```

完整紀錄與 raw evidence：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP2-3-READONLY-20260823.md`

## 2026-08-23 最新 fresh Step 2/3 regression 與 Step 4 qualification-abort 實驗（0c3fbea）

本輪由 exact commit `0c3fbea10f8c7ac99f64b6386c6c22226af8e36f` fresh firmware build、Quartus 17 clean compile、雙板 fresh SOF program，再執行 read-only JTAG。沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL、DDMTD polarity、PI、lock threshold、DCO、SI5340 或 PHY functional behavior。

- Master programmer checksum：`0x30A761CC`；Slave programmer checksum：`0x30AA2B3F`；兩片均 configuration succeeded、0 errors、0 warnings。
- Step 1：PASS。兩板 ready/link/RX/TX/CPU reset 正常，encoding error=0。
- Step 2：PASS。20-sample focused regression 通過唯一 MAC、MODE/PTP role、PTP/MiniNIC activity、RXERR=0；Slave `FOREIGN=1/0`。
- Step 3：PASS。Slave 20 samples 都有 parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`；`local_state=0` 的 shadow 與 handshake 證據不一致，保留為 `READ_INCONSISTENT`，不改判 Step 3 failure。
- Step 4：NOT PASS。30 samples 中 sampled transition 有活動，但 accept、DMTD event、tag、TRR、IRQ、helper update 沒有 delta。新 `DMTD_REF_SEEN/FB_SEEN=0x0000FFFF` 解碼為 LOW abort=0、HIGH abort=65535；HIGH abort counter 已飽和，本次窗口 delta=0，不能當成即時 fault rate。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
```

完整 provenance、programmer log、JTAG raw log 與判讀：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823.md`

## 歷史 read-only regression（0548ece，已由 0c3fbea fresh experiment 更新）

本輪只修改 `scripts/jtag/read_wb_runtime.tcl` 的 read validation：PSTAT、WR RX/TX signaling shadow 改用 source-backed validator 與 retry。沒有修改 FPGA RTL、firmware、MIF、SoftPLL、PTP、WR signaling、PHY 或任何 functional control register；沒有 Quartus compile，也沒有 program FPGA。

pain 已 checkout exact commit `0548ece1499d06b793b7fc58fd255250af1a1cf7`。JTAG 使用 Quartus Prime `17.0.0 Build 595`，板上仍是前一輪 `8859959` fresh SOF。

回歸結果：

- Step 1：兩板 PASS。
- Step 2：`read_step23_register_reliability.tcl` 兩板各 `valid=30/30`；focused script 兩板 Step 2 PASS。Master=`MAC 02:00:22:33:44:01 / MODE=2 / PTP=6`；Slave=`MAC 02:00:22:33:44:02 / MODE=3 / PTP=9`；MiniNIC/PTP 有 activity，RXERR=0；Slave `FOREIGN_META=03000001`。
- Step 3：Slave focused 30 samples PASS；`LOCK=0x1001`、`SLAVE_PRESENT=0x1000`、`LOCK_ENABLE=4` 持續成立。`WRS_IDLE` 與這些證據並存，故保留 `STATE_EVIDENCE=READ_INCONSISTENT`、`POST_STEP3_LOCK_STAGE=TIMEOUT`，不宣稱 Step 3 失敗。
- Step 4：仍 NOT PASS。dashboard 與 focused event-chain 都看到 DMTD accept/event 及下游 tag/TRR/IRQ/helper 沒有 sustained delta；本輪沒有修改功能行為。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

完整 raw logs 與判讀見：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP23-REGRESSION-READONLY-0548ECE-20260823.md`。

## 目前結論

本輪只新增 DMTD stability-counter 的 dedicated read-only observability，並精簡 JTAG dashboard 的預設輸出；沒有修改 firmware functional behavior、MIF、SoftPLL、PTP、WR signaling、PHY 或任何控制 register。pain 以 exact HEAD `8859959` 完成 Quartus Prime 17.0 Build 595 clean compile、雙板 fresh SOF program 與 read-only JTAG regression。

Step 2 / Step 3 regression barrier 已重新建立並通過：

- Step 2：兩張板各 30/30 個有效 accepted samples 通過。Master=`MAC 02:00:22:33:44:01 / MODE=2 / PTP=6`；Slave=`MAC 02:00:22:33:44:02 / MODE=3 / PTP=9`；MiniNIC/PTP traffic 有活動，`RXERR` 沒有增加。
- Step 3：Slave 各項 30/30 個有效取樣通過：`FOREIGN_META=03000001`、`parentIsWRnode=1`、`parentCalibrated=1`、RX=`0x1001 LOCK`、TX=`0x1000 SLAVE_PRESENT`、`LOCK_ENABLE>0`。
- `WRS_S_LOCK` 之後曾由 `wr_handshake_fail()` 退回 `WRS_IDLE`，由 source-backed `WR_FAILURE_DEBUG=02020001` 證明；這是獨立的 `POST_STEP3_LOCK_STAGE=TIMEOUT`，不再被誤判為 Step 3 regression failure。
- dashboard 原本的 `WDIAGS_PTP=0xA5A51330` 類 stale mailbox 值現在會被 retry/reject；counter decrease 只列 `COUNTER_RETEST`，不單獨宣稱硬體失敗。

因此目前 gate 為：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

## 2026-08-23 Step 2/3 read-only regression barrier

本次在 branch `exp/step4-softpll-enable` 的 exact commit `618ca6ad3681e302e9a67edf6c3d995e76f3bd41` 執行唯讀 regression。沒有 Quartus compile、沒有 program FPGA；板上仍是前一輪 `8859959` fresh SOF。這個 provenance 邊界已完整記錄於：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP23-REGRESSION-READONLY-20260823.md`

結果如下：

- Step 1：兩板 PHY/link PASS。
- Step 2：兩板 30/30 valid samples PASS；唯一 MAC、MODE/PTP role、MiniNIC/PTP activity 與 RXERR=0 均成立。
- Step 3：Slave focused 30 samples PASS；`FOREIGN_META=03000001`、parent WR/calibrated、`LOCK`、`SLAVE_PRESENT`、`LOCK_ENABLE=4` 均有證據。current state 同時呈現 `WRS_IDLE`，因此保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，不把它直接改判為 failure。
- Dashboard 對 stale/invalid read 的處理在本次完整執行中沒有 Tcl exception；短窗口 PTP_TX=0 只列資訊，不單獨使 Step 2 fail。

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

這次只重新建立 regression barrier，沒有新增 hardware/firmware functional evidence；Step 4 仍維持 `NOT PASS`，不可解讀為 SoftPLL 已 lock。

這只代表可以繼續單一變因的 Step 4 read-only 診斷；本輪 Step 4 尚未通過，也沒有要求 SoftPLL lock 或 `time_valid=1`。

## 2026-08-23 Step 4 sampled-transition fresh experiment

本輪 exact HEAD `67aa10b` 的 fresh build/program 證據已記錄於：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-SAMPLED-TRANSITION-20260823.md`

Step 2/3 focused regression 均 PASS；Slave 仍保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`。20 次、500 ms 間隔的 DMTD boundary observation 顯示 sampled transition counters 有大量活動，但 accept counters、直接 DMTD event、tag/TRR/IRQ/helper 沒有 delta。因此目前第一個已觀測 inactive boundary 是 `clk_sampled -> deglitch stability qualification -> new_edge_p_dmtdclk`，Step 4 為 `NOT_PASS`。這是 source-backed observability boundary，不是已證明的 hardware/firmware root cause。

## 2026-08-23 Step 4 stability-counter fresh experiment

本輪 exact HEAD `8859959` 重新 clean build、program 並執行 100 samples/200 ms 的 stability-counter observation。`SPLL_DMTD_STAB_COUNTERS` 主要讀值為 0/1；Master state 主要為 `REF=WAIT_STABLE_0, FB=GOT_EDGE`，Slave state 主要為 `REF=GOT_EDGE, FB=WAIT_STABLE_0`。sampled-transition activity 仍存在，但沒有形成持續 deglitch accepted edge 或下游 DMTD/tag/TRR/IRQ/helper activity。少數高值與同一 mailbox snapshot 的其他欄位一起錯位，保留為 measurement consistency evidence，不作功能結論。

完整 provenance、programmer checksum、raw JTAG logs 與判定詳見：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-STAB-COUNTER-20260823.md`

因此目前仍為 `STEP4_RESULT=NOT_PASS`，但 Step 4 已獲 barrier 允許，且 Step 2/3 fresh regression 仍為 PASS。

## 六步 milestone

| Step | 目標 | 狀態 | 證據或缺口 |
|---:|---|---|---|
| 1 | QSFP/Native PHY | **PASS** | status probe 顯示 link、PHY ready、RX/TX ready、RX lock-to-data 正常，encoding error 為 0 |
| 2 | Endpoint/MiniNIC/PTP | **PASS（30/30 accepted samples）** | 雙板唯一 MAC、MODE/PTP role、MiniNIC/PTP counters 與 RXERR 均符合 gate |
| 3 | WR Parent/Signaling | **PASS（30/30 accepted samples）** | foreign master、parent flags、`SLAVE_PRESENT`、`LOCK`、`LOCK_ENABLE` 均有 source-backed 證據；另記錄 post-stage timeout |
| 4 | SoftPLL Enable | **NOT PASS / DMTD_EVENT_GENERATION BLOCKER** | 唯讀 30 點 lock/events series 顯示 DMTD event 與下游 tag/TRR/IRQ/helper 沒有 sustained delta；尚未修改功能行為 |
| 5 | DDMTD/SoftPLL/Si5340 closed loop | **NOT DONE** | 尚未要求或驗證 SoftPLL lock、DCO correction 或 SI5340 closed loop |
| 6 | Global Time/execute_at(T) | **NOT DONE** | 尚未實作或驗證依共同 Global Time 在指定 `T` 啟動 accelerator |

## 當前邊界

`POST_STEP3_LOCK_STAGE=TIMEOUT` 是 Step 3 之後的觀測結果，不是 Step 3 gate 失敗。`PSTAT.locked=0`、`time_valid=0` 與後續 SoftPLL event 不活躍仍屬 Step 4/5 範圍；未經下一個明確指令，不修改 SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 control 行為。

## 2026-08-21 Step 4 focused 唯讀分類

本輪唯一變更是新增 `scripts/jtag/read_step4_startup_focused.tcl`，以同一 register 每 100 ms 讀取 30 次，並拒絕 mailbox invalid/stale word。未寫入 Wishbone control register，未 compile，未 program FPGA。

執行：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 30 100 lock
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 30 100 events
```

兩次 Tcl 均由 Quartus Prime 17.0 Build 595 回報 `Evaluation of Tcl script ... successful`、`0 errors, 0 warnings`；兩張板各組資料均為 `valid=30 invalid=0`。

lock-stage classification：

- Master：`WR_LOCK_RESULT=0`、`PSTAT_LOCKED bit=0`、`SPLL_STATE=00020009`，分類為 `TRANSITIONAL_OR_INCONSISTENT`，不是 LOCKED 證據。
- Slave：`WR_LOCK_RESULT` 最後值為 `1`、`WR_LOCK_UNLOCKED_COUNT` 穩定、`WR_LOCK_CALIB_FAIL_COUNT=0`、`PSTAT_LOCKED bit=0`，分類為 `SPLL_UNLOCKED`。
- Slave 的 `WR_LOCK_ENABLE_COUNT=4` 仍證明 Step 3 已進入 enable；`WR_LOCK_RESULT` 出現 decrease/reset 只列為讀值狀態，未直接宣稱硬體失敗。

event-chain classification：

- 兩張板 `CURRENT_TICS` 持續增加，代表 runtime observer 有活動。
- Master/Slave 的 DMTD REF/FB event counter、tag pending/grant、TAG_VALID、TRR_WRITE、IRQ、helper update 在 30 點窗口都沒有正向 delta。
- 依上游到下游的判定，第一個沒有 sustained activity 的已觀測邊界是 `DMTD_EVENT_GENERATION`；不能由此直接宣稱實體 clock、光纖或 SoftPLL 演算法根因。
- 因為 DMTD event 未形成持續活動，Step 4 目前為 `NOT PASS`，後續 tag/TRR/IRQ/FSM/helper 不可單獨解讀為功能故障。

source audit 保持現況：`xwr_core.clk_sys_i=clk_sys_625`、`clk_dmtd_i=QSFPB_REFCLK_p`、`clk_ref_i=QSFPA_REFCLK_p`、`g_use_simple_wa=true`；`wr_core` 有效 `g_softpll_reverse_dmtds=false`，而 `g_divide_input_by_2` 依 `not g_pcs_16bit and not g_softpll_reverse_dmtds` 為 true。本輪未改動這些功能設定。

raw evidence：

- `docs/experiments/exp-step4-softpll-enable/step4_focused_lock_2394a23_20260821.log`
- `docs/experiments/exp-step4-softpll-enable/step4_focused_events_2394a23_20260821.log`

因此目前結論是：`STEP1_REGRESSION=PASS`、`STEP2_REGRESSION=PASS`、`STEP3_REGRESSION=PASS`；`STEP4_ALLOWED=YES` 只表示可繼續 read-only/source audit，並不表示 Step 4 已通過。這一輪沒有 hardware/firmware functional change，也沒有 fresh program evidence。

## 2026-08-21 Step 4 source-only audit

針對 focused read-only 結果的第一個 inactive boundary，本輪只核對 current HEAD 的 clock/reset/data path，沒有修改任何 generic、threshold、polarity 或功能行為。

- Master/Slave top-level 均將 `clk_sys_i` 接到 `clk_sys_625`、`clk_dmtd_i` 接到 `QSFPB_REFCLK_p`、`clk_ref_i` 接到 `QSFPA_REFCLK_p`，並以 `wr_core_reset_n` 作為 WR core reset。
- 兩張板的 Arria 10 transceiver 都是 `g_use_simple_wa => true`；本輪沒有改 PHY。
- `wr_core` 將 `clk_ref_i(0)` 接到 recovered `phy_rx_clk`，feedback 使用 `clk_fb`，DMTD 使用 top-level `clk_dmtd_i`。
- current source 的有效 SoftPLL generic 為 `g_reverse_dmtds=false`；`g_divide_input_by_2` 由 `not g_pcs_16bit and not g_softpll_reverse_dmtds` 推導，在目前 `g_pcs_16bit=false` 下為 true。這些值只被核對，沒有切換。
- `dmtd_with_deglitcher` 先由 `dmtd_sampler` 產生 `clk_sampled`，再在 `clk_dmtd_i` domain 由 `WAIT_STABLE_0 -> WAIT_EDGE -> GOT_EDGE` 產生 `new_edge_p_dmtdclk`；之後透過 `gc_pulse_synchronizer2` 到 `new_edge_p_sysclk`，最後才輸出 `tag_stb_p1_o`。
- 因此現有證據可以把下一個只讀觀測點收斂到 `clk_sampled / deglitch accepted edge / post-CDC edge` 三層，但尚不能單靠 counters 證明是哪一層壞掉。

完整 source line audit 見：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-SOURCE-AUDIT-20260821.md`。

下一輪若仍需繼續，必須先新增 diagnostic-only observability 來分開這三層；在此之前不改 `g_divide_input_by_2`、`g_softpll_reverse_dmtds`、deglitch threshold 或其他 SoftPLL/PHY functional variable。

## 2026-08-20 歷史 fresh HEAD JTAG 證據摘要

| 節點 | MODE | WDIAGS_PTP | MAC | WDIAGS_PTP_RX | WDIAGS_PTP_TX | WDIAGS_FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6 | `02:00:22:33:44:01` | `0xA8` 起並持續增加 | `0x17D` 起並持續增加 | 不適用 |
| Slave | 3 | 9 | `02:00:22:33:44:02` | `0x17F` 起並持續增加 | `0x75` 起並持續增加 | `0x03000001` |

Step 3 signaling accepted samples：

- Master：`rx_msg=0x1000`、`tx_msg=0x1001`、`fail_state=3`
- Slave：`rx_msg=0x1001`、`tx_msg=0x1000`、`fail_state=2`、`WR_LOCK enable=4`
- Slave：30/30 筆 time-series samples 通過；Master：20/30 筆 accepted，其他為 frame consistency retry

### 證據界線

- `WDIAGS_PTP=6` 是 PPS_MASTER，`WDIAGS_PTP=9` 是 PPS_SLAVE。
- `WDIAGS_PTP_RX/TX` 是 PPSI-level PTP counters，不是 MiniNIC frame counters。
- `WDIAGS_TX/RX` 來自 `minic_get_stats()`，只能解讀為 MiniNIC frame-level traffic。
- `FOREIGN_META=03000001` 是 foreign master / parent discovery 證據，不等於 SoftPLL lock。
- `PSTAT.locked=0` 與 `time_valid=0` 是目前尚未完成 WR timing synchronization 的直接證據。

## 來源與硬體 provenance

先前的恢復成功實驗使用 historical `c88cc05` clean SOF；本次 Step 3 驗證則使用 `exp/step3-wr-handshake` 的 fresh HEAD build 與 fresh SOF。兩者必須分開解讀。current fresh build provenance 如下：

| 節點 | SOF SHA256 | programmer checksum | MIF SHA256 |
|---|---|---|---|
| Master | `1ac0873a3b06b5220cbfc13b6fa243be53ca4a3d7df190d26f0230e0f3df2f43` | `0x30A4A8E2` | `6989b73e3cf3d64a57cfca9f28a2d2625b0c92f90900450db2bd7f24d27c8f3e` |
| Slave | `dbd0a2ab07b7e1b0459568da43b4b323da60055a74f63641d74070e50e705fe3` | `0x30A39139` | `3657f026b9f69cf3e321e142be886eb6cd04945a1bafd36924fa24cd64b45f81` |

每次新的 runtime log 都要記錄：實際 SOF SHA256、SOF 來源 commit/branch、Master/Slave MIF SHA256、Quartus 版本、programmer checksum，以及 JTAG decode script 的 commit 或 blob SHA256。

## 2026-08-20 Step 4 fresh HEAD 唯讀稽核摘要

本輪在 `exp/step4-softpll-enable @ edd1259` 完成 clean firmware build、Quartus 17 clean compile、雙板 fresh SOF programming，並以 JTAG 做 read-only observation。這一輪沒有修改 SoftPLL 演算法、PTP、PHY、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。

已確認的鏈路：

```text
WRS_S_LOCK
  -> locking_enable()                         PASS
  -> spll_init(SPLL_MODE_SLAVE)               PASS
  -> RCER/tagger/ptracker/IRQ/TRR              PASS
  -> helper_update()                           PASS（有活動）
  -> helper correlation / UCNT                 PASS（輸入與 helper 有活動）
  -> DCO runtime request                       BLOCKED（rt_state=2、bus_state=0）
  -> I2C bus transaction completion             NOT OBSERVED
  -> completed DCO step                        NOT OBSERVED（STEP=0）
```

fresh runtime snapshot 顯示：Master `MODE=2/PTP=6/status=FF`；Slave `MODE=3/PTP=9/status=CF`、`FOREIGN_META=03000001`。Slave 的 `REF/TAG/IRQ/TAG_VALID/TRR_WRITE/UCNT` 持續增加，helper correlation 欄位也會變化；但 DCO correlation 反覆為 `DCO_DEBUG=FF6800000008A3A2`，即 `rt_state=2`、`bus_state=0`、`BUSY=1`、`STEP=0`、`HPLL_LOAD=0`、`ERROR=0`，DAC shadow 不變。

source audit 顯示 DCO 外層 state machine 使用 50 MHz `iCLK`，而 `i2c_bus_controller_dco` 使用 `clock_divider` 產生的較慢 clock。現行 state 1 的 `runtime_start/bus_start` 可能只存在一個 50 MHz cycle，未必被 I2C controller 看到；進入 state 2 後又等待永遠沒有出現的 `bus_state`。這支持「跨時脈 request pulse 被漏採樣」是目前優先假設，但尚不能單憑 snapshot 宣稱 I2C 實體線路故障。

完整資料見：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-WDIAGS-MAP-FIX-2-20260820.md`。

## 2026-08-20 Step 4 DDMTD 預設方向恢復實驗摘要

本輪唯一 functional 變因是移除 Master/Slave 的 `g_softpll_reverse_dmtds => true`，恢復 c88 預設取樣方向。結果為 Master `MODE=2/PPS=6`、Slave `MODE=3/PPS=9`；但 Slave `FOREIGN_META=00000001`、DCO `STEP=0`。完整紀錄與 raw output 位於：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-RESTORE-DDMTD-20260820/`

本輪證據支持「Master role blocker 已改善」，不支持「Step 2/Step 4 已完成」。

## 2026-08-20 Step 4 fresh HEAD DMTD blocker 更新

同一份 `51864b8` fresh SOF 的 clock activity 與極簡 DMTD 20 秒重測已完成：

- `QSFPB_REFCLK/DMTD` source clock 計數在 1 秒觀測中確實增加，`PHY_READY=1`、`RX_LOCK_DATA=1`。
- `CURRENT_TICS` 在 20 秒中持續增加，表示 observer/runtime 沒有停止。
- `REF_EVENTS`、`FB_EVENTS`、last-event ticks 與 tag counters 沒有形成持續 delta；主要 reset bits=0。
- 因此 Step 4 目前仍是 **NOT PASS**，第一個已證明沒有 sustained activity 的節點是 `dmtd_with_deglitcher -> dmtd_event_sys`，下游 `tags_p/TRR/IRQ/helper/DCO` 也未活動。
- 這是 observability boundary，不是已證明的 root cause；本輪沒有修改 DDMTD polarity、PI、lock threshold、DCO gain 或 SI5340。

Raw log 與完整 provenance：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-FRESH-HEAD-20260820/`

## 本次文件整理範圍

本次只更新：

- `docs/debug/jtag_register_map.md`
- `STATUS.md`
- `docs/MERGE_READINESS.md`
- `docs/experiments/exp-step3-wr-handshake/EXP-WRPC-STEP3-FRESH-HEAD-20260819.md`
- `docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-FRESH-HEAD-RETEST-20260820.md`
- `docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-RESTORE-DDMTD-20260820.md`

本次文件更新沒有修改 functional RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control；Step 3 fresh HEAD 的硬體實驗與原始輸出已在 `EXP-WRPC-STEP3-FRESH-HEAD-20260819.md` 記錄。

## 下一步

1. 保留 `31f2b51` 作為 current Step 2 fresh-program reference；其 focused raw evidence 已解碼出 Slave `FOREIGN_META=03000001` 等價狀態。
2. 先唯讀追查 WR signaling 為何停在 `local_state=0`，再判斷 `WRS_S_LOCK` 後 SoftPLL/DCO 第一個無活動節點；不要先調 PI/lock threshold。
3. 保留所有 Step 4 A/B 實驗與 raw logs；下一次燒錄前先 commit/push，再由 pain pull exact commit。

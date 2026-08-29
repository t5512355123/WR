# EXP-WRPC-STEP5-JTAG-HPLL-BOUNDED-BURST-AB-20260830

## 結論

本輪在同一個 paired fresh-program image 上，使用一次 JTAG `0 -> 1 -> 0` 觸發，證明 Slave controller 能自行串行完成 8 個 forced HPLL runtime transaction：

```text
JTAG_TRIGGERED_8_STEP_BURST = PASS
STEP4B_SLAVE_SOFTPLL_STARTUP = PASS
ACTUATOR_TO_MEASUREMENT_COUPLING = NOT PASS / NOT RESOLVED
STEP5_CLOSED_LOOP_LOCK = NOT PASS
MERGE_APPROVED = NO
```

這不能宣稱 Step5 pass。8 個 forced transaction 雖然全部完成，但 helper 的 clamp 前 error、raw tag、expected tag、tag delta 與 helper update count 在同一個 bounded window 內都沒有變化；目前最接近的證據 boundary 是 **SI5340 actuator transaction 已完成，但 feedback measurement 沒有反映到 helper/tag path**。

## 固定版本與產物

```text
branch = exp/step5-softpll-lock
HEAD = 48fb047ee91b958af00ebb00f2b49c49602e1081
experiment = EXP-WRPC-STEP5-JTAG-HPLL-BOUNDED-BURST-AB-20260830
source = one JTAG source pulse; controller internally serializes burst_size=8
```

Pain 端重新建置並燒錄兩張板：

```text
Master SOF SHA256 = ac059cddc980ab86fec797737de6be48c628d4c13debb3ebb80c98dc9292f156
Slave  SOF SHA256 = 366ce27a5e9d5491a3c2eab1192bcd0a1fd4eadfaf3bbe6cac0024cc6996fe39
Master programmer = success, 0 errors
Slave programmer  = success, 0 errors
TIMING_CLOSED = NO
```

## 實驗方法

1. A window：JTAG source 維持 low，先建立背景計數。
2. B window：讀取 `B_BEFORE`，只發出一次 source `0 -> 1 -> 0`。
3. reader 等待 Slave probe 37 的 forced-completed counter 到達 8；沒有手動發出八個 pulse。
4. 同一時間讀取 DCO step、burst counter，以及既有 read-only WDIAGS helper/tag shadow。

Probe 37 欄位：

```text
[7:0]   BURST_TRIGGER_COUNT
[15:8]  FORCED_HPLL_PENDING_COUNT
[23:16] FORCED_HPLL_COMPLETED_COUNT
[31:24] RT_STATE_ENTER_COUNT
[39:32] RUNTIME_START_COUNT
[47:40] BUS_DONE_COUNT
[63:48] DCO_STEP_COUNT
```

## Slave B window 結果

```text
B_BEFORE:
  STEP = 476
  BURST_TRIGGER_COUNT = 0
  FORCED_HPLL_PENDING_COUNT = 0
  FORCED_HPLL_COMPLETED_COUNT = 0
  RT_STATE_ENTER_COUNT = 220
  RUNTIME_START_COUNT = 148
  BUS_DONE_COUNT = 9
  PRECLAMP_ERROR_SIGNED = -9555272
  RAW_TAG = 4156866
  EXPECTED_TAG = 47929866
  TAG_DELTA = 15310
  EXPECTED_DELTA = 16384
  HELPER_UPDATE_COUNT = 0x00002377

B001 after one controller-serialized burst:
  STEP = 484
  BURST_TRIGGER_COUNT = 1
  FORCED_HPLL_PENDING_COUNT = 8
  FORCED_HPLL_COMPLETED_COUNT = 8
  RT_STATE_ENTER_COUNT = 228
  RUNTIME_START_COUNT = 172
  BUS_DONE_COUNT = 33
  PRECLAMP_ERROR_SIGNED = -9555272
  RAW_TAG = 4156866
  EXPECTED_TAG = 47929866
  TAG_DELTA = 15310
  EXPECTED_DELTA = 16384
  HELPER_UPDATE_COUNT = 0x00002377
```

直接差分：

```text
DELTA_BURST_TRIGGER_COUNT = 1
DELTA_FORCED_HPLL_PENDING_COUNT = 8
DELTA_FORCED_HPLL_COMPLETED_COUNT = 8
DELTA_STEP = 8
DELTA_RT_STATE_ENTER_COUNT = 8
DELTA_RUNTIME_START_COUNT = 24
DELTA_BUS_DONE_COUNT = 24
DELTA_PRECLAMP_ERROR = 0
DELTA_RAW_TAG = 0
DELTA_EXPECTED_TAG = 0
DELTA_TAG_DELTA = 0
DELTA_EXPECTED_DELTA = 0
DELTA_HELPER_UPDATE_COUNT = 0
```

前六項證明「單一 JTAG 觸發 → 8 個 pending admission → 8 個完整三寫入 runtime transaction」成立；後六項顯示此次 bounded burst 沒有在 helper/tag measurement shadow 形成對應變化。

## 同一 SOF 的 runtime dashboard

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4B Slave SoftPLL Startup pass
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

STEP5_LOCKDET_BEFORE: HELPER locked=0 cnt=1/10000 threshold=200 MAIN enabled=0 PSTAT_locked=0
STEP5_LOCKDET_AFTER:  HELPER locked=0 cnt=1/10000 threshold=200 MAIN enabled=0 PSTAT_locked=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此使用者畫面若仍顯示 Step4 error，與這次固定 `HEAD/SOF` 的 live reader 不一致；本輪同一 SOF 的 Step4B 已由 dashboard 明確判定 PASS。Step5 尚未完成，不能 merge。

## 原始證據

- [JTAG bounded-burst raw log](raw/EXP-WRPC-STEP5-JTAG-HPLL-BOUNDED-BURST-AB-20260830/jtag-hpll-bounded-burst-ab.log)
- [runtime dashboard raw log](raw/EXP-WRPC-STEP5-JTAG-HPLL-BOUNDED-BURST-AB-20260830/dashboard-after.log)
- [bounded-burst reader](../../../scripts/jtag/read_step5_jtag_hpll_bounded_burst_ab.tcl)
- [controller RTL](../../../quartus/jtag_runtime_diag/si5340a_controller_dco.v)


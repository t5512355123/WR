# EXP-WRPC-STEP5-BURST-TO-HELPER-UPDATE-CORRELATION-20260830

## 結論

本輪在 fresh-reprogram 的同一個 Slave SOF 上，重用 8-step JTAG-triggered bounded burst；待 forced burst 完成後，繼續觀察到 helper update，再比較 pre-clamp error 與 tag shadow：

```text
JTAG_TRIGGERED_8_STEP_BURST = PASS
HELPER_UPDATE_AFTER_BURST = OBSERVED
ACTUATOR_TO_MEASUREMENT_COUPLING = OBSERVED_BUT_WRONG_DIRECTION
STEP5_CLOSED_LOOP_LOCK = NOT PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

8-step burst 之後確實有新的 helper sample，但 pre-clamp error 的絕對值增加、遠離 0；因此目前 evidence 指向 **DCO/FINC-FDEC direction polarity 需要下一輪 A/B**，尚不能宣稱 closed-loop lock。

## 固定版本與產物

```text
branch = exp/step5-softpll-lock
source/SOF commit = 48fb047ee91b958af00ebb00f2b49c49602e1081
reader commit = 9a2fc28
experiment = EXP-WRPC-STEP5-BURST-TO-HELPER-UPDATE-CORRELATION-20260830
controller burst size = 8
```

Slave 在執行前重新 program，以清除前一輪 sticky `force_hpll_seen` 與 burst counters；上一輪未重新 program、因此第二次 trigger 未被接受的 raw 已保留並排除，不納入本結論。

```text
Slave SOF SHA256 = 366ce27a5e9d5491a3c2eab1192bcd0a1fd4eadfaf3bbe6cac0024cc6996fe39
programmer = success, 0 errors
TIMING_CLOSED = NO
```

## 實驗方法

1. fresh program Slave，同一 SOF source 保持 low。
2. A window 讀取背景 activity。
3. B window 先讀 `B_BEFORE`，只發出一次 JTAG `0 -> 1 -> 0`。
4. controller 內部自行串行 8 個 forced HPLL requests；reader 不手動發 8 次 pulse。
5. 強制完成數到達 8 後，繼續輪詢，直到觀察到 `HELPER_UPDATE_COUNT` 相對 burst completion 增加，並保存第一個觀測到的後續 helper sample。

## Slave forced burst 直接證據

`B_BEFORE -> B001`：

```text
STEP: 235 -> 243
DELTA_STEP = 8

DELTA_BURST_TRIGGER_COUNT = 1
DELTA_FORCED_HPLL_PENDING_COUNT = 8
DELTA_FORCED_HPLL_COMPLETED_COUNT = 8
DELTA_RT_STATE_ENTER_COUNT = 8
DELTA_RUNTIME_START_COUNT = 24
DELTA_BUS_DONE_COUNT = 24

DELTA_HELPER_UPDATE_COUNT = 4108
PRECLAMP_ERROR: -38113244 -> -42920312
DELTA_PRECLAMP_ERROR = -4807068
RAW_TAG changed; TAG_DELTA: 15207 -> 15216
EXPECTED_DELTA remained 16384
```

這次與上一輪不同：burst window 內已觀察到 helper update 與 tag shadow 變化，因此「沒有 measurement sample」的證據缺口已排除。

## Burst completion 後第一個 helper-update 觀測

`B001 -> H005`：

```text
STEP: 243 -> 243
DELTA_STEP = 0
DELTA_FORCED_HPLL_PENDING_COUNT = 0
DELTA_FORCED_HPLL_COMPLETED_COUNT = 0
DELTA_HELPER_UPDATE_COUNT = 4107

PRECLAMP_ERROR: -42920312 -> -47718234
DELTA_PRECLAMP_ERROR = -4797922
RAW_TAG changed; TAG_DELTA: 15216 -> 15219
EXPECTED_DELTA remained 16384
```

`H005` 是 burst completion 後 reader 首次觀察到 helper update count 增加的 sample；不是宣稱硬體只增加了一次 update。此 sample 顯示 pre-clamp error 仍朝更負方向移動。

## 同一 SOF 的穩定 runtime dashboard

緊接 burst 後的第一次 dashboard 取樣曾因 WR handshake 尚未穩定而回報 `Step3=NA`；等待 20 秒後的有效重讀為：

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4B Slave SoftPLL Startup pass
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

HELPER locked=0 cnt=0/10000 threshold=200
MAIN enabled=0 locked=0
PSTAT_locked=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

所以 Step4B 仍是 PASS；Step5 仍未完成。第一次 dashboard 的 transient `BLOCKED_BY_STEP3` 不覆蓋等待後的穩定 repeated result。

## 目前判定與下一步

```text
STEP4B = PASS
STEP5 = NOT PASS
ACTUATOR_TO_MEASUREMENT = OBSERVED, BUT ERROR MOVES AWAY FROM ZERO
NEXT_REQUIRED_EXPERIMENT = polarity A/B using the same bounded trigger path
MERGE_APPROVED = NO
```

本輪沒有修改 PI gain、lock threshold、lock samples、DMTD 或 PTP/PHY；也沒有因為結果不理想而直接改 polarity。下一輪應由分支5先明確指定 polarity A/B 的唯一 functional change 與 acceptance criteria。

## 原始證據

- [JTAG burst-to-helper-update raw log](raw/EXP-WRPC-STEP5-BURST-TO-HELPER-UPDATE-CORRELATION-20260830/jtag-burst-to-helper-update-correlation.log)
- [dashboard immediately after burst](raw/EXP-WRPC-STEP5-BURST-TO-HELPER-UPDATE-CORRELATION-20260830/dashboard-after.log)
- [dashboard after 20-second settling wait](raw/EXP-WRPC-STEP5-BURST-TO-HELPER-UPDATE-CORRELATION-20260830/dashboard-after-wait.log)
- [bounded-burst reader](../../../scripts/jtag/read_step5_jtag_hpll_bounded_burst_ab.tcl)


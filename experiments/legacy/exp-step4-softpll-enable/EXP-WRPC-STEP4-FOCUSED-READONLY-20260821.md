# EXP-WRPC-STEP4-FOCUSED-READONLY-20260821

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-FOCUSED-READONLY-20260821`
- 日期：2026-08-21
- Branch：`exp/step4-softpll-enable`
- Git commit：`2394a23937838f11f63660a0465f48a88038a419`
- 實驗類型：JTAG read-only diagnostics
- Quartus：17.0.0 Build 595（僅執行 `quartus_stp`）
- FPGA program：本輪未執行
- Quartus compile：本輪未執行

## 想驗證什麼

在不改變 White Rabbit 功能行為的前提下，將 Step 4 的 lock-stage 與 event-chain 觀測分開，確認：

1. SoftPLL lock result 是否能透過同一 register 的連續有效讀值分類。
2. DMTD event、tag、TRR、IRQ、sequencer、helper update 的第一個 inactive boundary 在哪裡。
3. `DECREASED_OR_RESET` 是否只是 counter/read snapshot 狀態，而不是直接的硬體失敗。

## 相較 baseline 唯一修改

新增 read-only script：

```text
scripts/jtag/read_step4_startup_focused.tcl
```

SHA256：

```text
B3C58BB4CB39E2CB424F400507AE09C8538C132D3A0284D4AC69FC95CC394E44
```

此 script：

- 每個 register 以同一地址獨立取樣 30 次。
- 每次取樣間隔 100 ms。
- mailbox invalid/stale word 最多 retry 5 次，無效資料不混入判定。
- 只讀取 register，不寫入 `WDIAGS_CTRL` 或其他 Wishbone control register。
- 不讀取會改變狀態的 `TRR_R0`，避免診斷本身消耗事件。

沒有修改 RTL、firmware、MIF、SoftPLL、PTP、WR signaling、PHY、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340。

## 執行命令與工具結果

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 30 100 lock
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 30 100 events
```

兩次執行皆由 Quartus 回報：

```text
Evaluation of Tcl script ... was successful
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

兩張板的兩組取樣均為 `valid=30 invalid=0`，本輪沒有 JTAG timeout 或 stale mailbox sample 混入結果。

## Lock-stage 結果

### Master：DE5 [1-11.1]

| Register | first | last | delta |
|---|---:|---:|---:|
| `WR_FAILURE_DEBUG` | `01030001` | `01030001` | 0 |
| `WR_LOCK_RESULT` | `00000000` | `00000000` | 0 |
| `WR_LOCK_POLL_COUNT` | `00000000` | `00000000` | 0 |
| `WR_LOCK_UNLOCKED_COUNT` | `00000000` | `00000000` | 0 |
| `WR_LOCK_CALIB_FAIL_COUNT` | `00000000` | `00000000` | 0 |
| `WR_LOCK_ENABLE_COUNT` | `00000000` | `00000000` | 0 |
| `SPLL_STATE` | `00020009` | `00020009` | 0 |
| `PSTAT_LOCKED` | `00000001` | `00000001` | 0 |

解碼後 `PSTAT_LOCKED` 的 lock bit 為 0；依 focused script 分類為 `TRANSITIONAL_OR_INCONSISTENT`。這不是 Master 已 locked 的證據，也不是單憑本輪 read-only snapshot 宣稱 Master functional failure。

### Slave：DE5 [1-11.2]

| Register | first | last | delta |
|---|---:|---:|---:|
| `WR_FAILURE_DEBUG` | `02020001` | `02020001` | 0 |
| `WR_LOCK_RESULT` | `00000100` | `00000001` | `DECREASED_OR_RESET` |
| `WR_LOCK_POLL_COUNT` | `000E8B36` | `000E8B36` | 0 |
| `WR_LOCK_UNLOCKED_COUNT` | `000E8B36` | `000E8B36` | 0 |
| `WR_LOCK_CALIB_FAIL_COUNT` | `00000000` | `00000000` | 0 |
| `WR_LOCK_ENABLE_COUNT` | `00000004` | `00000004` | 0 |
| `SPLL_STATE` | `00030009` | `00030009` | 0 |
| `PSTAT_LOCKED` | `00000001` | `00000001` | 0 |

解碼後 `PSTAT_LOCKED` 的 lock bit 為 0，且 `WR_LOCK_RESULT=1`；`WR_LOCK_UNLOCKED_COUNT` 很大但在窗口內沒有增加，`WR_LOCK_CALIB_FAIL_COUNT=0`。因此 focused script 分類為 `SPLL_UNLOCKED`。`WR_LOCK_RESULT` 的 decrease/reset 只作為讀值狀態保存，不能單獨當作硬體 failure。

`WR_LOCK_ENABLE_COUNT=4` 與前一輪 Step 3 證據一致，表示本輪不是在重新判定 Step 3。

## Event-chain 結果

兩張板的 event series 共同呈現：

- `CURRENT_TICS` 持續增加，runtime observer 仍在活動。
- DMTD REF/FB event counter 沒有正向 delta。
- tag pending、tag grant、TAG_VALID、TRR_WRITE、IRQ、sequencer transition、HELPER_UPDATE 都沒有正向 delta。
- 因為上游 DMTD event 已沒有 sustained activity，不能只看下游零值就宣稱 tag/TRR/IRQ/FSM/helper 各自是獨立根因。

因此由上游往下游判斷，第一個已被本輪資料支持的 inactive boundary 是：

```text
DMTD_EVENT_GENERATION
```

這是觀測邊界，不是已證明的實體 clock、光纖、deglitch 或 SoftPLL 演算法根因。

## Raw evidence

| 檔案 | SHA256 |
|---|---|
| `step4_focused_lock_2394a23_20260821.log` | `A9433A51A51930CB034D8B3E6B735F1137FA43F6D6F504F4F198888A932B64B8` |
| `step4_focused_events_2394a23_20260821.log` | `201000029DC3FBF217750B13EEEAA8D7E185C05604EEDE0F6F580341D172F3D6` |

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT PASS
```

本輪沒有重新燒錄，因此沒有新增「fresh HEAD → SOF → program」證據。讀值本身有效且可重現，結果目前應解讀為 **SoftPLL/DMTD event-chain 的 read-only observation blocker**，不是已證明的 hardware/firmware functional failure。

## Next Step

先做 source-only audit，追查目前 exact HEAD 的：

```text
clk_in / clk_dmtd
  -> dmtd_sampler
  -> clk_sampled
  -> deglitch FSM
  -> new_edge_p_dmtdclk
  -> CDC
  -> new_edge_p_sysclk
  -> tag_stb_p1
```

只核對現有 source 的 clock wiring、reset、`g_divide_input_by_2` 與 `g_softpll_reverse_dmtds`；在取得 source-backed 差異前，不修改這些功能變因，也不進行 Step 4 functional program。

# EXP-S5-SLOCK-POLL-CALIB-CAUSE-AUDIT-20260914

## 結論

本輪的 S_LOCK cause telemetry：**PASS_READ_ONLY**。

本輪新增的 packed detail 直接記錄最近一次 `locking_poll()` 的：

```text
return code
spll_check_lock() result
calib_t24p() attempted/succeeded/failed
t24p calibrated state
```

結果顯示：Slave 確實曾經先達到 SoftPLL 的完整內部 lock chain，但在 WR protocol 完成之前，Master 已先進入 `WR_M_LOCK_TIMEOUT`。Slave 隨後在約 136.886 秒出現 `SPLL_SEQ_READY + PSTAT_LOCKED + TRACKING`，共 34 個 tracking samples；約 142.864 秒之後才因 `WR_LOCKED_TIMEOUT`／`HANDSHAKE_FAILURE` 被 disable。

這表示目前最有價值的根因方向已從「SoftPLL 完全沒有鎖」收斂為：**WR master/slave extension handshake 沒有在 PLL lock 後完成；且 calibration failure/retry 的紀錄需要補上 successful early-return path 才能做最後因果閉合。**

Step5 closed-loop lock：**NOT COMPLETE**。

## 實驗身分與可追溯性

- source commit: `88596aa8a0419f2ce1667f3a8202043124c34585`
- branch: `exp/step5-softpll-lock`
- experiment ID: `EXP-S5-SLOCK-POLL-CALIB-CAUSE-AUDIT-20260914`
- changed files:
  - `vendor/wrpc-sw/ppsi/arch-wrpc/wrpc.h`
  - `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c`
  - `vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c`
  - `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c`
  - `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl`
- Pain checkout: exact commit above, detached HEAD
- Quartus: 17.0.0 Build 595
- capture mode: read-only Wishbone/JTAG observer
- observer deadline: 240000 ms
- actual observer elapsed: 241504 ms
- physical power-cycle: completed by user before this round
- raw transfer SHA-256: `e4b87e44f39fe60ae0e90fee89c01298d37548ee7a39545a37184c56b6f5f229`

本輪的 firmware telemetry 只保存診斷結果，不改變任何 `locking_poll()` return、WR timeout、retry、SoftPLL lock threshold、PI、DCO 或 reset 行為。完整輸出在 `raw/`。

## Build、燒錄與 transport

兩個 firmware 與兩個 Quartus image 均成功完成；兩張 DE5 均以同一輪 fresh image programming 成功。Timing closure 仍為 `NO`，所以本輪不宣稱 timing pass。

| role | SOF SHA-256 | Quartus full compile | programming | timing closed |
| --- | --- | --- | --- | --- |
| Master | `d66e4d14f143fa9585061607206d4dbda167da7a37c1fb8167c4de5eb4a5f9af` | PASS | PASS | NO |
| Slave | `5f25cb4dfc8bfbcd4f7715f4516883da26e65236ef01536adc4cf1fbe0a4df2c` | PASS | PASS | NO |

Build logs 的最後結果都是 `Quartus Prime Full Compilation was successful`；program logs 都是 `Configuration succeeded`、`0 errors, 0 warnings`。

JTAG/Wishbone preflight：

```text
WB_REQUEST_COUNT = 352
PRELOAD_COUNT = 352
COMMIT_COUNT = 352
PROBE_3WAY_MATCH_COUNT = 352
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Preflight 的 Step1/Step2 已通過；Slave Step3 仍被 dashboard 判為 invalid，原因是最後的 `WR_TX_SIGNAL_DEBUG` 為 `LOCKED count=5`，而既有 gate 只接受 `SLAVE_PRESENT 0x1000`。這是目前 gate 與「last transmitted signaling message」語意不一致的 measurement limitation，不能把它當成 PHY/endpoint failure。

## Observer 結果

| role | samples | sample errors | frame invalid | boot generation | first tracking | tracking samples | first WR failure | first disable | inactive boundary |
| --- | ---: | ---: | ---: | --- | ---: | ---: | --- | --- | --- |
| Master | 85 | 0 | 7 | 1 → 1, changes=0 | NEVER | 0 | 57834 ms, `WR_M_LOCK_TIMEOUT` | 57834 ms | `WR_EXTENSION_FAILURE` |
| Slave | 85 | 0 | 3 | 1 → 1, changes=0 | 136886 ms | 34 | 142864 ms, `WR_LOCKED_TIMEOUT` | 142864 ms | `WR_EXTENSION_FAILURE` |

Slave 的 milestone 順序是：

```text
1153 ms      DMTD/TAG/TRR/IRQ/Helper activity
70463 ms     Main enabled
79535 ms     Main frequency locked
136886 ms    SPLL_READY, Main phase/Main lock, PSTAT_LOCKED, TRACKING
142864 ms    WR_LOCKED_TIMEOUT, HANDSHAKE_FAILURE, WR disabled
```

最後樣本仍可看到內部 PLL lock bits，但 WR state 已是 `WRS_IDLE`，PPSI 已是 failure；因此最後的內部 tracking 不能作為有效 Step5 session。

## S_LOCK cause detail

在 Slave 尚未 lock 的樣本中，packed detail 是：

```text
SLOCK_TRACE_POLL_RET = 0x00000001
locking_poll()       = 1 (WRH_SPLL_UNLOCKED)
spll_check_lock()    = 0
calib_t24p()         = not attempted
```

在約 136.886 秒起，detail 變成：

```text
SLOCK_TRACE_POLL_RET = 0x00000B01
locking_poll()       = 1 (WRH_SPLL_UNLOCKED)
spll_check_lock()    = 1
calib_t24p()         = attempted
calib_t24p()         = failed
t24p_calibrated      = 0
```

同一段觀測的 `LOCK_CALIB_FAIL_COUNT=0x224`，即 recorder 看見多次 calibration failure；但 `WR_STATE` 在 139879 ms 的樣本已呈現 `next=4 (WRS_LOCKED)`，表示在兩個稀疏 sample 之間曾有 successful return，把 state machine 推到 `WRS_LOCKED`。目前 `state-wr-s-lock.c` 在 `locking_poll()==WRH_SPLL_LOCKED` 時會直接 return，沒有寫入 S_LOCK trace，所以 trace 保留的是前一次 `0xB01` failure。這不是矛盾，而是本輪還未捕捉成功 early-return path。

因此本輪能確定：

```text
PLL lock reached before WR_LOCKED_TIMEOUT       PASS
calib_t24p failures were observed                PASS
successful locking_poll() boundary               INFERRED, not directly traced
Master sent/Slave received CALIBRATE successfully NOT PROVEN
```

## L2 DCO cross-check

最後 Slave sample 的 producer counters：

```text
L2_MAIN_START_COUNT = 26648
L2_MAIN_COMPLETED = 26648
L2_HELPER_START_COUNT = 10303
L2_HELPER_COMPLETED = 10303
L2_MAIN_FAILED = 0
L2_HELPER_FAILED = 0
L2_ACK_EVENTS = 0
L2_TIMEOUT_EVENTS = 0
L2_FIRST_LOSS_VALID = 0
```

因此 L2 的 logical start/completion contract 仍然是閉合的，沒有 evidence 指向 producer-side DCO starvation 或 L2 transaction error。本輪不能把這些 firmware counters 等同於外部 SI5340 readback 成功。

## Step5 判定

```text
STEP5 = NOT_COMPLETE
STEP5_PASS = false
```

不能 pass 的原因：

1. Master 先在 57.834 秒進入 `WR_M_LOCK_TIMEOUT`，因此沒有形成可持續的兩板 WR extension session。
2. Slave 雖在 136.886 秒出現 34 筆有效格式的 internal tracking，但在 WR handshake 完成前於 142.864 秒進入 `WR_LOCKED_TIMEOUT`。
3. Slave 的 Step3 gate 仍因 last TX signal 語意造成 `INVALID`，Step4B/Step5 upstream gate 仍被阻擋。
4. 還沒有三次 fresh-program、有效 WR session 內連續 `PSTAT.locked` 的 reproducibility evidence。

## 下一輪

下一輪仍只做診斷，不先改 PI 或 timeout：

1. 在 `wr_s_lock()` 的 `poll_ret == WRH_SPLL_LOCKED` early return 前寫入一次成功 detail，捕捉 `0x1700` 類的 success record。
2. 同時在 Master `wr_m_lock()` 記錄收到 `LOCKED`、送出 `CALIBRATE`／等待 CALIBRATE 的明確 message boundary。
3. 以同一個 240 秒窗口確認：Slave 的 successful S_LOCK 是否發生在 Master timeout 之前，以及 Master 是否根本沒有活到能處理 Slave 的 `LOCKED`。

只有這個因果邊界確認後，才選擇唯一的 production fix（若確實是 Master WR timeout policy 或 message progression），並重新做 cold-program repeat；本輪不 merge 到 main。


# EXP-S5-L2-TELEMETRY-CONTRACT-EDGE-AND-MASTER-WIRING-20260914

## 結論

本輪 L2 DCO liveness telemetry contract：**PASS_READ_ONLY**。

本輪修正了兩個診斷缺口：

1. `runtime_start` 是等待 I2C 接受期間維持的 level；liveness recorder 改為只在 rising edge、且 runtime FSM 位於第一個 logical write 時計一次，避免把同一 transaction 的每個 clock 都誤算成新的 service start。
2. Master top level 原本未接出 probes 52–61；本輪把既有 DCO liveness payload 接到 Master 的 diagnostic probes，使 Master 的 `TIMEOUT` 與 producer-side zero 可區分。

兩項修改都只增加診斷可觀測性，沒有修改 production runtime FSM、I2C arbiter、PI 參數、WR timeout、SoftPLL lock 條件或 reset 行為。

Step5 closed-loop lock：**NOT COMPLETE**。

這輪雖然證明 Slave 的 DCO logical start/completion 計數已相等，且沒有 recorded failure、ACK error 或 timeout event，但兩板仍未形成有效的 WR upstream session：Master 進入 `WR_M_LOCK_TIMEOUT`，Slave 之後進入 `WR_S_LOCK_TIMEOUT`／`HANDSHAKE_FAILURE`。Slave 在 WR failure 之後才出現少量內部 `TRACKING` 樣本，不能作為 Step5 pass。

## 實驗身分與可追溯性

- source commit: `3fab754bc54f08cf4dc76112c6073778517972ca`
- branch: `exp/step5-softpll-lock`
- experiment ID: `EXP-S5-L2-TELEMETRY-CONTRACT-EDGE-AND-MASTER-WIRING-20260914`
- changed files:
  - `quartus/jtag_runtime_diag/si5340a_controller_dco.v`
  - `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`
- Pain host: `pain`
- Quartus: 17.0.0 Build 595
- capture mode: read-only Wishbone/JTAG observer
- observer deadline: 240000 ms
- actual observer elapsed: 240573 ms
- physical power-cycle: completed by user before this round
- raw transfer SHA-256: `c8318a51f2f72f601eab4e09abbc1560370664ec3ee15beb863a7f6dbbf974b2`

Source file hashes and all build/program/observer outputs are in `raw/`. The raw checksum manifest records the remote capture paths; the raw transfer hash above verifies the local archive transfer.

## Build、燒錄與 transport preflight

兩個 firmware 與兩個 Quartus image 均建置成功；兩張 DE5 均燒錄成功。Timing report 仍標示 `timing_closed=NO`，因此這不是 timing closure 的通過證據。

| role | firmware ELF SHA-256 | MIF SHA-256 | SOF SHA-256 | build | programming | timing closed |
| --- | --- | --- | --- | --- | --- | --- |
| Master | `c5e9511c6b49ae9141c16ef0d6c8a0bae54fef3bccc907409c9441bc9d45378b` | `439e6cdc0a8caeb00b335918cc23a11418bd41f2dba16f080909f9a410547b33` | `4d90c41999dfcbc4536aee7b77d13a3482a5b81cf720d524f40eca42da7f010b` | PASS | PASS | NO |
| Slave | `ae44c58306297875103da1fb867e708fda5cfeab5cc2d922e1903281f098061a` | `609a26a1c7a712e2d45407da905f38756b950f1590aa027555e5ac3eaeb85b28` | `216b1df9f32db97dbb6c48ecc2fa6e23da091f532ef2d00e689ab6c55a410890` | PASS | PASS | NO |

JTAG/Wishbone preflight：

```text
WB_REQUEST_COUNT = 353
PRELOAD_COUNT = 353
COMMIT_COUNT = 353
PROBE_3WAY_MATCH_COUNT = 353
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

上游狀態仍是：

```text
Master: STEP1=PASS, STEP2=PASS, STEP4A=PASS
Slave:  STEP2=INVALID, STEP4B_ALLOWED=NO, STEP4B_RESULT=BLOCKED_BY_STEP2
```

## Observer 結果

| role | samples | sample errors | frame invalid | boot generation | first tracking | tracking samples | first WR failure | first inactive boundary |
| --- | ---: | ---: | ---: | --- | --- | ---: | --- | --- |
| Master | 85 | 0 | 7 | 1 → 1, changes=0 | NEVER | 0 | 641 ms, `WR_M_LOCK_TIMEOUT` | `WR_EXTENSION_FAILURE` |
| Slave | 85 | 0 | 3 | 1 → 1, changes=0 | 217517 ms | 7 | 172652 ms, `WR_S_LOCK_TIMEOUT` | `WR_EXTENSION_FAILURE` |

所有 boot generation 在窗口內維持不變，沒有新的 CPU、WR core 或 SI configuration reset 證據。少數 frame invalid 樣本保留為 snapshot consistency caveat。

### Master

Master 從觀測起點即已處於 `WR_M_LOCK_TIMEOUT`／`HANDSHAKE_FAILURE` 的失效歷史，整個窗口沒有 `ACQUISITION → TRACKING`，也沒有 Main DCO transaction start。這不代表 Master image 沒有 producer payload，因為本輪已把 payload 接到 probes；它表示在本次有效讀取中沒有觀測到 Main producer transaction。

Master Helper liveness 的穩定值為：

```text
L2_HELPER_START_COUNT = 1929
L2_HELPER_COMPLETED = 1929
L2_MAIN_START_COUNT = 0
L2_MAIN_COMPLETED = 0
L2_MAIN_FAILED = 0
L2_HELPER_FAILED = 0
L2_ACK_EVENTS = 0
L2_TIMEOUT_EVENTS = 0
```

### Slave

Slave 在約 1.142 秒開始出現 DMTD、TAG、TRR、IRQ、Helper update，約 172.652 秒進入 `WR_S_LOCK_TIMEOUT`／`HANDSHAKE_FAILURE`。在約 217.517 秒才觀察到內部 `SPLL_SEQ_READY`、Helper locked、Main frequency/phase/Main locked 與 `PSTAT_LOCKED=1` 同時為真；這只留下 7 個稀疏 tracking 樣本，且全部發生在 WR failure/disable 之後，所以不符合有效 WR session 內的 Step5 條件。

最後一筆 Slave 樣本（238570 ms）的關鍵值：

```text
WR_STATE = WRS_IDLE
WR_FAILURE = WR_S_LOCK_TIMEOUT
WR_DISABLE = valid=1, cause=HANDSHAKE_FAILURE
SPLL_SEQ_STATE = SEQ_READY
PSTAT_LOCKED = 1
N2_PHASE = TRACKING
```

這組資料應解讀為「WR 先失敗後，內部 PLL 狀態仍可能短暫／延遲地到達 tracking」，不能解讀為 Step5 已鎖定。

## L2 counter contract 判定

本輪的重點是先把 recorder 語意固定，再讀結果；不能把 counter 數值直接當成外部 SI5340 readback 成功。

Master 與 Slave 的診斷 payload 均可讀取。Slave 最後樣本：

```text
L2_MAIN_PENDING_COUNT = 50527
L2_HELPER_PENDING_COUNT = 15357
L2_MAIN_START_COUNT = 48947
L2_HELPER_START_COUNT = 15357
L2_MAIN_COMPLETED = 48947
L2_HELPER_COMPLETED = 15357
L2_MAIN_FAILED = 0
L2_HELPER_FAILED = 0
L2_ACK_EVENTS = 0
L2_TIMEOUT_EVENTS = 0
L2_FIRST_LOSS_VALID = 0
L2_MAIN_MAX_WAIT = 4114539  (raw recorder units)
L2_HELPER_MAX_WAIT = 1       (raw recorder units)
L2_MAIN_MAX_LATENCY = 61441  (raw recorder units)
L2_HELPER_MAX_LATENCY = 61441 (raw recorder units)
```

因此本輪可判定：

```text
logical start = logical completion       PASS
recorded failed/ACK/timeout             0
producer-side DCO activity              OBSERVED on Slave
external SI5340 transaction readback    NOT PROVEN by these counters
```

`L2_FIRST_LOSS_VALID=0` 時，`L2_FIRST_LOSS_REASON` 的非零內容不具有效語意，不能拿來當作 loss cause。`L2_STATUS_TIME` 與 wait/latency 是 recorder raw units，本輪不將其換算成毫秒。

## Step5 判定

```text
STEP5 = NOT_COMPLETE
STEP5_PASS = false
```

原因是：

1. Slave preflight Step2 仍為 `INVALID`，沒有形成可接受的 WR upstream session。
2. Master 先出現 `WR_M_LOCK_TIMEOUT`；Slave 先出現 `WR_S_LOCK_TIMEOUT`／`HANDSHAKE_FAILURE`。
3. Slave 的 7 筆 late tracking 全部在 WR failure/disable 之後，不能當作 Step5 的有效 continuous producer evidence。
4. 本輪雖已閉合 L2 recorder 的 start/completion 關係，但沒有因此證明 `PSTAT.locked` 在有效 WR session 內持續成立，也沒有達成三次 fresh-program reproducibility。

本輪不是 Step5 pass，也不應 merge 到 main。

## 下一步

下一輪只追一個因果問題：**為什麼 Slave `locking_poll()` 在 `WR_S_LOCK` 期間持續回傳非成功，最後落到 `WR_S_LOCK_TIMEOUT`？**

先做 read-only source audit 並加入最小 persistent breadcrumbs，分開記錄：

```text
S_LOCK entry
locking_poll return
spll_check_lock result
calib_t24p return/result
retry/deadline transition
```

在未拿到這些因果證據前，不再調 PI、DCO bias、WR timeout 或 arbiter。只有當結果明確顯示是 production control bug，才進行單一功能修改並重跑同一 cold-program / observer 窗口。


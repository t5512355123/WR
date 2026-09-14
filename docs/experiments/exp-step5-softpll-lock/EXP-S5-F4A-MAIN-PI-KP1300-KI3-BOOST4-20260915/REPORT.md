# EXP-S5-F4A-MAIN-PI-KP1300-KI3-BOOST4-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`0b0893d80380566af4ba5cbcfd4ba93e0c65fa14`

## Verdict

```text
SOURCE_BUILD = PASS
PROGRAM = PASS
POST_COLD_PREFLIGHT = FAIL (two captures)
MASTER_STEP4A = PASS
STEP4B_ALLOWED = NO
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
F4A_DECISION = BLOCKED_BY_UPSTREAM_SIGNALING
MERGE_APPROVED = NO
```

本輪沒有合法的 Slave Step4B/Step5 觀測窗，因此不能把本輪判成
`MAIN_PHASE_LOCK` 失敗，也不能宣稱 Step5 pass。依停止條件，本輪在 preflight
retry 後停止，不執行 coherent Step5 observer。

## 實驗目的與唯一功能變因

本輪依 Fable 的 F4a 建議，保留 F3a 的 operating point：

```text
bootstrap_steps = 3388
helper_kp = -2250
helper_ki = -2
helper_phase_guard = 8 s
```

唯一 production functional change 位於
`vendor/wrpc-sw/softpll/spll_main.c`：

```diff
-MPLL_FREQ_PRELOCK_GAIN_BOOST 20
+MPLL_FREQ_PRELOCK_GAIN_BOOST 4
-Main PI kp=300, ki=1
+Main PI kp=1300, ki=3
```

其餘 Helper、bootstrap、WR timeout、RTL arbitration 與 observer 讀取語意均未
在本輪修改。由於 `spll_main.c` 同時編入 Master/Slave firmware，本輪兩張板
都使用同一個 F4a source image；本資料不足以單獨證明 upstream regression 的
因果來源，但已足以判定本輪不能進 Step5。

## Laptop → GitHub → Pain

Pain 從 GitHub 拉取並核對：

```text
REMOTE_HEAD = 0b0893d80380566af4ba5cbcfd4ba93e0c65fa14
BRANCH = exp/step5-softpll-lock
```

### Clean build

Master 與 Slave 均由 Pain 重新執行 firmware build 與 clean Quartus 17.0
compile，兩者 exit code 都為 0：

```text
MASTER_BUILD = PASS, 01:38:51–01:43:37 +08:00
SLAVE_BUILD  = PASS, 01:43:37–01:49:05 +08:00
```

Fitter 成功，但 timing 仍未 closed（既有 implementation caveat）：

```text
MASTER WNS = -0.251 ns
SLAVE  WNS =  0.032 ns
TIMING_CLOSED = NO
```

本輪 fresh SOF：

```text
MASTER SOF SHA256 = 77715de0741ab6495e4677a484fcecd5675dbba3af9a83001d5366042ddad319
SLAVE  SOF SHA256 = 0a1b8e6323f405d2cd733c5f97780cd24b1cb9b3a48d1fdbf1835c02689a78e4
```

### 實際燒錄

兩張 DE5 均由 direct Quartus programmer 完成配置：

```text
Master cable DE5 [1-11.1]：Configuration succeeded，0 errors，0 warnings
Slave  cable DE5 [1-11.2]：Configuration succeeded，0 errors，0 warnings
PROGRAM_ORDER = MASTER → 46 s → SLAVE
```

## 冷開機後 preflight

使用者已完成實體冷開機；SSH recovery probe 回報 `PAIN_SSH_OK`。冷開機後重新
拉取、build、program，並完成 120 s settled wait。第一次 preflight 於
`01:54:58` 開始，retry 前再等待 60 s，第二次於 `01:57:32` 開始；兩份完整
輸出保存在 `raw/`。

### Master

Master 的 JTAG/WB transport 是可信的，Step4A event chain 仍持續活動：

```text
STEP1_REGRESSION = FAIL
WR_READY = 0
CORE_TM_LINK_UP = 0
CORE_LINK_OK = 0
WR_RX_READY = 0
WR_TX_READY = 0
STEP4A_RESULT = PASS
DMTD_ACCEPT_DELTA = 36805
TAG_VALID_DELTA = 23554
TRR_WRITE_DELTA = 23557
TRR_POP_DELTA = 23629
IRQ_DELTA = 23629
HELPER_UPDATE_DELTA = 23629
ΔBOOT_GENERATION = 0
ΔCPU_RESET = 0
ΔWR_CORE_RESET = 0
ΔSI_CONFIG_DROP = 0
```

這表示 CPU/diagnostic/Step4A event path 有在運作，但不能替代 Slave 的 WR
upstream prerequisite。

### Slave

兩次 preflight 都得到同一個阻斷狀態：

```text
STEP1_REGRESSION = FAIL
WR_READY = 0
CORE_TM_LINK_UP = 0
CORE_LINK_OK = 0
WR_RX_READY = 0
WR_TX_READY = 0
WR_RX_LOCKED_TO_DATA = 0
WDIAGS_PTP = LISTENING (raw=00004104)，不是 SLAVE
parentIsWRnode = 0
parentCalibrated = 0
WR_RX_SIGNAL_DEBUG = UNKNOWN, count=0
WR_TX_SIGNAL_DEBUG = UNKNOWN, count=0
LOCK_ENABLE = 0
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

因此沒有執行 F4a 的 120-s smoke 或 6000-s long observer；若強行執行，會把
upstream failure 與 phase-lock failure 混在一起。

### JTAG/WB data-quality gate

這次 failure 不是 JTAG mailbox timeout 或地址污染造成的：

```text
WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
WB_REQUEST_COUNT = 354 (first) / 353 (retry)
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

## 判讀

1. `STEP4B_ALLOWED=NO` 是硬性停止條件；本輪沒有任何 Step5 phase-lock
   evidence。
2. Master Step4A 仍通過且 reset delta 為 0，說明「整板完全死機」不是目前
   最貼近的描述；Slave 的 WR parent/signaling 尚未形成可供 Step4B 使用的
   session。
3. F4a 的 Main PI 變更與本輪 upstream 不成立在同一個 fresh image 中，但
   這批資料不能把它直接定性為唯一根因。下一輪必須先做 known-good Main PI
   control，將「F4a 軟體變更」與「冷開機/鏈路恢復條件」分離。

## 下一步

下一輪回到流程第一步，建立 F4a control：

```text
EXP-S5-F4A-CONTROL-RESTORE-MAIN-PI-UPSTREAM-20260915
```

只將 Main 恢復為 F3a 已知基準 `kp=300, ki=1, prelock_boost=20`，保留
bootstrap 3388、Helper `-2250/-2` 與 guard 8 s；重新走完整
Laptop→GitHub→Pain build/program→preflight。若 control 恢復 Step3/4B，才
能把 F4a 標成 upstream regression，並設計「僅 Slave Main PI」的隔離變因；若
control 仍失敗，則先處理外部 WR signaling/啟動條件，不再調 PI。

## Raw evidence

```text
raw/build_jtag_master.log
raw/build_jtag_slave.log
raw/build_info_jtag_master.txt
raw/build_info_jtag_slave.txt
raw/program-master.log
raw/program-slave.log
raw/preflight-wb-runtime-post-powercycle.log
raw/preflight-wb-runtime-post-powercycle-retry.log
raw/preflight-post-powercycle-timeline.log
raw/image-sha256.txt
raw/checksums.sha256
```

Pain 原始壓縮檔與完整 Quartus compile logs 另保留在 `raw-transfer/`。

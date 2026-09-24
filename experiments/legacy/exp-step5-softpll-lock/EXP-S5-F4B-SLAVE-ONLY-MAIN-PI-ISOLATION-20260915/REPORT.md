# EXP-S5-F4B-SLAVE-ONLY-MAIN-PI-ISOLATION-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`55398347a4f290bac870e9b382fe5dcb5fbd5ff4`

## Verdict

```text
SOURCE_BUILD = PASS
PROGRAM = PASS
PREFLIGHT_INITIAL = STEP4B_BLOCKED_BY_STEP3
PREFLIGHT_RETRY_AFTER_60S = STEP4B_BLOCKED_BY_STEP3
JTAG_WB_PATH = TRUSTED
STEP5_OBSERVER = NOT_RUN (UPSTREAM_GATE_INVALID)
STEP5 = NOT_EVALUATED
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
MERGE_APPROVED = NO
```

本輪沒有取得合法的 Step5 observer window，因此不能把本輪判成
`MAIN_PHASE_LOCKED=0`，也不能判成 Step5 fail。可判定的結果是：F4b
在 Slave image 中加入候選 Main PI 後，Slave upstream Step3 gate 仍未成立。

## 實驗目的與唯一變因

F4a 將候選 Main PI 同時放入兩張 image 後，曾造成 upstream gate 失效；F4a
control 恢復 baseline 後可通過 Step4B，但 Main phase 仍未鎖定。本輪做
per-image isolation：

```text
Master image：control
  DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 0
  MPLL_FREQ_PRELOCK_GAIN_BOOST = 20
  Main PI kp = 300, ki = 1

Slave image：candidate
  DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 1
  MPLL_FREQ_PRELOCK_GAIN_BOOST = 4
  Main PI kp = 1300, ki = 3
```

其餘條件固定：

```text
bootstrap_steps = 3388
helper_kp = -2250
helper_ki = -2
helper_phase_guard = 8 s
helper_threshold = 2000
helper_lock_samples = 1000
normal_hpll_cooldown_loads = 0
hpll_code_per_physical_step = 64
WR timeout = 60 s
```

本輪只新增 image identity 與 compile-time isolation；沒有修改 production
PI/RTL 的其他控制流程，也沒有修改 observer 或觸發 PI snapshot。

## Laptop → GitHub → Pain

Laptop 先完成 source audit 與 replay regression：`7/7 OK`，再將
`55398347` push 到 GitHub。Pain 端核對：

```text
REMOTE_HEAD = 55398347a4f290bac870e9b382fe5dcb5fbd5ff4
BRANCH = exp/step5-softpll-lock
MASTER identity macro = 0
SLAVE identity macro = 1
```

### Clean build

```text
MASTER_BUILD = PASS, 02:47:35–02:51:44 +08:00
SLAVE_BUILD  = PASS, 02:51:44–02:56:18 +08:00
TIMING_CLOSED = NO
MASTER WNS = -0.251 ns
SLAVE  WNS =  0.032 ns
```

Fresh SOF：

```text
MASTER SOF SHA256 = fdc091bb89747c9e90e2b9081647365d09c31cee890bd28c06dc6aed9d1c2a5b
SLAVE  SOF SHA256 = 19b9e7086fc5d0d677ed158deadc8ce100d947bf2706d5cc08b7cddf63b67288
```

### 實際燒錄

```text
Master cable DE5 [1-11.1]：Configuration succeeded，0 errors，0 warnings
Slave  cable DE5 [1-11.2]：Configuration succeeded，0 errors，0 warnings
PROGRAM_ORDER = MASTER → 46 s → SLAVE
SETTLE = 120 s
```

## Read-only preflight

第一次 preflight 與等待 60 秒後的 retry 都得到相同結果。Master control
維持正常；Slave PHY/link 與 endpoint/parent 狀態可見，但 Step3 的訊號
語意不符合 gate 要求：

```text
Master STEP1/STEP2/STEP3/STEP4A = PASS

Slave STEP1 = PASS
Slave STEP2 = PASS
Slave WR_RX_SIGNAL_DEBUG = WR_MODE_ON, count=4
      expected = LOCK, 0x1001, count > 0
Slave WR_TX_SIGNAL_DEBUG = CALIBRATED, count=4
      expected = SLAVE_PRESENT, 0x1000, count > 0
Slave LOCK_ENABLE = 1 (>0)
Slave STEP3 = ERROR

STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP3
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

兩次 preflight 的 transport 證據仍可信：

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

因此這不是 JTAG transport timeout 或 observer 資料品質問題；是合法
Step4B window 尚未建立。依停止條件，本輪沒有執行 120-s smoke 或 6000-s
long observer，也沒有進行任何參數調整。

## 判讀

1. Master image 使用 control 設定時，Master upstream 維持 PASS；因此本輪
   不是兩張 image 都一起失效。
2. Slave image 只切換到候選 Main PI/boost 後，兩次 preflight 仍在同一個
   Slave Step3 signaling boundary 停止。這與 F4a global candidate 的現象
   一致，支持「候選 Main 啟動設定可能使 Slave upstream signaling 不穩定」
   的工作假說。
3. 這仍不是單一參數的正式因果證明，因為本輪同時改了 Slave 的 Main PI
   與 prelock boost；更不能用本輪資料推論 phase lock 或 Step5 結果。

## 下一步

依 Fable 的隔離原則，下一輪拆開 F4b 的兩個候選變因：保留 Slave-only
`Main kp=1300, ki=3`，先恢復 `MPLL_FREQ_PRELOCK_GAIN_BOOST=20`，Master
繼續使用 control。實驗名稱：

```text
EXP-S5-F4C-SLAVE-ONLY-MAIN-PI-KP1300-KI3-BOOST20-20260915
```

仍須先完成 clean build/program 與 settled preflight；若 Step3/Step4B
再次失效，立即停止並記錄，不啟動 observer。只有 Step4B 合法後，才可做
smoke，再做 long capture，回答候選 Main PI 是否能讓 `MAIN_PHASE_LOCKED`
成立。

## Raw evidence

```text
raw/build-master.log
raw/build-slave.log
raw/build-timeline.log
raw/build_info_jtag_master.txt
raw/build_info_jtag_slave.txt
raw/program-master.log
raw/program-slave.log
raw/program-timeline.log
raw/settle-timeline.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-retry.log
raw/preflight-timeline.log
raw/image-sha256.txt
raw/git-head.txt
raw/git-status.txt
```

Pain 原始壓縮檔、完整 build logs 與兩份 fresh SOF 保留於
`raw-transfer/` 與 `quartus/`。

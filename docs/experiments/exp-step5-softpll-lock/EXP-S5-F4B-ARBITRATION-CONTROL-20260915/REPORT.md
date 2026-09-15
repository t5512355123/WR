# EXP-S5-F4B-ARBITRATION-CONTROL-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
硬體 source commit：`a1980bff30231376a3182486fd786d906876c2d4`

## Verdict

```text
SOURCE_BUILD = PASS (Master + Slave)
PROGRAM = PASS (Master + Slave)
PREFLIGHT_INITIAL = STEP4B_BLOCKED_BY_STEP2
PREFLIGHT_RETRY_AFTER_60S = STEP4B_PASS
JTAG_WB_PATH = TRUSTED
L1_DCO_LIVENESS = PASS
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
MERGE_APPROVED = NO
```

本輪不能判定 Step5 通過。F4b 的 RTL 仲裁修改已在模型測試與硬體上證明
Helper 可以取得服務並維持活動，但 Slave 的 Main 仍只有 frequency lock，沒有
進入 phase lock/PSTAT locked。

## 實驗目的與唯一功能變因

本輪驗證 Fable F4b：當 Main 與 Helper 同時有殘差時，讓 normal HPLL request
優先於 DPLL request；bootstrap 與 forced request 的既有順序保持不變。硬體使用
control image，兩張 image 的 Main-PI candidate 都關閉：

```text
DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 0 (Master)
DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 0 (Slave)
```

有效的 RTL 變更是 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

```text
normal HPLL residual / explicit normal pending
    -> DPLL residual
    -> forced HPLL pending
```

`bootstrap`、`forced`、SoftPLL PI、lock detector、WR timeout 均未在本輪調整。

固定控制參數：

```text
bootstrap_steps = 3388
helper_kp = -2250
helper_ki = -2
helper_phase_guard = 8 s
helper_threshold = 2000
helper_lock_samples = 1000
normal_hpll_cooldown_loads = 0
hpll_code_per_physical_step = 64
Main PI = kp 300, ki 1, prelock boost 20
WR timeout = 60 s
```

## Laptop → GitHub → Pain

Pain 已從 GitHub 拉取上述 source commit。兩張 image 均 clean build 成功，
Quartus 版本為 17.0.0 Build 595；programmer 也回報兩個 cable
`Configuration succeeded`，順序為 Master → 約 45 s → Slave。

```text
MASTER_SOF_SHA256 = ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400
SLAVE_SOF_SHA256  = ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092
MASTER_WORST_SETUP_SLACK = -0.047 ns
SLAVE_WORST_SETUP_SLACK  = -0.268 ns
TIMING_CLOSED = NO (separate implementation caveat)
```

## Upstream preflight

第一次 settled preflight 的 Slave Step2 尚未有效，因此依停止規則沒有把那一筆
當成 Step5 結果。等待 60 s 後 retry 建立了合法觀測前提：

```text
Master STEP1/STEP2/STEP3/STEP4A = PASS
Slave  STEP1/STEP2/STEP3/STEP4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

## RTL liveness test

Pain 在上板前重跑 `tb_dco_liveness.sv`。核心結果：

```text
MAIN_JUMP:              MAIN_COMPLETED=4  HELPER_COMPLETED=0
HELPER_JUMP:            MAIN_COMPLETED=0  HELPER_COMPLETED=4
MAIN_HELPER_CONTENTION: MAIN_COMPLETED=204 HELPER_COMPLETED=4
MAIN_BEFORE_FIRST_HELPER = 5
FIRST_HELPER_TIME_NS = 9540
WRONG_PAGE = 0
SEQUENCE_ERRORS = 0
L1_TEST_RESULT = PASS
```

這證明仲裁不再讓 Helper 在 Main backlog 下永久餓死；它不是 PLL phase lock
或 Step5 pass 的證據。

## Hardware observer

觀測腳本的參數 `120` 與 `6000` 是 sample count，不是秒數。依 observer
自身的 timestamp，smoke 實際有效 wall time 為約 16.790 s；long capture
為約 845.143 s（6000 筆樣本）。這裡以 raw timeline 的實際時間為準。

### 120-sample smoke

```text
measurement/coherent samples = 120/120
position snapshots = 90
helper_error_rms = 105.0057
helper_error_max_abs = 239
fraction outside actual threshold = 0
helper locked = 120/120
low/high rail fraction = 0/0
normal request delta = 1608
normal completed delta = 1607 (不同有效 snapshot，不作差值推論)
MAIN_FREQ_LOCKED = 1
MAIN_PHASE_LOCKED = 0
PSTAT_LOCKED = 0
RESET_STABLE = PASS
```

### 6000-sample long capture

離線 replay 沒有信任 observer 最後一筆非原子欄位，而是逐筆重新解析 raw：

```text
measurement valid = 6000/6000
frame valid = 5949/6000
coherent measurement = 6000/6000
position valid = 4766/6000
helper_error_mean = -0.1818
helper_error_rms = 107.5892
helper_error_max_abs = 466
fraction outside actual threshold = 0
helper locked = final 1; no lock-count rise/fall
low/high rail fraction = 0/0
SPLL_DELOCK_COUNT delta = 0
BOOT_GENERATION delta = 0
CPU_RESET delta = 0
WR_CORE_RESET delta = 0
SI_CONFIG_RESET delta = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
MAIN_FREQ_LOCKED = 1
MAIN_PHASE_LOCKED = 0
MAIN_LOCKED = 0
PSTAT_LOCKED = 0
full-chain duration = 0
strict replay Step5 = false
```

`NORMAL_REQ` 與 `NORMAL_COMPLETED` 的 valid snapshot 數量不同，不能把兩個
observer summary 的 delta 直接相減宣稱 backlog 或遺失。可以確定的只有：DCO
request/completion counters 持續活動、Helper measurement 維持可信、但 Main
phase lock bit 全程未成立。

## 判讀

1. F4b 的主要假設在 liveness 層成立：Helper 在 Main backlog 競爭下仍得到服務，
   硬體上的 Helper error 也從先前的高幅度 hunting 降到約 105–108 RMS，沒有
   rail 或 reset。
2. 這沒有解決 Step5 的最後邊界。即使 Helper 保持 locked，Main 仍停在
   `frequency locked`，`MAIN_PHASE_LOCKED` 與 `PSTAT_LOCKED` 都是 0。
3. 因此目前不能把問題再簡化成「Helper starvation」；下一輪需要直接觀察
   Main service、phase PI input/output 與 phase detector/lock flags 的新鮮度，
   才能區分 Main 沒有更新、phase PI 沒有有效輸入，或 phase detector 沒有達到
   lock 條件。

## 下一步

依最新診斷建議，下一輪先做純診斷工作包：

```text
EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915
```

保留 candidate 0/0、F4b 仲裁與全部控制參數；先做合法的短 smoke，再做長
觀測。只增加 Main service→phase PI→detector 的 raw 關聯欄位，不修改
production C/RTL，不調 PI、timeout 或 threshold；資料無法保持新鮮一致時立即
判 `INCONCLUSIVE` 並停止。這個診斷輪本身也不能宣告 Step5 pass。

## Raw / replay evidence

```text
raw/observer-smoke-120.log
raw/observer-long-6000.log
raw/observer-timeline.log
raw/preflight-wb-runtime.log
raw/preflight-wb-runtime-retry.log
raw/preflight-timeline.log
raw/program-master.log
raw/program-slave.log
raw/program-timeline.log
raw/settle-timeline.log
raw/build-master.log
raw/build-slave.log
raw/build-timeline.log
raw/build_info_jtag_master.txt
raw/build_info_jtag_slave.txt
raw/l1-dco-liveness.log
raw/image-sha256.txt
raw/checksums.sha256
analysis/replay-smoke/comparison.csv
analysis/replay-smoke/verdict.json
analysis/replay-long/comparison.csv
analysis/replay-long/verdict.json
raw-transfer/EXP-S5-F4B-ARBITRATION-CONTROL-20260915.tar.gz
```

完整 raw archive 的 SHA256：

```text
810be426d5a3e022f5bd139445137db645a12e9209ab1141c8db61535840f729
```

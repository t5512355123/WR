# EXP-S5-F4B-ARBITRATION-MIXED-SLAVE-CANDIDATE-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`c4294d5e9cbda4c83a5b2b4861aef2421dc9f9cf`

## Verdict

```text
L1_DIRECT_ADMISSION = PASS
SOURCE_BUILD = PASS
PROGRAM = PASS
PREFLIGHT_INITIAL = SLAVE_STEP2_INVALID
PREFLIGHT_RETRY = STEP1_STEP2_STEP3_STEP4B_PASS
STEP4B = PASS (settled retry)
STEP5_OBSERVER = NOT_RUN (PROVENANCE_CONTAMINATED)
STEP5 = NOT_EVALUATED
MERGE_APPROVED = NO
```

本輪先通過了 Fable F4b 意圖的離線 liveness test，接著完成硬體
build/program 與 settled Step4B gate；但在啟動 observer 前發現 source 仍
包含前一輪的 Slave-only Main PI candidate，因此本輪不是「只改 arbiter」的
有效 F4b 單變因實驗。為維持證據品質，本輪不使用硬體資料宣稱 Step5 結果。

## Source 與變因核對

本輪 `c4294d5e` 包含兩部分：

1. Fable F4b 的 DCO idle arbitration：normal HPLL residual/pending 優先於
   DPLL residual，forced/bootstrap 順序維持。
2. 前一輪 F4b isolation 遺留的 image-specific Main PI：Master 為 control，
   Slave 為 candidate。

實際 image identity：

```text
Master DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 0
  Main kp=300, ki=1, prelock_boost=20
Slave  DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE = 1
  Main kp=1300, ki=3, prelock_boost=4
```

所以即使硬體 Step4B 通過，也不能把後續行為歸因於 arbiter 單一變因。

## Laptop → GitHub → Pain

Fable 指定的 liveness test 在 Pain pull 同一 source 後執行：

```text
REMOTE_HEAD = c4294d5e9cbda4c83a5b2b4861aef2421dc9f9cf
L1_CASE=MAIN_HELPER_CONTENTION MAIN_COMPLETED=204 HELPER_COMPLETED=4
L1_CONTENTION MAIN_BEFORE_FIRST_HELPER=5 FIRST_HELPER_TIME_NS=9540
SOURCE_LIVENESS_RISK_REPRODUCED=NO_OR_NOT_REPRODUCED
WRONG_PAGE=0
SEQUENCE_ERRORS=0
L1_TEST_RESULT=PASS
```

NACK completion defect仍如既有 test 所示，但不是本輪變因：

```text
NACKS=1 HELPER_COMPLETED=1 ACK_ERROR=1 DCO_ERROR=0
TRANSACTION_COMPLETION_DEFECT_REPRODUCED=YES
```

## Clean build 與燒錄

```text
MASTER_BUILD = PASS, 08:39:22–08:43:34 +08:00
SLAVE_BUILD  = PASS, 08:44:08–08:53:01 +08:00
TIMING_CLOSED = NO
MASTER WNS = -0.047 ns
SLAVE  WNS = -0.268 ns

MASTER SOF SHA256 = 1872645e33d739f0faf0709592c8b4000ede19ed681245af9232e2af6a8ced8d
SLAVE  SOF SHA256 = 68bd76e1933d16fe042bc2eab2bcd14a83fb4e59efb1ec1193a5733d2b88a840

Master cable DE5 [1-11.1]：Configuration succeeded，0 errors，0 warnings
Slave  cable DE5 [1-11.2]：Configuration succeeded，0 errors，0 warnings
PROGRAM_ORDER = MASTER → 45 s → SLAVE
SETTLE = 120 s
```

## Settled preflight

第一次 preflight 的 Slave Step2 尚在啟動暫態；等待 60 秒後 retry 才作為
settled gate：

```text
Master STEP1/STEP2/STEP3/STEP4A = PASS

Slave STEP1 = PASS
Slave STEP2 = PASS
Slave STEP3 = PASS
  WR_RX_SIGNAL_DEBUG = LOCK count=1
  WR_TX_SIGNAL_DEBUG = SLAVE_PRESENT count=1
  LOCK_ENABLE = 4
Slave STEP4B_ALLOWED = YES
Slave STEP4B_RESULT = PASS
Slave STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

兩次 WB diagnostic transport 均可信；retry 顯示：

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

retry 雖然已到達可觀測條件，但 source provenance 不符合本實驗的單變因
要求，所以沒有執行 smoke 或 6000-s long capture。

## 判讀與下一步

離線 liveness test 的 contention 結果證明「直接以 normal HPLL residual
作 admission」才真正解除 source-level starvation；單純搬移已存在的
`hpll_pending` branch 不足以解決問題。這是 Fable F4b 的正向 source-level
證據。

本輪硬體 gate 也能通過，但它同時含有 Slave-only Main PI candidate，故
不能用來判斷 arbiter 對 Step5 lock 的獨立效果。下一輪回到第 1 步：將
Master 與 Slave 的 identity 都恢復 control（`candidate=0`、Main
`kp=300/ki=1/boost=20`），只保留目前 DCO arbitration 修正；重新做
pull/build/program、settled preflight，再做 120-s smoke 與 6000-s long。

## Raw evidence

```text
raw/l1-dco-liveness-f4b-direct-admission.log
raw/l1-dco-liveness-f4b-direct-admission-timeline.log
raw/f4b-arbiter-build-master.log
raw/f4b-arbiter-build-slave.log
raw/f4b-arbiter-build-timeline.log
raw/f4b-arbiter-program-master.log
raw/f4b-arbiter-program-slave.log
raw/f4b-arbiter-program-timeline.log
raw/f4b-arbiter-settle-timeline.log
raw/f4b-arbiter-preflight.log
raw/f4b-arbiter-preflight-retry.log
raw/f4b-arbiter-preflight-timeline.log
raw/f4b-mixed-git-head.txt
raw/f4b-mixed-image-sha256.txt
build/build_info_jtag_master.txt
build/build_info_jtag_slave.txt
```

完整 raw、build log 與 SOF 保留於 `raw-transfer/`、`build/` 與 `quartus/`。

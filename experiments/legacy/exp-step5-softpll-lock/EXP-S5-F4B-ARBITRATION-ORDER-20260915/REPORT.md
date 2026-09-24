# EXP-S5-F4B-ARBITRATION-ORDER-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`6ec740735a976d7aba0e08deafb1b696bd4ec960`

## Verdict

```text
SOURCE_AUDIT = PASS
L1_BUILD_AND_RUN = PASS
L1_EXPECTED_HELPER_LIVENESS = NOT_OBSERVED
L1_TEST_RESULT = PASS (serializer/accounting)
SOURCE_LIVENESS_RISK_REPRODUCED = YES
HARDWARE_BUILD = NOT_RUN
HARDWARE_PROGRAM = NOT_RUN
STEP5 = NOT_EVALUATED
```

本輪依 Fable §3 F4b 先做離線 production-DCO liveness test，沒有進行
Quartus compile、燒錄或硬體 Step5 observer。測試本身的 page/sequence/
completion accounting 通過，但 Fable 預期的「Main backlog 下 Helper 取得服務」
沒有出現，因此這個版本不能進入硬體驗證。

## 唯一修改

在 `quartus/jtag_runtime_diag/si5340a_controller_dco.v` 的 `rt_state==0`
仲裁順序加入 normal HPLL pending 優先於 DPLL residual，並將原本的 HPLL
分支限定為 forced request：

```text
normal hpll_pending && !hpll_pending_forced
→ DPLL residual
→ forced/bootstrap HPLL
```

bootstrap/forced 的相對順序與 I2C serializer、ACK/completion、PI、startup
控制均未修改。

## Laptop → GitHub → Pain

Laptop 完成 source diff audit 與 whitespace check 後 push；Pain pull 到同一
commit：

```text
REMOTE_HEAD = 6ec740735a976d7aba0e08deafb1b696bd4ec960
BRANCH = exp/step5-softpll-lock
```

## L1 offline result

使用既有 testbench `scripts/experiment/tb_dco_liveness.sv` 與
`scripts/experiment/run_dco_liveness.sh`，在 Pain 的 ModelSim Intel FPGA
Edition 上執行 production DCO controller 的 pin-level I2C test：

```text
L1_CASE=MAIN_JUMP                 MAIN_COMPLETED=4   HELPER_COMPLETED=0
L1_CASE=HELPER_JUMP               MAIN_COMPLETED=0   HELPER_COMPLETED=4
L1_CASE=MAIN_HELPER_CONTENTION    MAIN_COMPLETED=208 HELPER_COMPLETED=0
L1_CONTENTION MAIN_BEFORE_FIRST_HELPER=-1 FIRST_HELPER_TIME_NS=-1
SOURCE_LIVENESS_RISK_REPRODUCED=YES
L1_CASE=NACK_COMPLETION           NACKS=1 HELPER_COMPLETED=1 ACK_ERROR=1 DCO_ERROR=0
TRANSACTION_COMPLETION_DEFECT_REPRODUCED=YES
L1_DCO_LIVENESS_SUMMARY MAIN_COMMANDS=212 HELPER_COMMANDS=5 TRANSACTIONS=217
  WRONG_PAGE=0 SEQUENCE_ERRORS=0 FAIL_COUNT=0
L1_TEST_RESULT=PASS
```

## 判讀

正常單一 owner 的 Main/Helper jump 與 I2C page/write sequence 都通過；但
contention case 仍完全重現 Main 佔用 serializer、Helper 0 completion 的
liveness risk。這不是硬體 Step5 fail，而是本輪 RTL 修改尚未解決 source-level
的實際 starvation。

原因在於目前原始程式的 normal HPLL pending 並不是在 HPLL load 時直接成立；
它是在 `rt_state==0` 的最末端、且只有當前面的 DPLL residual 條件不成立時才
被置位。只把已存在的 `hpll_pending` branch 移到前面，無法讓持續 Main backlog
下的 HPLL residual 進入該 branch。因此 testbench 的 `MAIN_HELPER_CONTENTION`
仍得到 Helper 0。

這個結果也說明不能把「仲裁分支文字已重排」當成「Helper 已被服務」；必須讓
normal HPLL residual 的 admission 本身在 DPLL backlog 存在時仍可被選取，並保留
forced/bootstrap 優先權邏輯。

## 下一步

回到第 1 步，做 Fable F4b 意圖的最小有效修正：在 idle arbiter 先判斷
`normal HPLL residual`（或已成立的 normal `hpll_pending`），直接選取一個
normal HPLL transaction；只有沒有 normal HPLL work 時才判斷 DPLL residual，
forced/bootstrap 分支維持原順序。先重跑相同 L1 contention test，期待
`HELPER_COMPLETED > 0` 且 `MAIN_COMPLETED > 0`、`WRONG_PAGE=0`、
`SEQUENCE_ERRORS=0`。L1 未達預期前仍不進行硬體 build/program。

## Raw evidence

```text
raw/l1-dco-liveness-f4b-arbiter.log
raw/l1-dco-liveness-f4b-arbiter-timeline.log
raw/l1-git-head.txt
raw/l1-git-status.txt
```

Pain 原始檔案保留於 `raw-transfer/`。

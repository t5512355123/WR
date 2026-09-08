# EXP-WRPC-STEP5-SIGNED-HPLL-TARGET-FDEC5632-20260908

## 結論

本輪針對上一輪發現的 `0xFFFB` signed target 疑點，將 HPLL target position
改為 sign-extension 後重新完整建置與燒錄。兩次 preflight 都無法通過 Step1：
Slave SoftPLL 沒有初始化，TAG/TRR/IRQ/helper counters 全為 0，因此本輪沒有
有效 Step5 observer，也不能把它當成 lock 結果。此版本是可重現的 upstream
regression，不能 merge。

```text
STEP1_TO_STEP3 = INVALID_UPSTREAM
STEP4B = BLOCKED_BY_STEP1
OBSERVER_EXECUTED = NO
STEP5 = INVALID_UPSTREAM
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
MERGE_APPROVED = NO
```

## 版本與變因

```text
branch = exp/step5-softpll-lock
source_commit = bc735d8
bootstrap_steps = 5632
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 1
change_under_test = signed sign-extension of hpll_target_position
```

相對上一輪只把 `iHPLL_DATA` 寫入 `hpll_target_position` 的方式改為 signed
sign-extension，並同步改變 raw target 方向比較；沒有修改 PI、lock threshold、
DMTD、PTP、PHY 或 reset policy。

## Build 與 program

```text
SIMULATION_RC = 0
FIRMWARE_MASTER_RC = 0
FIRMWARE_SLAVE_RC = 0
COMPILE_MASTER_RC = 0
COMPILE_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
```

兩個 SOF 都是本輪由同一 source commit 產出；Quartus timing 仍為既有
`TIMING_CLOSED=NO` caveat。

```text
MASTER_SOF_SHA256 = ce535277d5a4f342540aec8c5c19fb617b1166837dd3f9bd47468a472d20cb14
SLAVE_SOF_SHA256 = 9ae86358037b1cab967897e31e92e05cb3c6c2c2e3166d76ed3a70219ce48779
```

## Preflight evidence

第一次與第二次 preflight 均為：

```text
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
```

兩次輸出都顯示：

```text
SPLL_INIT_COUNT = 0
TAG_VALID = 0
TRR_WRITE = 0
IRQ = 0
HELPER_UPDATE = 0
SPLL_HELPER_ERROR = 0
SPLL_HELPER_OUTPUT = 0
```

JTAG/WB transport 本身仍為 trusted，故不是讀取通道失敗；失敗邊界在上游
Step1，不能進入 observer。原始輸出內沒有 `closed-loop-120s.log`，這是刻意的，
因為 settled Step1–4B 門檻未成立。

## 判定與下一步

sign-extension 的想法由上一輪 `0xFFFB`/65531 來回證據支持，但本次實作破壞了
上游啟動，不能直接保留。下一輪應先回到已知可工作的 unsigned target 版本，
再用 read-only probe 或在不改 upstream target contract 的前提下，確認 `0xFFFB`
究竟是 signed code、helper output raw value，還是啟動期間的暫態 sentinel；在
契約未釐清前，不應再次直接把它送入正常 tracker。Step5 維持 `NO`，不應 merge。

## 原始證據

所有建置、燒錄、simulation 與兩次 preflight 輸出及完整 archive 位於本資料夾
的 `raw/` 目錄。

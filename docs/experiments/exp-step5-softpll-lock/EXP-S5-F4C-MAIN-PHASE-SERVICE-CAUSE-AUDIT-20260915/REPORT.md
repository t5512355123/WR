# EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915

日期：2026-09-15（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Laptop/Pain source commit：`5ba40f84cc4275f9a707bd847ac9809b267f7637`

## Verdict

```text
SOURCE_BUILD = PASS (Master + Slave)
PROGRAM = PASS (Master + Slave)
JTAG_WB_PATH = TRUSTED
PREFLIGHT_INITIAL = STEP4B_BLOCKED_BY_STEP2
PREFLIGHT_RETRY_AFTER_60S = STEP4B_BLOCKED_BY_STEP3
F4C_OBSERVER = NOT_STARTED (upstream preflight invalid)
F4C_DATA_QUALITY = NOT_APPLICABLE
STEP5 = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
MERGE_APPROVED = NO
```

本輪沒有取得可用的 F4C sample window，因此不能判定 F4C diagnostic PASS，
更不能判定 Step5 PASS。本輪在 preflight gate 停止，沒有用不完整的 upstream
狀態硬跑 observer。

## Purpose and allowed change

本輪原定執行 Astra 建議的唯一診斷實驗：

```text
EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915
```

目標是把 Main 的 `sample_n/update_count`、phase detector shadow、phase PI、
L2 Main/Helper service 與 Helper residual 放在同一個只讀觀測窗中，區分：

1. Helper 失鎖時 Main update 是否停止；
2. Helper residual 存在時，Main 是否仍完成而 Helper normal service 不前進；
3. phase PI/phase detector 是否有新鮮且一致的輸入。

本次 source commit 只有 observer/離線測試修正：

```text
scripts/jtag/read_step5_main_frequency_prelock_observability.tcl
scripts/tests/test_step5_f4c.py
scripts/tests/test_step5_f4c_observer.py
```

修正內容是將疑似 `sample_n=0` 造成的大於半個 32-bit counter space 的 modulo
delta 標成 ambiguous，不計入 Main progress 或 window delta；沒有修改 production
C、RTL、PLL 控制參數、lock threshold、timeout 或映像控制內容。

Laptop 端完成 17 項 targeted unit tests、Python compile check 與 `git diff --check`
後才 push。這個觀測修正不改變硬體控制功能。

## Laptop → GitHub → Pain

Pain 以乾淨 clone 取得並驗證上述完整 commit，工作樹無變更。Master 與 Slave
均由既定腳本 clean build 成功，Quartus 版本為 17.0.0 Build 595：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_TIMING_CLOSED = NO
SLAVE_TIMING_CLOSED = NO
```

兩張板均完成 programming：

```text
DE5 [1-11.1] Master = Configuration succeeded
DE5 [1-11.2] Slave  = Configuration succeeded
PROGRAMMER = 0 errors, 0 warnings (both)
```

## Upstream preflight

JTAG/WB transport 本身可信：

```text
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

第一次 preflight（燒錄後等待啟動）：

```text
Master STEP1/STEP2/STEP3/STEP4A = PASS
Slave  STEP1 = PASS
Slave  STEP2 = INVALID
Slave  STEP3 = PASS (reported in that snapshot)
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP2
STEP5_RESULT = UPSTREAM_NOT_READY
```

依流程等待 60 秒後只做一次 retry：

```text
Master STEP1/STEP2/STEP3/STEP4A = PASS
Slave  STEP1/STEP2 = PASS
Slave  STEP3 = INVALID
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP3
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

因此未執行：

```text
120 s smoke observer = NOT STARTED
600 s long observer = NOT STARTED
```

## Interpretation

這一輪沒有證明 Main phase service 的根因，也沒有推翻先前 F4b 的結果；它只
證明在本次重新燒錄後，Slave 的 Step4B upstream gate 在兩次取樣中都沒有形成
可合法進入 F4C 的穩定前提。第一次是 Step2 invalid，第二次則是 Step3 invalid。

這個現象本身不能被解讀成「PLL phase 一定失鎖」或「仲裁一定是根因」，因為
F4C 的關聯資料尚未取得。JTAG/WB path 通過，故目前較精確的 boundary 是：

```text
JTAG/WB transport = healthy
source build/program = healthy
Slave upstream Step4B precondition = not stable/valid in this session
F4C Main phase-service diagnosis = not observed
Step5 = not complete
```

Timing `closed=NO` 也仍是獨立 implementation caveat；本輪沒有把它誤判為
Step5 functional 結果。

## Next action

下一輪仍應遵守 Astra 的 F4C 限制，但先處理本輪暴露的 upstream gate 問題：

1. 保持 `5ba40f84` 的 observer ambiguity 修正與所有 F4b/Step5 控制參數不變；
2. 重新依 Laptop→Pain 流程取得 fresh-program session；
3. preflight 必須在同一 session 形成合法、穩定的 Slave Step2/Step3/Step4B
   前提後，才允許開始短 smoke；
4. 若 gate 再次 invalid，保存 preflight raw 並停止，不啟動 F4C observer；
5. 只有 smoke 通過 transport/data-quality gate，才做最多 600 秒 long capture；
6. F4C diagnostic PASS 仍不等於 Step5 PASS。Step5 仍需完整 chain、至少 300
   秒 fresh continuous lock、strict replay 與 3 次 fresh-program reproduction。

本輪沒有 merge，因為 Step5 未完成且沒有 merge approval。

## Raw evidence

```text
raw/wr-step5-f4c-master-build-5ba40f84.log
raw/wr-step5-f4c-slave-build-5ba40f84.log
raw/wr-step5-f4c-master-program-5ba40f84.log
raw/wr-step5-f4c-slave-program-5ba40f84.log
raw/wr-step5-f4c-preflight-5ba40f84.log
raw/wr-step5-f4c-preflight-retry-5ba40f84.log
```

Pain transfer archive：

```text
EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915-5ba40f84-preflight-blocked.tgz
SHA256 = ca01cfe07081df8cc844fde389f46b15289004059d6a00a0158781b5edb798aa
```

Local raw file SHA256 values are recorded in `manifest.json`.

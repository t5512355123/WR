# EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915

日期：2026-09-15（Asia/Taipei）  
branch：`exp/step5-softpll-lock`  
observer/source commit：`e5e9cfb2a42c385d0508668985c07d44b65bd87b`  
functional image build commit：`e5e9cfb2a42c385d0508668985c07d44b65bd87b`  
functional source baseline：`5ba40f84cc4275f9a707bd847ac9809b267f7637`

## 結論

本輪 F4D gate/session audit：**PASS（`ACQUISITION_WINDOW_OBSERVED`）**。  
Step 5：**尚未完成，不能宣稱 PASS**。

有效 capture 的結果是：

```text
F4D_RESULT                    = ACQUISITION_WINDOW_OBSERVED
F4D_PASS                      = true
STEP5_COMPLETE                = false
STEP5_PASS                    = false
MERGE_APPROVED                = false
END_REASON                    = DURATION_REACHED
ELAPSED_MS                    = 120199
GENERATION_CHANGES            = 0
RESET_CHANGES                 = 0
```

F4D PASS 在本實驗只代表：在正確的 JTAG-runtime 映像下，取得了可信的
上游 acquisition window，且沒有觀測到 session 已終止或 reset/restart。
它不代表 WR upstream gate 已恢復，也不代表 SoftPLL 已進入 closed-loop lock。

## 為什麼前兩次觀測全部 timeout

前一版流程使用 `scripts/pain/pain_build_master.sh` 與
`pain_build_slave.sh`，實際編譯的是 `quartus/rs422_uart_diag` top-level：

```text
DE5a_wr_master_rs422
DE5a_wr_slave_rs422
```

這兩個 top-level 沒有 `wr_jtag_wb_mailbox.vhd`，也沒有 F4D 所需的
Wishbone mailbox / probes 52..61。它們可以讀到 direct status probe，卻
無法完成 F4D 使用的 mailbox read，因此不是硬體 gate 的結果。

同一映像上的短 transport sanity audit 也得到：

```text
PRELOAD_COUNT = 60
COMMIT_COUNT  = 0
TIMEOUT_COUNT = 60
```

這確認問題在 target 映像缺少 mailbox，而非可以拿來判定 Step 5 的 WR
session failure。之後改用 repo 既有的 JTAG-runtime workflow：

```text
pain_build_jtag_master.sh
pain_build_jtag_slave.sh
pain_program_jtag_master.sh
pain_program_jtag_slave.sh
```

其 QSF 明確包含 `wr_jtag_wb_mailbox.vhd`，並保留 probes 52..61。

## 有效硬體流程

Laptop push 後，Pain 確認 exact HEAD 為 `e5e9cfb2`，再完成：

```text
JTAG-runtime Master build  = PASS, timing_closed=NO
JTAG-runtime Slave build   = PASS, timing_closed=NO
Master program             = PASS, Configuration succeeded
Slave program              = PASS, Configuration succeeded
Master SOF checksum        = 0x30B89B19
Slave SOF checksum         = 0x30B84088
```

這輪沒有修改 production C/RTL、PLL/PI、timeout、threshold、arbiter 或
firmware control path；`5ba40f84` 到本輪 commit 的 functional source
diff 為空。新增內容只在 observer Tcl 的 mailbox transport / F4D audit
與測試紀錄。

## 有效 F4D capture

raw：`raw/attempt-e5e9cfb2-jtag-runtime/tmp/wr-step5-f4d-timeline-jtag-e5e9cfb2.log`  
analysis：`analysis/replay-e5e9cfb2-jtag-runtime/`

```text
觀測窗                    120000 ms（hard limit 130000 ms）
實際 elapsed              120199 ms
Master samples            38
Slave samples             38
Master CORE_FRAME_VALID   37/38 = 0.9736842105
Slave CORE_FRAME_VALID    38/38 = 1.0
generation changes        0
reset changes             0
terminal streak max       0（兩板）
upstream pass streak max  0（兩板）
observer stop             none
```

主要狀態：

```text
Master:
  PTP_STATE                 = MASTER
  WR_STATE                  = WRS_M_LOCK
  SPLL_MODE                 = FREE_RUNNING_MASTER
  SPLL_SEQ_STATE            = SEQ_WAIT_HELPER
  helper locked             = 0
  main enabled/locked       = 0/0
  PSTAT_LOCKED              = 0

Slave:
  PTP_STATE                 = UNCALIBRATED
  WR_STATE                  = WRS_S_LOCK
  SPLL_MODE                 = SLAVE
  SPLL_SEQ_STATE            = SEQ_WAIT_MAIN（capture 結尾）
  helper locked             = 1（capture 結尾）
  main enabled/freq/phase   = 1/1/0（capture 結尾）
  main locked               = 0
  PSTAT_LOCKED              = 0
```

Slave 已有 DMTD、TAG、TRR、IRQ、helper update 與 Main frequency lock 的
證據，但 phase lock 與 PSTAT lock 從未成立；因此這輪明確把問題邊界
縮到「Slave Main phase acquisition/phase convergence 尚未完成」，而不是
把 F4D gate audit 當成 Step 5 pass。

## Observer 修正歷史

```text
7cc73976  首版 F4D；indirect reset-array Tcl expression 在第一筆 sample abort
79380a35  修正 indirect array 讀取；仍發現 terminal streak 未初始化
9e010847  初始化 terminal streak；rs422 target 可跑但 mailbox 全 timeout
e5e9cfb2  使用既有 preload→toggle commit→三次一致 mailbox protocol；
          source audit 後改以 JTAG-runtime target 取得有效 capture
```

以上 observer runtime error 與錯誤 target 的 raw 都保留，不能混入有效
capture 的 gate 統計。

## 原始證據與 checksum

```text
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-7cc73976-observer-error.tgz
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-79380a35-observer-error.tgz
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-9e010847-runtime.tgz
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-e5e9cfb2-rs422-runtime.tgz
raw-transfer/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915-e5e9cfb2-jtag-runtime.tgz
```

重要 archive SHA256：

```text
9e010847 rs422/observer runtime archive:
44d5c57f0e728974bf8a1f080cd31bf8deb5a0d1a2838585ba1e599b1bf25574

e5e9cfb2 rs422/observer runtime archive:
0eba8b0a2ddb0a7bb630b5713804ca2a758ce7e3d9cef9601ac155939a10b037

e5e9cfb2 JTAG-runtime valid capture archive:
bdbfc7cd4561397c9a3e9ac1fb0c5af39c7fa554fd8c4d1120a3a358ee5210f7

79380a35 observer-error archive:
6e961413fefa1a0c5fc33619f0041ce44533c05a0373c096ba5705393a761714
```

離線判定檔案：

```text
analysis/replay-e5e9cfb2-jtag-runtime/verdict.json
analysis/replay-e5e9cfb2-jtag-runtime/gate_conditions.csv
analysis/replay-e5e9cfb2-jtag-runtime/timeline.csv
analysis/replay-e5e9cfb2-jtag-runtime/role_summary.csv
```

下一步必須先把本輪有效 capture 與「rs422 target 缺 mailbox」的 source
audit 結果交給 Astra，再依其更新建議設計下一輪實驗；本輪不自動調參、
不 merge 到 main。

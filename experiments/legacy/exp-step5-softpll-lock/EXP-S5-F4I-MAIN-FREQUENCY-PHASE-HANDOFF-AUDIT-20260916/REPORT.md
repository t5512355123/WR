# EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916

日期：2026-09-16（Asia/Taipei）
Branch：`exp/step5-softpll-lock`
實驗目的：在 F4H 已證明 PHY/WR gate 有效、但 Main phase lock 仍為 0 的前提下，觀察 Main frequency domain 與 phase domain 的交接是否穩定，並確認 residual frequency error 是否伴隨反覆回到 frequency domain。

## Verdict

```text
CLASSIFICATION = RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS
DIAGNOSTIC_PASS = YES
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

本輪成功取得足夠且結構一致的診斷資料，但沒有達成 Step5。正式資料顯示 Main
確實多次進入 phase domain，之後又回到 frequency domain；在所有唯一 Main
publication 中，`MAIN_PHASE_LOCKED` 仍為 0。這支持「frequency residual / handoff
仍是目前主要觀察邊界」的診斷，不等於已證明某一個 production 根因，也不授權
本輪直接調整 PI、threshold 或 timeout。

## Scope and source contract

本輪依 Astra 的 F4I 建議執行，唯一目的為：

```text
Main frequency/phase handoff audit
→ 保留 residual frequency evidence
→ 區分 publication coherence 與 producer-domain coherence
→ 不修改 production control
```

只修改了 host-side observer、offline replay/analyzer、測試與文件：

- Main trace 改用既有 coherent compact reader，並以
  `(publication_epoch, sample_n)` 去重。
- 保留 direct `JTAG_PROBE0` PHY source、Helper CORE/state、Helper position、
  L2 52–61、Main detector 與 Master background WR evidence。
- detector stream 與 Main trace stream 分開分析。
- 只宣告 publication coherence；`PRODUCER_DOMAIN_COHERENCE=UNPROVEN`。
- 不開 Helper PI snapshot、不開第二個 reader、不做 control write。

Production C/RTL、PI/gain/boost、lock threshold、timeout/retry、bootstrap、
arbitration、mailbox、reset 與 image-control source 均未修改。

Source audit 見 [source_coherence_audit.md](source_coherence_audit.md)。F4H baseline
replay 仍保守判定為 `SOURCE_COHERENCE_LIMITED`，因為舊 F4H capture 沒有可信的
同一 Main frame `dref/dout` pair；因此本輪沒有把舊資料升級成 F4I 證據。

## Laptop → GitHub → Pain

```text
SOURCE_COMMIT = a67fee352e57213bc05dc06d5518462d97a54d55
PAIN_CHECKOUT = a67fee352e57213bc05dc06d5518462d97a54d55
RUN_ROLE = f4i
MASTER_TARGET = DE5 [1-11.1]
SLAVE_TARGET = DE5 [1-11.2]
```

Master 與 Slave clean build 均成功；Pain build log 報告 `timing_closed=NO`，這是
implementation caveat，不作為本輪 Step5 verdict。兩張既有 runtime image 均完成
program，Master/Slave return code 均為 0。

```text
MASTER_SOF_SHA256 = add03fb14c93c8dec231bf217c9ba5d49c6faa58969f765b417d17b684cfe549
SLAVE_SOF_SHA256  = 012dec89a28b40f02bb095a80a7c91457be757267c8cf96b41432b61bb9c0a76
TIMING_CLOSED = NO
```

## Smoke

同一個 F4I observer 先做短 smoke：

```text
SMOKE_RC = 0
MAIN_TRACE = 4
MAIN_VALID = 4
HELPER_ATTEMPTS = 6
HELPER_ACCEPT = 4
CONTEXT_ERRORS = 0
STOP_REASON = NONE
RUN_END_REASON = SAMPLE_LIMIT
```

Smoke 的早期 Main 值仍在 startup/zero state，僅用來驗證 reader、格式與 transport，
不作 Step5 判定。

## Formal capture

觀測命令為：

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 240 500 "" 120000 130000 f4i
```

正式觀測正常到達目標時間，沒有 timeout、transport failure、PHY regression 或 reset
stop：

```text
session_elapsed_ms = 120041
target_duration_ms = 120000
hard_duration_ms = 130000
slave_cycles = 100
master_samples = 34
slave_trace_unique = 64
slave_trace_duplicates = 36
slave_domain_changes = 8
main_trace_valid = 100/100
main_stale_publication = 0
main_sample_ambiguous = 0
main_progress_count = 63
run_end_reason = TARGET_REACHED
stop_reason = NONE
single_reader = PASS
```

正式資料具備 analyzer 要求的最低 coverage：

```text
unique Main publications = 64 (required >= 20)
unique Main span = 118927 ms (required >= 30000 ms)
valid 10-second background bins = 12 (required >= 3)
```

## Observed evidence

獨立 replay 輸出位於：

- [verdict.json](analysis/formal-a67fee3/verdict.json)
- [main_trace.csv](analysis/formal-a67fee3/main_trace.csv)
- [main_dedup.csv](analysis/formal-a67fee3/main_dedup.csv)
- [main_domain_transitions.csv](analysis/formal-a67fee3/main_domain_transitions.csv)
- [bins.csv](analysis/formal-a67fee3/bins.csv)
- [detector_state.csv](analysis/formal-a67fee3/detector_state.csv)
- [service.csv](analysis/formal-a67fee3/service.csv)

| 證據 | 結果 |
|---|---:|
| Main trace valid records | 100/100 |
| Main unique publications | 64 |
| Main duplicate publications | 36 |
| Main stale publication | 0 |
| Main sample progress | 63 |
| Main domain：PHASE | 60/64 |
| Main domain：FREQUENCY | 4/64 |
| Visible frequency↔phase handoffs | 8 |
| Main phase-locked records | 0/64 |
| Detector phase-locked records | 0/100 |
| Detector frequency-locked records | 96/100 |
| Helper state valid/locked | 100/100 |
| Helper position records | 100 |
| Service-demand records | 100 |
| Direct WR/PHY records | 134 |
| WR/PHY gate valid and pass | 134/134 |
| Context/shape errors | 0 |

Main trace 的數值範圍如下：

```text
MAIN_FREQ_ERROR: 27..66, mean=48.375, positive=64/64
abs(MAIN_FREQ_ERROR) > 50: 28/64
MAIN_PRELOCK_ERROR: -1320..-540
MAIN_PI_X: -7992..7913
MAIN_PI_OUTPUT: 10204..12222
MAIN_PI_CLAMP_SIDE: 0/64
dref/dout/freq_error pair check: 64 PASS, 0 FAIL, 0 UNKNOWN
```

12 個十秒區間全部有可信的 Main/Helper service completion 與 start 增量；各區間的
completion window 都是 `TRUSTED`。區間資料合計為：

```text
Main completed delta sum   = 56205
Helper completed delta sum = 6327
Main start delta sum       = 56204
Helper start delta sum     = 6327
```

這證明 service liveness 與資料窗有效，不宣稱跨 reader、跨 probe 的同一 cycle
因果關係。

## Interpretation

8 次 handoff 的實際轉移包含：

```text
PHASE → FREQUENCY：4 次
FREQUENCY → PHASE：4 次
```

每次回到 frequency domain 時，`MAIN_FREQ_ERROR` 仍為正且非零；回到 phase domain
後 `PI_X` 有 phase-context-like 變化，但 phase lock 從未成立。這與 analyzer 的
`RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS` 一致，並且診斷 coverage 通過。

這一輪能回答的是：

1. Main publication stream 確實持續前進，而不是只重複同一筆資料。
2. frequency/phase domain 不是一次性切換；正式窗內有反覆 re-entry。
3. PHY/WR/Helper service 在同一 capture 中沒有出現本輪可見的 transport 或 gate
   regression。

這一輪不能回答的是：

1. `PRODUCER_DOMAIN_COHERENCE` 仍未證明；publication epoch coherence 不等於同一
   control iteration 的 branch identity。
2. 尚未做 phase unwrap、cycle-slip fit 或 phase slope，因此不能把目前的 phase
   failure 歸因到某個具體 PI 數值。
3. `MAIN_PHASE_LOCKED=0` 與 `PSTAT_LOCKED=0` 仍然表示 Step5 未完成。

## Reproducibility artifacts

Pain 原始資料與執行紀錄保留於
[raw/attempt-a67fee3-f4i-jtag-runtime](raw/attempt-a67fee3-f4i-jtag-runtime)。
封存檔解出的 raw files 位於
[raw/attempt-a67fee3-f4i-jtag-runtime/](raw/attempt-a67fee3-f4i-jtag-runtime/)。

```text
FORMAL_LOG_SHA256  = c2da4c61c931c0e021ee4b872471c26c0256905b637e9bd7f78ae800fec3d5f
SMOKE_LOG_SHA256   = 55307aaeed31696f8ade4c504e4161df5ba728f9d1af3c0a8e88b8ac544af491
ARCHIVE_SHA256     = dcde493da372932cf55916d498bef893c8ebd5f0f6f0f6f624a78f7767492bc436
```

## Offline verification

```text
F4G/F4I TEST HARNESS = 17 PASS
F4H SOURCE UNITTEST = 11 PASS
TOTAL TESTS = 28 PASS
PY_COMPILE = PASS
ANALYZER_RC = 0
SOURCE/PRODUCTION CONTROL CHANGE = NONE
```

本輪結論是診斷成功、Step5 未通過。依實驗規則，本輪不自動調參、不 merge 到
`main`，先將完整報告推送回 GitHub，再取得下一個受控實驗建議。

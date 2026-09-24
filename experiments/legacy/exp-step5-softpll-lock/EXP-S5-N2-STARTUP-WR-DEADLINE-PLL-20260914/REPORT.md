# EXP-S5-N2-STARTUP-WR-DEADLINE-PLL-20260914

## 結論

本輪 N2 的 read-only observer 與同一窗口的 startup→WR deadline→PLL 時間軸：**PASS_BOUNDARY_LOCALIZED**。

本輪硬體窗口：**INVALID_OR_UPSTREAM_BLOCKED**。Slave 的 Step2 沒有形成 uniform valid gate，因此本輪不能作為 Step4B closure 或 Step5 closed-loop lock 的有效通過窗口。

Step5 closed-loop lock：**NOT COMPLETE**。

本輪唯一 source 變更是 observer：加入 CTRL frame bracket、boot-generation continuity、ACQUISITION/TRACKING 分類，以及 producer-side probes 52–61 的 first-loss/DCO telemetry。沒有修改 production SoftPLL、PI、I2C arbiter、WR timeout 或控制參數。

## 實驗身分與可追溯性

- source commit: `68793ea9caa142bbbbc0fb943d00c3ece68a702f`
- branch: `exp/step5-softpll-lock`
- changed file: `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl`
- observer SHA-256: `5edbfcd20a3621c2b87e33b68d98e81db39acc21c772dc035dcee4800f9602e3`
- experiment ID: `EXP-S5-N2-STARTUP-WR-DEADLINE-PLL-20260914`
- Pain host: `pain`
- Quartus: 17.0.0 Build 595
- capture mode: read-only, two designated DE5 cables, one observer session
- session deadline: 240000 ms
- actual observer elapsed: 240997 ms
- observer sample errors: 0
- physical power-cycle: completed by user before this round

既有 dirty report 與未追蹤 raw/artifact 檔案均保留，沒有清理或覆蓋。

## 本輪修改的診斷界線

每筆 sample 以 `0x00100A04` 的 CTRL frame begin/end 包住 Wishbone snapshot，並輸出：

- `FRAME_VALID`
- boot generation 首筆／末筆／變化次數
- WR state、S_LOCK trace、`spll_check_lock`、Helper/Main lock state、PSTAT
- `ACQUISITION`：尚未同時滿足完整 lock chain
- `TRACKING`：同時具備 `SPLL_SEQ_READY`、Helper locked、Main enabled/frequency/phase/Main locked、PSTAT locked，且 frame valid
- probes 52–61：pending、service start、completed、failed、wait、latency、ACK/timeout、sticky first-loss

此分類僅用於定位時序，不把短暫 tracking 當成 Step5 PASS。

## Build 與 programming

兩次（observer summary 修正前／修正後）都完成 firmware build 與完整 Quartus compile；正式分析採用修正後第二次 image：

| role | firmware MIF SHA-256 | SOF SHA-256 | WNS | timing closed | programming |
| --- | --- | --- | ---: | --- | --- |
| Master | `3f1387070ebb70386c5c2369a59e863f7c14c304f0e8f7dbcbc906195fae9f9a` | `f61b5f51d1a55ed66989bda9147025a685b63619b76ec981bad4c222454d2292` | -0.058 ns | NO | `DE5 [1-11.1]` PASS |
| Slave | `f73c3c199f4f9731ee9eda6cab7b14e6b61647ebe530d0601c12a035a2dbbec2` | `e722f48292f69bdda240c07f00517f2d3817b970f6a9db9bfc11c413ada941b0` | +0.015 ns | NO | `DE5 [1-11.2]` PASS |

兩次完整 build 均為 `Full Compilation was successful`。重建的 MIF/SOF hash 與前一個 observer compile 不同，已將兩次 build logs 與 hash 分開保存；不把它們視為同一 binary。

## Preflight

正式 rerun 的 WB transport diagnostic path：

```text
PROBE_3WAY_MATCH_COUNT = 355
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

上游 milestone：

```text
Master: STEP1=PASS, STEP2=PASS, STEP3=PASS, STEP4A=PASS
Slave:  STEP2=INVALID, STEP4B=BLOCKED_BY_STEP2
```

因此沒有把 Master 的成功與 Slave 的 invalid 混成一個雙板 Step4B PASS。

## N2 時間軸結果

### Master

```text
samples = 86
sample_errors = 0
BOOT_GENERATION = 1 -> 1
BOOT_GENERATION_CHANGES = 0
N2_PHASE = ACQUISITION throughout
N2_TRACKING_SAMPLES = 0
FIRST_CORE_TM_LINK_UP = 627 ms
FIRST_DMTD_ACCEPT = 627 ms
FIRST_TAG_VALID/TRR_WRITE/TRR_POP/IRQ/HELPER_UPDATE = 627 ms
FIRST_WR_FAILURE = 22350 ms, reason=2 WR_M_LOCK_TIMEOUT
FIRST_WR_DISABLE = 22350 ms, cause=2 HANDSHAKE_FAILURE
FIRST_INACTIVE_BOUNDARY = WR_EXTENSION_FAILURE
```

Master 的 probes 52–61 在這個 image 上是 `TIMEOUT`，所以本輪沒有 Master 端 producer-side first-loss/DCO transaction 證據；這是 telemetry unavailable，不是「DCO 沒有發生」的證明。

### Slave

```text
samples = 86
sample_errors = 0
BOOT_GENERATION = 1 -> 1
BOOT_GENERATION_CHANGES = 0
FIRST_CORE_TM_LINK_UP = 1137 ms
FIRST_DMTD_ACCEPT = 1137 ms
FIRST_TAG_VALID/TRR_WRITE/TRR_POP/IRQ/HELPER_UPDATE = 1137 ms
FIRST_HELPER_LOCKED = 36710 ms
FIRST_MAIN_ENABLED = 36710 ms
FIRST_MAIN_FREQ_LOCKED = 42608 ms
FIRST_SPLL_READY = 93066 ms
FIRST_MAIN_PHASE_LOCKED = 93066 ms
FIRST_MAIN_LOCKED = 93066 ms
FIRST_PSTAT_LOCKED = 93066 ms
N2_FIRST_TRACKING = 93066 ms
N2_TRACKING_SAMPLES = 5
FIRST_WR_FAILURE = 96000 ms, reason=4 WR_LOCKED_TIMEOUT
FIRST_WR_DISABLE = 96000 ms, cause=2 HANDSHAKE_FAILURE
N2_PHASE returned to ACQUISITION at observed sample 107823 ms
FIRST_INACTIVE_BOUNDARY = WR_EXTENSION_FAILURE
```

Slave probes 52–61 都能讀到，而且不是全程為零。完整 raw 顯示：

```text
FIRST_SAMPLE t=1137 ms: HELPER_COMPLETED=3388, MAIN_COMPLETED=0
FIRST_MAIN_COMPLETED > 0: t=33724 ms, MAIN_COMPLETED=34
FINAL_SAMPLE t=238995 ms: MAIN_COMPLETED=42328, HELPER_COMPLETED=12669
MAX_MAIN_WAIT = 86692037       (raw liveness units; unit 尚未映射)
MAX_HELPER_WAIT = 512          (raw liveness units; unit 尚未映射)
MAX_MAIN_LATENCY = 60930       (raw liveness units; unit 尚未映射)
MAX_HELPER_LATENCY = 60930     (raw liveness units; unit 尚未映射)
MAIN/HELPER_FAILED = 0
ACK_EVENTS = 0
TIMEOUT_EVENTS = 0
DCO_ERROR = 0
FIRST_LOSS_VALID = 0
```

這證明 Slave 端確實有 DCO service activity，且觀測期間沒有 sticky first-loss、failed、ACK、timeout 或 DCO error。但 service-start 與 completion 的數量關係，以及極大的 `MAIN_MAX_WAIT`，仍需要 transaction-local telemetry 與單位定義的 audit；不能只靠這些欄位推論 starvation 或 completion failure。因此目前不能把「Slave 約 93.066 秒出現內部完整 lock bits」歸因為 DCO arbiter starvation，也不能由此選擇 L3A/L3C。這只證明在稀疏取樣中曾出現短暫 tracking，且在 WR failure/disable 之後沒有保持到 deadline。

### Frame 與同代性

兩板 boot generation 在窗口內都維持 `1 -> 1`、沒有變化。CTRL frame 大部分有效，但 Master 有 7 筆、Slave 有 5 筆 `FRAME_VALID=0`；因此需保留少量 snapshot consistency caveat。這不改變首個 WR failure 與 lock milestone 的主要順序，但不支持宣稱「全窗口連續鎖定」。

## N2 判定與因果邊界

已定位的第一失效邊界：

1. Master：先在約 22.35 秒進入 `WR_M_LOCK_TIMEOUT`／`HANDSHAKE_FAILURE`，全程沒有 Main/PLL tracking。
2. Slave：先有 DMTD/Step4B event chain，之後在約 93.066 秒觀測到一次完整 lock chain；約 96 秒 WR 記錄 `WR_LOCKED_TIMEOUT` 並 disable；約 107.823 秒觀測到 tracking chain 離開。
3. 同一窗口沒有 boot generation change、CPU/WR reset；Slave 有 DCO service activity，但沒有 producer-side first-loss、failed、ACK 或 timeout event。Master 的同類 payload 在 image 中不可用（probes 52–61 讀到 `TIMEOUT`），且 Slave 的 service-start/completion counter 關係尚未釐清，因此不能證明是 I2C starvation、NACK/timeout completion bug 或 PI polarity 導致這次失效。

這輪的診斷價值是把兩條時間軸拆開：

```text
WR protocol deadline/fallback  !=  PLL state bits briefly becoming locked
```

此外，Slave Step2 INVALID 使此窗口不具備有效 WR upstream closure；Slave L2 雖然有活動計數，但 telemetry contract 尚未閉合；Master L2 telemetry timeout 則使 DCO 因果仍缺一側證據。

## Step5 判定

```text
STEP5_HELPER_LOCK = NOT_CONCURRENTLY_STABLE
STEP5_MAIN_FREQ_LOCK = NOT_CONCURRENTLY_STABLE
STEP5_MAIN_PHASE_LOCK = NOT_CONCURRENTLY_STABLE
STEP5_PSTAT_LOCK = NOT_CONCURRENTLY_STABLE
STEP5_SEQ_READY = BRIEFLY_OBSERVED_ON_SLAVE
STEP5_WR_ACTIVE = NOT_PROVEN_CONTINUOUSLY
STEP5_DCO_TRANSACTION_CAUSALITY = UNKNOWN
STEP5_RESULT = NOT_COMPLETE
STEP5_PASS = false
```

完整 Step5 仍要求在有效 WR session 中，Helper、Main frequency、Main phase、Main locked、SEQ_READY、PSTAT 同時 fresh 且連續，並通過 fresh-program repeats；本輪不滿足。

## 下一步

下一輪不直接改 PI、timeout 或 arbiter。先做一個 N2 measurement closure round：

1. 保持 production source 與控制參數不變。
2. 先解決 Slave Step2 的 intermittent INVALID，並保留 Master/Slave 各自的 preflight verdict。
3. 核對 probes 52–61 在 Master image 的實際 owner/map；若 Master 真的沒有這組 producer telemetry，報告中明確標 `UNAVAILABLE_BY_IMAGE_SCHEMA`，不要把 TIMEOUT 轉成零。對 Slave 則先補齊 transaction-local owner/epoch、start/completion 對應與 raw-unit 定義，避免把有效活動誤判為失敗或 starvation。
4. 在同一個 fresh-program boot/session 重新取得一條 valid WR window；60 秒 smoke 必須是同一 capture 內檢查點，不另起未知時間軸。
5. 只有在 first-loss/DCO telemetry 真正提供因果證據後，才依 Astra 分流選一個 L3 功能修正：公平仲裁、transaction completion、bootstrap handshake 或 bumpless transfer。

本輪不是 Step5 PASS，也沒有 merge 或修改 main。

## Raw 與 checksum

- local raw folder: `raw/`
- remote bundle SHA-256: `cf0635cbe6d0f9ae9e88cd076d433d111b05caede23df3d43e2c8a828e2252e5`
- raw checksums: `raw/checksums.sha256`
- first observer run（取樣成功但 summary format error）保留於 `raw/startup-timeline-v1-summary-format-error.log`
- final valid observer output: `raw/startup-timeline-final.log`

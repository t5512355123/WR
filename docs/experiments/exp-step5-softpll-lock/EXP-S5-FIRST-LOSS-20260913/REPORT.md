# EXP-S5-FIRST-LOSS-20260913

## 結論

本輪完成了 Step5 L2 觀測版本的 full compile、雙板燒錄與只讀 preflight，但沒有進入有效的 first-loss telemetry window。原因是 Slave 的上游 Step2 calibration gate 尚未成立，因此依實驗規範本輪判定為：

```text
EXPERIMENT_CLASSIFICATION = INVALID_OR_UPSTREAM_BLOCKED
STEP4A_RESULT             = PASS
SLAVE_STEP1_RESULT        = PASS
SLAVE_STEP2_RESULT        = INVALID / NA
SLAVE_STEP3_RESULT        = PASS
STEP4B_RESULT             = BLOCKED_BY_STEP2
STEP5_RESULT              = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE      = UPSTREAM_STEP4B
```

這不是 Step5 lock failure，也不能宣稱 Step4B 或 Step5 PASS。實際最早失效邊界是：

```text
Slave Step2 Endpoint / PTP calibration gate
```

## Provenance

- 日期：2026-09-13（Asia/Taipei）
- branch：`exp/step5-softpll-lock`
- source commit：`0b7fa9c1dbf4bda6b63ad072028b493935552558`
- Pain checkout：同一個 `0b7fa9c1dbf4bda6b63ad072028b493935552558`
- 實驗目標：`EXP-S5-FIRST-LOSS-20260913`
- 硬體：Master `DE5 [1-11.1]`、Slave `DE5 [1-11.2]`
- Quartus：17.0.0 Build 595
- cold-power-cycle：本輪使用者已先完成實體斷電重開；本輪沒有再重複斷電

## 唯一程式變因

本輪 commit 只加入 Step5 first-loss 的低擾動 persistent observability：

- DCO Main/Helper pending、service start、completed、failed、wait、queue age、latency
- ACK error、timeout、DCO error 與 first-loss owner/reason/epoch
- Slave JTAG source-probe indices 52–61

Diagnostic registers/probes 沒有回饋到 arbiter、I2C transaction、PI、SoftPLL、reset 或 startup functional control。既有 functional MIF 未改；Master 與 Slave 都因 top-level component/probe interface 變更而重新 full compile。

## Build 與 programming

兩個 image 都由同一個 source commit 產生，且 full compilation 成功：

| image | compile | timing | SOF SHA-256 |
| --- | --- | --- | --- |
| Master | `Full Compilation was successful` | `TIMING_CLOSED=NO`, WNS `-0.058 ns` | `8b30f40bf54fbf7936d5d4d86642db5b4a16208983eb00944a9132a1124d1497` |
| Slave | `Full Compilation was successful` | `TIMING_CLOSED=NO`, WNS `+0.015 ns` | `8574db90d3200ab5fe4f0869075c1f8772bb977a79846c01c37be1f5d5ed2038` |

兩張板均由 Quartus Programmer 回報 configuration succeeded、0 errors、0 warnings。programming raw log 與 build manifest 已保存於 `raw/`。

## Preflight evidence

### Master

- Step4A event chain：`PASS`
- Step5：`NOT_APPLICABLE_MASTER`

### Slave

```text
Step 1 PHY / Link       pass
Step 2 Endpoint / PTP   NA
Step 3 WR Handshake     pass
Step 4B                 blocked
Step 5                  NA
```

具體 gate 輸出：

```text
WDIAGS_PTP = 8 UNCALIBRATED (raw=00004108)
STEP1_REGRESSION = PASS
STEP2_REGRESSION = INVALID
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP2
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
FAILURE_CLASSIFICATION = JTAG/DASHBOARD_MEASUREMENT_FAILURE
```

這次並非 JTAG/WB 讀取不穩定：

```text
WB_REQUEST_COUNT = 353
WB_PROBE_READ_COUNT = 1765
PRELOAD_UNEXPECTED_TRIGGER_COUNT = 0
PROBE_3WAY_MATCH_COUNT = 353
STABLE_RESPONSE_WRONG_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
STALE_A5A5_COUNT = 0
UNSTABLE_TRANSACTION_COUNT = 0
DMTD_REF_DECREASE_COUNT = 0
DMTD_FB_DECREASE_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Slave 的 PTP RX/TX 與一般 RX/TX counter 都有增加，RX error 為 0；因此現在能確定的是 link/traffic/WR handshake 有活動，但不能把 activity 等同於 PTP calibration 已完成。raw snapshot 也記錄了 `boot_generation=1`、`cpu_reset_count=1`、`wr_core_reset_count=1`、`si_config_drop_count=1`、`spll_init_count=1` 與 `spll_state=00030004`，這些是狀態證據，不是 lock 證據。

## L2 observer 狀態

`read_step5_first_loss_telemetry.tcl` 本輪沒有啟動正式 smoke/600-second observer。依規範，Step1–4B 必須先 settled PASS；目前 Step2 invalid、Step4B blocked，若繼續讀取只能得到不具資格的資料，不能用來判定 first loss 或 Step5。

## 判讀與下一步分流

本輪不修改 PI、arbiter、ACK semantics 或 SoftPLL。下一個合法實驗應先單獨釐清 `WDIAGS_PTP=UNCalibrated` 是實際 calibration 尚未完成，還是 runtime reader 的 publication/gate 語意問題：固定同一份 image/source，對 calibration publication、raw PTP state、`parentCalibrated`、`pstat/sstat`、WR state 與 counter delta 做只讀、連續時間觀測。只有 Step2 在同一 settled window 變成 PASS，才重新執行 Step4B，再進入本 L2 first-loss observer。

若 Step2 仍然 invalid，應保存為 upstream-blocked evidence，不再掃 PI；若 Step2 PASS 且 Step4B PASS，才可將 L2 observer 的第一個 loss reason、owner、queue age、ACK/timeout/applied correlation 用作下一個唯一 functional change 的依據。

## 原始資料

- [Master build log](raw/step5-l2-build-master-0b7fa9c.log)
- [Slave build log](raw/build-slave.log)
- [Master build info](raw/build-info-master.txt)
- [Slave build info](raw/build-info-slave.txt)
- [Master programming log](raw/program-master.log)
- [Slave programming log](raw/program-slave.log)
- [完整 preflight log](raw/preflight.log)
- [manifest](manifest.json)
- [verdict](verdict.json)
- [raw checksums](raw/checksums.sha256)


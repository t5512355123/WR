# EXP-S5-WR-LOCK-DETECTOR-TIMELINE-D35A344-20260913

## 結論

本輪完成 `d35a344` 的 Pain pull、Master/Slave full compile、雙板燒錄，以及 Slave 120 秒 lock-detector timeline。這輪沒有達成 Step5；但它將失效邊界進一步分解為「SoftPLL 的 helper/main lock detector 沒有在 WR handshake timeout 前形成 `SEQ_READY`」：

```text
WR_STATE = WRS_S_LOCK
  ├─ helper_locked 曾短暫 = 1
  ├─ main_enabled 後曾 phase_locked = 1
  ├─ main_freq_locked = NEVER
  ├─ main_locked = NEVER
  └─ SEQ_READY = NEVER

約 48.031 s：PTP 進入 SLAVE 的同一時間，WR extension 進入 FAILURE/PTP fallback，WR state 回到 WRS_IDLE
```

權威摘要：

```text
EXPERIMENT_CLASSIFICATION = VALID_LOCK_DETECTOR_DIAGNOSTIC
SLAVE_STEP1_RESULT        = PASS
FIRST_PTP_SLAVE_MS        = 48031
FIRST_HELPER_LOCKED_MS    = 43635
FIRST_MAIN_ENABLED_MS     = 63419
FIRST_MAIN_PHASE_LOCKED_MS= 72212
FIRST_MAIN_FREQ_LOCKED_MS = NEVER
FIRST_MAIN_LOCKED_MS      = NEVER
FIRST_SPLL_READY_MS       = NEVER
FIRST_PSTAT_LOCKED_MS     = NEVER
FIRST_INACTIVE_BOUNDARY   = WR_EXTENSION_FAILURE
STEP4B_RESULT             = BLOCKED_BY_WR_EXTENSION_FAILURE
STEP5_RESULT              = NOT_COMPLETE
MERGE_ALLOWED             = false
```

## Provenance

- 日期：2026-09-13（Asia/Taipei）
- experiment id：`EXP-S5-WR-LOCK-DETECTOR-TIMELINE-D35A344-20260913`
- branch：`exp/step5-softpll-lock`
- source commit：`d35a344216059b9c57f76a6ade966494f218dded`
- Pain checkout：同一個 commit
- 硬體：Master `DE5 [1-11.1]`、Slave `DE5 [1-11.2]`
- observer：Slave 120000 ms，66 samples，0 sample errors
- 唯一變更：timeline observer 改為讀取並列印 `WR_LOCK_RESULT`、poll/unlocked/calibration counters、helper lock shadow、main frequency/phase lock shadow 與 `SEQ_READY`；沒有改 PI、SoftPLL 控制演算法、WR timeout、arbiter、I2C、reset 或 startup functional control
- 實體斷電：本實驗窗之前已完成；本輪沒有再重複斷電

## Build and programming

兩個 image 都由同一 source commit full compile 成功：

| image | result | timing | SOF SHA-256 | MIF SHA-256 |
| --- | --- | --- | --- | --- |
| Master | Full Compilation was successful | `TIMING_CLOSED=NO`, WNS `-0.058 ns` | `24a75a7775d2d4cb59ceb4e18906e6979f3c77d6b7e0fa0a16b10577a82e5e3c` | `1fa5e5a9103466841a5928115550672b20b8434049c0643b22f79dd73437f912` |
| Slave | Full Compilation was successful | `TIMING_CLOSED=NO`, WNS `+0.015 ns` | `fb83d10e7ea5f8b248f0618f5c638932fb54300a4c3b82459af6c687976afb30` | `72037f8f1deb23f37241c843069b121449111a4f698352dbe21d6b4230570e00` |

Master 與 Slave programming 都回報 configuration succeeded、0 errors、0 warnings。原始 build、program 與 image manifest 保存在 `raw/`。

## Lock-detector timeline

### Initial live state

在 478 ms 的第一筆有效 sample：

```text
core_link_ok=1
PTP_RX/TX active
RXERR_COUNT=0
PTP_STATE=8 UNCALIBRATED
PPSI_PDSTATE=3 PDETECTED
PPSI_EXTSTATE=1 ACTIVE
WR_STATE=WRS_S_LOCK
WR_LOCK_RESULT=1 (unlocked), check_lock=0
SPLL_SEQ_STATE=4 SEQ_WAIT_HELPER
SPLL_HELPER_STATE locked=0
SPLL_MAIN_STATE enabled=0
```

`WR_LOCK_POLL_COUNT` 與 `LOCK_UNLOCKED_COUNT` 隨後持續增加，`LOCK_CALIB_FAIL_COUNT` 沒有成為持續性主因；`spll_check_lock(0)` 的 shadow 沒有變成 1。

### Helper detector

在 43635 ms：

```text
SPLL_SEQ_STATE=SEQ_WAIT_HELPER
SPLL_HELPER_STATE locked=1, changed=0
SPLL_MAIN_STATE enabled=0
```

在 45832 ms，helper 又回到 `locked=0`。因此 helper 曾達到 lock detector 的 locked bit，但沒有在觀測窗內維持穩定的 `lock_changed`/sequencer handoff 證據。依 `softpll_ng.c` 的 sequencing FSM，Slave 必須滿足 `helper.ld.locked && helper.ld.lock_changed` 才會由 `SEQ_WAIT_HELPER` 進入 `SEQ_START_MAIN`；本輪沒有觀測到 `SEQ_READY`。

### WR extension failure

在 48031 ms，以下訊號同一筆 sample 改變：

```text
PTP_STATE      8 UNCALIBRATED → 9 SLAVE
PPSI_PDSTATE   3 PDETECTED    → 4 FAILURE
PPSI_EXTSTATE  1 ACTIVE       → 2 PTP fallback
parentIsWRnode 1              → 0
parentCalibrated 1            → 0
WR_STATE       WRS_S_LOCK     → WRS_IDLE
WR_FAILURE     00000000       → 02020001
```

`0x02020001` 的 source packing 為：

```text
last_fail_role  = 0x02 = WR_SLAVE
last_fail_state = 0x02 = WRS_S_LOCK
failure_count   = 0x0001
```

這與 `wr_handshake_fail()` 的實作一致：記錄失敗 role/state、設定 `WRS_IDLE`、reset WR servo，並停用 WR extension。故本輪的 Step4B 阻斷是有效 runtime evidence，不是把 PTP 尚未選成 Slave 誤判成失敗。

### Main detector

WR extension 失敗後，SoftPLL diagnostic shadow 仍能看到其內部 sequencer 後續活動：

```text
63419 ms: SPLL_SEQ_STATE=SEQ_WAIT_MAIN, main_enabled=1
72212 ms: main_phase_locked=1
全程：   main_freq_locked=NEVER
全程：   main_locked=NEVER
全程：   SPLL_SEQ_STATE=SEQ_READY NEVER
全程：   PSTAT_LOCKED=0
```

在 72212 ms，Main shadow 顯示 `freq_count=50`、`phase_count=100`，但 `freq_locked=0`、`locked=0`；這表示 phase detector 曾達到條件，不代表 Main frequency detector 或整體 Main lock 已成立。

## Measurement caveat

本輪 WB 交易層回報 66 samples、0 sample errors，且 link/traffic 活躍、RX error 為 0；因此沒有看到 timeout 型的 JTAG/WB 失敗。然而 WDIAGS 的 dynamic shadow 各欄位不是同一個 firmware seqlock frame，少數中途 sample 出現不可能的暫態組合，例如 `SPLL_SEQ_STATE=123` 或 `177`，之後又回到合法的 `SEQ_WAIT_MAIN`。這些欄位不被用來建立新的邊界；本報告只使用重複出現且與 source/其他訊號一致的關鍵 sample，以及 observer summary。

這個 caveat 不會把本輪降級成無效：`WR_FAILURE=02020001`、PTP/PD/extension 同步轉換、`WRS_S_LOCK→WRS_IDLE`、`main_enabled`、`main_phase_locked`、`main_freq_locked=0` 與 `PSTAT_LOCKED=0` 的組合已足以支持目前的上游 failure classification。但後續若需要逐事件因果，應讓 dynamic shadow 也使用一致的 epoch/commit 讀取或 firmware-side sticky latch。

## 判定與下一步

本輪不能算 Step4B PASS，因為 WR extension 在 `WRS_S_LOCK` 失敗並退回 PTP fallback；也不能算 Step5 PASS，因為沒有 `SEQ_READY`、Main frequency lock、Main lock 或 `PSTAT_LOCKED`。

下一輪應先針對「SoftPLL startup 完成時間與 WR S_LOCK timeout 的競合」做單一功能實驗，且不要同時更動 PI、arbiter 或 transaction contract。具體先以 source-backed 的 `WR_S_LOCK_TIMEOUT_MS` 為唯一變因，讓 WR handshake 等待時間覆蓋目前已觀測到的 helper/main startup 時間；保留所有 lock-detector telemetry，並以 `FIRST_SPLL_READY_MS`、`FIRST_MAIN_FREQ_LOCKED_MS`、`FIRST_MAIN_LOCKED_MS`、`FIRST_PSTAT_LOCKED_MS` 和 WR failure count 作為 pass/fail gate。

這不是把 timeout 延長就宣稱能解決問題：若延長後仍是 `main_freq_locked=NEVER`，就能排除「單純 timeout 太短」，下一個分流才回到 Main frequency PI/plant 或 startup handoff；若延長後 `SEQ_READY` 與 Step4B 成立，才有資格進行 Step5 closed-loop lock 的長時間驗證。

## Raw data

- [Master build log](raw/build-master-d35a344.log)
- [Slave build log](raw/build-slave-d35a344.log)
- [Master programming log](raw/program-master-d35a344.log)
- [Slave programming log](raw/program-slave-d35a344.log)
- [Corrected lock-detector observer log](raw/observer-d35a344.log)
- [Master build info](raw/build_info_jtag_master.txt)
- [Slave build info](raw/build_info_jtag_slave.txt)
- [Raw SHA-256 checksums](raw/checksums.sha256)

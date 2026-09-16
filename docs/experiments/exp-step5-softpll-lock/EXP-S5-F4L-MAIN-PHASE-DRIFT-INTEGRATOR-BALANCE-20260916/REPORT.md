# EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260916

日期：2026-09-16（Asia/Taipei）
Branch：`exp/step5-softpll-lock`
目的：依 `ai_advice/Step5/14_Astra.md`，以被動 Main producer snapshot 關聯
Main phase/integrator、Helper service 與 transport，找出 Step 5 phase acquisition
未收斂的邊界。

## Verdict

```text
CLASSIFICATION = FRAME_SCHEMA_INVALID
OBSERVER_STOP = STOP_DATA_UNRESOLVED
DIAGNOSTIC_PASS = NO
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

本輪沒有取得任何可信的 F4L frame。三次 F4L frame 嘗試的 WDIAGS read
均為 transport timeout；因此 `FRAME_SCHEMA_INVALID` 表示「傳回的 raw frame
不完整」，不是證明 firmware 的 F4L schema 錯誤，也不是 PLL 根因判定。依停止
條件，本輪在約 4.2 秒停止，沒有延長觀測或調整控制參數。

## Scope and control freeze

本輪只加入被動診斷資料與既有 WDIAGS 動態視窗的發布；沒有加入 control write。
F4L 使用既有 `0x00100B58..0x00100BDC` RAM window，34-word、3-page frame，沒有
修改 RTL、SDB、shared control ABI、第二個 reader 或 debug FIFO drain。

固定控制條件保持不變：

```text
Slave/Main PI       = Kp 300, Ki 1, prelock boost 20
Master PI           = Kp 300, Ki 1, prelock boost 20
Helper PI           = Kp -2250, Ki -2
phase guard         = 8 s
Slave bootstrap     = 3388
Master bootstrap    = disabled
timeout/threshold/lock/delock/anti-windup = unchanged
```

F4L 未宣稱 Step 5 pass；它的成功條件是取得跨多個時間窗、三個 page、同一
generation 且 transport/source 一致的 Main diagnostic frames。

## Laptop → GitHub → Pain

F4L 原始 implementation commit 為 `95ffa1de`。第一次 Pain firmware build
發現 F4L identity 下既有 Helper PI trace locals 只寫入未讀取，WRPC 的
`-Werror=unused-but-set-variable` 使 build 失敗。Laptop 只以 conditional
compilation 排除在 F4L image 中不使用的舊 trace locals；offline tests 仍通過，
修正 commit 為：

```text
SOURCE_COMMIT = 28b8e845e94cbb139f3a6bf08f59e8a3922549d6
PAIN_CHECKOUT = 28b8e845e94cbb139f3a6bf08f59e8a3922549d6
```

Pain 兩張板均重新 build 完成，Quartus 17.0 Build 595：

| image | result | SOF SHA-256 | MIF SHA-256 | timing |
|---|---|---|---|---|
| Master `DE5 [1-11.1]` | Full Compilation successful | `fac035a180579ec13a1d426809e54b419d8908c7b4b0e6aa8fb740e3183a0e15` | `3966ded2d93d9888b1dce06dd32e857a491fbea1646e2077c88b6d39be700737` | `TIMING_CLOSED=NO` |
| Slave `DE5 [1-11.2]` | Full Compilation successful | `6d5ecebc245a5701948976091f12dcbb49fe63214e1fd71ee0cae716b1d46cc5` | `0269e06656225af351eb318f23f8b029d77627d7633508fa43feb134638dc437` | `TIMING_CLOSED=NO` |

Build identity、firmware hashes 與完整 compile logs 保留於 [raw/build](raw/build)。
`TIMING_CLOSED=NO` 是本次 implementation caveat，不作為本輪 Step 5 verdict。

## Programming

兩次 programming 均成功，且 `0 errors, 0 warnings`：

```text
Master: 2026-09-16 18:51:25..18:51:44, cable DE5 [1-11.1], configuration succeeded
Slave : 2026-09-16 18:52:04..18:52:23, cable DE5 [1-11.2], configuration succeeded
```

Quartus programmer 的完整輸出保留於 [program-master.log](raw/program-master.log)
與 [program-slave.log](raw/program-slave.log)。

## Observer capture

執行的單一 F4L session：

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 100 2000 "" 120000 130000 f4l
```

observer 自身 return code 為 `0`，但依資料有效性停止，不代表診斷成功：

```text
session_elapsed_ms = 4197
target_duration_ms = 120000
hard_duration_ms = 130000
slave_cycles = 3
master_samples = 2
smoke_ok = 0
diag_valid = 0
page0 = 0, page1 = 0, page2 = 0
run_end_reason = STOP_DATA_UNRESOLVED
stop_reason = DATA_UNRESOLVED
single_reader = PASS
step5_complete = NO
step5_pass = NO
merge_approved = NO
```

物理 probe0 PHY status 仍可讀且 gate bits 通過；但同一 session 的 WDIAGS、
Helper 與 F4L Main direct diagnostic reads 全部 timeout。也就是目前只能確認
「部分 JTAG probe transport 活著」，不能確認 WDIAGS diagnostic bank 或 F4L
producer frame 的內容。

原始 observer output 保留於 [observer-f4l.log](raw/observer-f4l.log)。

## Offline replay

離線驗證結果保留於 [f4l-verdict.json](analysis/f4l-verdict.json)：

| evidence | result |
|---|---:|
| `STEP5_F4L_MAIN_DIAG` rows | 3 |
| valid F4L frames | 0 |
| unique valid frames | 0 |
| valid span | 0 ms |
| page 0 / 1 / 2 | 0 / 0 / 0 |
| invalid frame rows | 3 |
| invalid reasons | incomplete raw frame / transport timeout |
| diagnostic pass | NO |
| Step 5 pass | NO |

離線測試 `scripts/tests/test_step5_f4l.py` 通過；本輪 analyzer return code
為 `2`，正確表示 diagnostic inconclusive，而非程式崩潰或 Step 5 pass。

## Interpretation and next boundary

本輪不能回答「Helper 失鎖時 Main update 是否停頓」，因為沒有任何可信 Main
snapshot；也不能回答 residual/admission 與 Main progress 的關聯。不能從這些
timeout raw data 推論 phase PI、gain、threshold、arbiter 或 PLL plant 是根因。

下一輪若要繼續，第一個必要邊界是先做只讀的 WDIAGS/JTAG transport preflight
（重用既有 `read_wdiags_mapping_selftest.tcl` 或同等既有 reader），確認
WDIAGS bank 可穩定讀取後，再以同一 frozen control image 重跑 F4L。只有取得
可信且跨 page 的 F4L frame，才可以回到 Main phase/integrator 根因分析；本輪
不自動調參、不宣告 Step 5、不 merge 到 main。

## Evidence inventory

```text
raw/observer-f4l.log
raw/program-master.log
raw/program-slave.log
raw/build/*
analysis/f4l-verdict.json
```

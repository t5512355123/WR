# EXP-S5-F4E-ACQUISITION-MAIN-PHASE-PROGRESS-20260915

日期：2026-09-15（Asia/Taipei）  
branch：`exp/step5-softpll-lock`  
Pain exact checkout：`7851e760756a8e7021178e1358de017ae2cf2313`  
observer/image build checkout：`7851e760756a8e7021178e1358de017ae2cf2313`  
observer logic predecessor：`2e2c1a1d7c861aed498f2cc51f0adfb23d8e7dec`  
analysis/test commit：`7851e760756a8e7021178e1358de017ae2cf2313`  
functional source baseline：`5ba40f84cc4275f9a707bd847ac9809b267f7637`

## 結論

本輪是 Astra 指定的 read-only acquisition diagnostic，不是 Step5
驗收。最終 strict replay 結果：

```text
F4E_RESULT             = PHASE_CONVERGENCE_NOT_REACHED
F4E_DIAGNOSTIC_PASS   = true
STEP5_COMPLETE         = false
STEP5_PASS             = false
MERGE_APPROVED         = false
```

`F4E_DIAGNOSTIC_PASS=true` 只表示資料足以區分「Main 持續取得新樣本、
但 phase 尚未收斂」這個診斷邊界；它不表示時鐘已鎖定，也不表示可以
merge 到 `main`。

## 凍結設定與允許範圍

本輪只修改 host-side observer、離線 replay、測試與本報告。沒有修改
production C/RTL、identity、JTAG target 組成、gain、boost、threshold、
timeout/retry、arbiter、bootstrap 或 reset。

```text
candidate                  = 0/0
Main control               = +300/+1, prelock boost 20
Helper control             = -2250/-2
WR guard                   = 8 s
Slave bootstrap            = 3388
Master bootstrap           = disabled
observer mode              = acquisition
observer                   = one reader, read-only
Helper PI snapshot         = disabled
debug FIFO drain           = disabled
control writes during read = none
```

已核對 `git diff 5ba40f84 7851e760 -- firmware quartus rtl` 為空；本輪
編譯出的 functional image 沒有 production source 差異。

## Pain build / program

使用正確的 `quartus/jtag_runtime_diag` workflow：

```text
Master cable/top-level = DE5 [1-11.1] / DE5a_wr_master_jtag
Slave cable/top-level  = DE5 [1-11.2] / DE5a_wr_slave_jtag
build Master            = PASS, timing_closed=NO
build Slave             = PASS, timing_closed=NO
program Master          = PASS, Configuration succeeded
program Slave           = PASS, Configuration succeeded
```

```text
Master SOF Quartus checksum = 0x30B89B19
Slave SOF Quartus checksum  = 0x30B84088
Master SOF SHA256            = 1E8279C09689D0D403D16A0105FFA0C37C8F9B1A0E0FFA62097E084101C0BD85
Slave SOF SHA256             = 309F8C9A7EE526215869D77946113D38198B36C8334EA8926D0A95681B86C0C7
```

Program 時間（Asia/Taipei）：

```text
Master 15:55:33–15:55:52
Slave  15:56:11–15:56:29
```

## Capture

單一 Tcl reader 執行：

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  300 500 "" 120000 130000 acquisition
```

```text
capture start              = 2026-09-15 15:57:19.651 +08:00
last read end              = 2026-09-15 15:59:21.660 +08:00
target duration            = 120000 ms
hard duration              = 130000 ms
observer elapsed           = 122014 ms
run end                    = TARGET_REACHED
observer stop reason       = NONE
single reader              = PASS
sample parse errors        = 0
Master samples             = 20
Slave samples              = 39
```

raw：`raw/attempt-7851e760-jtag-runtime/tmp/observer.log`  
raw SHA256：
`8C63AA2E579B6F4C50AF206008C72A793A1EDABA4E5F89FAF68C409FF680C1C4`  
Pain 端與 Laptop 端 raw 行數：`85`

## Strict replay 結果

分析輸出：`analysis/replay-7851e760-jtag-runtime/`

```text
Slave raw samples                         = 39
Slave Main core-valid acquisition frames = 36
Slave fresh Main producer samples        = 35
Slave Main progress samples              = 35
phase detector-stable observations       = 30
phase-domain observations                = 30
phase in-band observations               = 3
phase-locked observations                = 0
Main PI_X range                          = -7123 .. 7641
non-zero PI clamp side                   = 0/39
transport-invalid samples                = 1/39
maximum transport-invalid streak         = 1
generation changes                       = 0
reset changes                            = 0
best core segment                        = 0 .. 117720 ms
best segment valid/fresh                 = 36/35
best segment phase observations          = 30
```

Main producer `sample_n` 由 `93944` 增加到 `541997`。這證明在可信的
acquisition window 內 Main 仍持續產生新樣本；同時 `MAIN_DETECTOR_PHASE_LOCKED`
在 strict phase observations 中始終為 0，故目前可見的未完成邊界是 phase
convergence。

這不是把 `frequency_locked=1` 當成完整鎖定。觀測中曾有短暫 frequency
lock 欄位變化，但沒有連續三筆 regression，因此 observer 沒有中止；
最後 frame 回到 frequency-locked、可供 phase-domain 判讀的狀態，phase 仍為 0。

## 服務與 Master 背景

各資料組分開判定，沒有把非原子讀取拼成單 cycle 因果：

```text
Helper coherent measurement = 0/39
position coherent reads      = 27/39
L2 telemetry valid            = 39/39
strict service windows       = 0
```

L2 raw counter 本身在窗口內增加，但因 Helper measurement group 沒有取得
可信 coherent frame，本輪不宣稱 Main/Helper demand、admission 或
completion 的因果關係；這些欄位維持 `UNKNOWN`，不能據此修改 PI 或
arbiter。

Master 只有 background samples，未進入本輪 Slave acquisition entry；其
狀態仍是 Master / `SEQ_WAIT_HELPER` 背景，沒有 terminal/disable/reset
事件。這不能被當成 upstream closure，也不能反推 Slave phase 的根因。

## 判讀

本輪支持的最小結論是：

```text
Slave WRS_S_LOCK
  -> Helper locked
  -> Main enabled and frequency acquisition
  -> Main producer keeps advancing
  -> phase detector never reaches phase lock
```

因此 `PHASE_CONVERGENCE_NOT_REACHED` 是目前第一個可由資料支持的未完成
milestone；它仍不是「PI 參數錯誤」的證明。由於 Helper coherent
measurement 沒有形成可用服務窗口，本輪不能再往 admission／仲裁或 PI
增益歸因。

## Earlier observer attempts（保留但不納入硬體 verdict）

```text
fab1acb1  host scope error：can't read "samples"；未形成硬體結論
be29e9f6  Tcl catch status 反轉；約 6.8 s 後 DATA_UNRESOLVED，未形成硬體結論
```

相關 raw SHA256：

```text
fab1acb1 = 8AEB5D3D9E2633DC36307623EE3BC89BB7B72D01B482EBC09E40715ED6C6E339
be29e9f6 = 21FFE704C32849DFF82A8EBBB5D70EDAB9E7214B8A020F49132242D46850D9F5
2e2c1a1d = 8D52192C5A6B03DF235CBB9932A697E25A26814D0FC2E27201FC875ADD7A42B
7851e760 = 8C63AA2E579B6F4C50AF206008C72A793A1EDABA4E5F89FAF68C409FF680C1C4
```

## Artifact index

```text
raw/attempt-fab1acb1-observer-scope-error/tmp/observer.log
raw/attempt-be29e9f6-observer-catch-error/tmp/observer.log
raw/attempt-2e2c1a1d-jtag-runtime/tmp/observer.log
raw/attempt-7851e760-jtag-runtime/tmp/observer.log
analysis/replay-2e2c1a1d-jtag-runtime/
analysis/replay-7851e760-jtag-runtime/
analysis/replay-7851e760-jtag-runtime/verdict.json
analysis/replay-7851e760-jtag-runtime/timeline.csv
analysis/replay-7851e760-jtag-runtime/service_windows.csv
```

本輪在 push report 後停止自動調參與 merge；下一步需把本輪結果交給
Astra，依其更新的 `08_Astra.md` 再決定下一個實驗。Step5 仍未通過。

# EXP-WRPC-STEP23-REGRESSION-20260825-AA6F03E

## 實驗摘要

- **Experiment ID**：EXP-WRPC-STEP23-REGRESSION-20260825-AA6F03E
- **日期**：2026-08-25
- **Repository**：`t5512355123/WR`
- **Branch**：`exp/step4-softpll-enable`
- **Git HEAD**：`65c632ec171f9edbbd6602dbe6da5a3d1adcedd7`
- **功能基準**：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- **Quartus**：Quartus Prime 17.0 Build 595 04/25/2017 SJ Standard Edition

## 這次想驗證什麼

本輪先建立可靠的 Step 2 / Step 3 read-only regression barrier，再決定是否允許進入 Step 4。重點是確認：

1. JTAG mailbox 的有效 sample 能否被重複讀取並通過驗證。
2. Master/Slave 的 Endpoint、MiniNIC、PTP、Foreign Master 與 WR signaling 是否仍有活動。
3. 單一 counter 的短時間 delta=0、counter decrease 或 state 不一致，是否應被視為量測不確定，而不是直接判定硬體失敗。

本輪**沒有 program FPGA、沒有 Quartus compile、沒有寫入 Wishbone control register，也沒有進行 Step 4 functional experiment**。下列 compile provenance 是 exact HEAD 在前一階段已完成的 fresh build 證據，僅作為本輪 branch/bitstream provenance 參考。

## 相較基準的唯一變因

`aa6f03e` / `65c632e` 保留原有 WR、PTP、signaling、SoftPLL、DDMTD、DCO、SI5340 與 PHY 行為；新增的是 read-only observability：

- `WAIT_STABLE_0_LOW_SAMPLE_COUNT` 診斷計數器。
- 以既有 `f_sat_inc` 計數，沒有接入 FSM、servo 或任何 functional control path。
- 透過既有 Wishbone read path 提供 REF/FB 低取樣觀測。
- `65c632e` 只補上 `wr_softpll_ng` component declaration，使診斷 port 與 entity/interface 一致。

本輪沒有再修改 source。

## Provenance

Exact HEAD fresh build 的輸出與 hash：

| 項目 | SHA256 |
|---|---|
| Master MIF | `e75d9bbb0a979529b2dd00b2c406fbbb8957ae7e89eb475d60cc4ccd2d09cae9` |
| Slave MIF | `ac625d4a549d5017f969849564ae937c3d06c9c298c9f850832bce6d94e1a9df` |
| Master QSF | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` |
| Slave QSF | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC（Master/Slave） | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Master SOF | `6f03a85eccc6a70c4a883e33a4be764b1a5db1dbde5930fc81760771ca635e11` |
| Slave SOF | `2aab8f1d964faedd348dc8c18b82fe887db5ab842b0b728b6786fd5e527d07f3` |
| Master build info | `de29bb6c1bab110e0f894e2c8ef677c61529b15495c01baaa51e6b95989cba55` |
| Slave build info | `41a4cbc2ccee2d859961671c1aa25aeaa85ead8c294903854a5b193604f84743` |

兩份 fresh compile 均顯示 Full Compilation was successful、Fitter successful；但 timing report 為 `TIMING_CLOSED=NO`，因此這些 SOF 仍有 timing caveat。這些 SOF 在本輪沒有被燒錄。

## 執行的唯讀測試

### Test A：Dashboard current-hardware snapshot

- Script：`/home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl`
- 執行方式：Quartus 17 `quartus_stp -t ...`
- Remote raw log：`build/artifacts/EXP-STEP4-REGRESSION-20260825-aa6f03e/dashboard-current-hardware.log`
- Local raw log：`raw/dashboard-current-hardware.log`
- Log SHA256：`5760b13d4d3e990c87c4fd3325d34b0039deb8ff02c97a1b4a193bd8c63626e`

結果：

- Master：Step 1 PASS、Step 2 PASS；MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`，PTP/MiniNIC counters 有 delta，RXERR delta=0。
- Slave：Step 1 PASS、Step 2 PASS、Step 3 PASS；MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`，Foreign Master count=1/best=0，parent flags `1/0/1`，RX `0x1001`、TX `0x1000`、LOCK_ENABLE=4。
- Slave dashboard 的 Step 4 downstream counters 沒有活動；其中 OCER 有單次 JTAG timeout。這只能先視為觀測警告，不能單獨宣稱硬體故障。

### Test B：Focused Step 2/3 repeated sampling

- Script：`/home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl`
- 參數：`20 500 25`
- Local raw log：`raw/handshake-current-hardware.log`
- Log SHA256：`140bc919a4c0eed451893755fd89fe3703a0ca191f27a42e63ed8acda2d2704d`

結果摘要：

```text
Master valid_samples=20 invalid_samples=0 counter_decreased=0
Master PTP_TX_DELTA=65 STEP2_REGRESSION=PASS

Slave valid_samples=20 invalid_samples=0 counter_decreased=0
Slave PTP_TX_DELTA=12 STEP2_REGRESSION=PASS
Slave STEP3_REGRESSION=PASS
Slave POST_STEP3_LOCK_STAGE=TIMEOUT
Slave STATE_EVIDENCE=READ_INCONSISTENT
Slave signal_good=20 signal_bad=0 state_idle=20 state_good=0
```

20/20 samples 均通過 mailbox validity 檢查，沒有 timeout sample 混入判定，也沒有 counter decrease。Slave 的單一 current-state 讀值持續顯示 `WRS_IDLE`，但 RX `LOCK`、TX `SLAVE_PRESENT`、LOCK_ENABLE 與 parent evidence 均重複成立；因此保留 `STATE_EVIDENCE=READ_INCONSISTENT`，不把它直接改寫成 Step 3 hardware FAIL。

## Acceptance table

| Gate | 結果 | 證據 |
|---|---|---|
| Step 1 PHY / Link | PASS | dashboard 與 focused samples；ready/link/error 條件正常 |
| Step 2 Endpoint / MiniNIC / PTP | PASS | Master/Slave 20/20 valid；角色、MAC、PTP activity、RXERR=0 |
| Step 3 WR Parent / Signaling | PASS（保留 state inconsistency） | Slave Foreign Master、parent flags、RX/TX signaling、LOCK_ENABLE 重複成立 |
| Step 4 SoftPLL Startup | NOT_PROVEN | current hardware 的 DMTD/tag/TRR/IRQ/helper downstream delta=0；本輪未 program exact HEAD SOF |
| Step 5 Closed-loop Lock | NOT_ASSESSED | 不屬於本輪 regression barrier |

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PROVEN
STATE_EVIDENCE = READ_INCONSISTENT
HARDWARE_FIRMWARE_FAILURE = NOT_PROVEN
MEASUREMENT_ISSUE = PRESENT
```

這次的證據支持 Step 2 / Step 3 regression barrier 通過，因此從 gate 角度允許下一輪 Step 4；但**不能**宣稱 Step 4 已通過。Step 4 目前最可靠的描述是：JTAG 讀值與既有 SoftPLL downstream event 沒有提供足夠的 sustained activity 證據；這可能是目前硬體狀態、觀測邊界或診斷 mapping 的問題，本輪沒有足夠證據將它歸因於 RTL/firmware functional failure。

## 燒錄與 compile 狀態

- FPGA program：**未執行（依本輪要求）**，因此沒有 programmer log/checksum。
- Quartus compile：本輪未重新執行；紀錄中的 exact HEAD fresh compile provenance 來自前一階段，兩片均成功但 `TIMING_CLOSED=NO`。
- Current-hardware JTAG read：執行成功，`quartus_stp` 回傳 0 errors、0 warnings。
- Current-hardware 與 exact HEAD fresh SOF 的對應關係：**未建立**。因此 current-hardware 的 PASS 只能稱為 current hardware regression，不可稱為 exact HEAD fresh-SOF runtime reproduction。

## 原始檔案

本實驗的 raw artifacts 位於：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP23-REGRESSION-20260825-AA6F03E/raw/`

內容包括：

- `dashboard-current-hardware.log`
- `handshake-current-hardware.log`
- `quartus_jtag_master_compile.log`
- `quartus_jtag_slave_compile.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`

## Next Step

下一輪若要做 Step 4，應先依使用者授權，以 exact `65c632e` fresh SOF 完成雙板 program，再重跑 focused Step 2/3 gate；只有重跑仍 PASS，才讀取新的 Step 4 startup counters，特別是 REF/FB `WAIT_STABLE_0_LOW_SAMPLE_COUNT` 以及 DMTD deglitch acceptance 到 tag/TRR/IRQ/helper 的 delta。不得同時修改 SoftPLL algorithm 或其他 functional variable。

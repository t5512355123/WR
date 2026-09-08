# EXP-WRPC-STEP5-HPLL-WIDE-PHASE-ACCUMULATOR-REVERSE-BOOTSTRAP-1024-20260909

## 結論

本輪 source 已完成 laptop push、Pain pull、Master/Slave 編譯，且在互動式
sudo 權限下重新燒錄成功。然而新映像燒錄後，兩端 WR upstream 沒有恢復到
可執行 Step5 的狀態；因此本輪沒有有效的 Step5 closed-loop measurement，
不得把先前用舊映像取得的 observer 輸出當成新版本結果。

```text
SOURCE_COMMIT = e66f9417debd2768e05cf8c0248ae4e31de8d9f5
MASTER_SOF_SHA256 = 746d6909e160e17c097aad684c101243f04da84b064b3ac6126dbddf5873be03
SLAVE_SOF_SHA256  = b4609baafa214e3b55a2478aecdefe3ce16891147441178ab8fb14da0b004b15
MASTER_PROGRAM = PASS (Configuration succeeded, 0 errors)
SLAVE_PROGRAM  = PASS (Configuration succeeded, 0 errors)
TIMING_CLOSED = NO
STEP1_TO_STEP3 = BLOCKED_AFTER_PROGRAMMING
STEP4B = BLOCKED_BY_STEP1
STEP5 = NOT_RUN_UPSTREAM_NOT_READY
MERGE_APPROVED = NO
```

## 本輪 source 變更

- `vendor/wrpc-sw/softpll/spll_helper.c`：以 64-bit internal shadow arithmetic
  保存 phase accumulator、setpoint 與 tag state；既有 int32 diagnostic fields
  維持相容並做飽和匯出，避免長時間 frequency bias 造成 32-bit overflow。
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`：將 normal HPLL tracker
  保持啟用，bootstrap 改為 `1024`、reverse seed 啟用。
- coherent observer：修正 FINC/FDEC 對 absolute applied position 的方向公式，
  並同步記錄實際 `kp=-300, ki=-1`。

## Build 與 programming provenance

Pain 端以 `e66f941` 建立兩個 JTAG image。兩個 build 均為 Full Compilation
successful，但 timing 尚未 closed：

```text
Master WORST_SETUP_SLACK_NS = -0.242
Slave  WORST_SETUP_SLACK_NS = -0.336
```

使用 Master→Slave 順序燒錄。第一次非互動式 sudo 嘗試未取得權限，產生的
`preflight-1-old-image.log` 與 `observer-coherent-1200-old-image.log` 明確標記
為舊映像/無效觀測，全部排除。第二次互動式燒錄確認：

```text
Master cable DE5 [1-11.1]  Configuration succeeded
Slave  cable DE5 [1-11.2]  Configuration succeeded
```

## Actual post-programming preflight

重新燒錄成功後等待並執行兩次 read-only preflight：

### preflight 2

```text
Master WDIAGS_PTP = DISABLED; Step 1 = error; PTP RX/TX delta = 0
Slave  WDIAGS_PTP = LISTENING; Step 1 = error; WR_RX_SIGNAL = UNKNOWN
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

### preflight 3

```text
Master WDIAGS_PTP = DISABLED; Step 1 = error; PTP RX/TX delta = 0
Slave  WDIAGS_PTP = MASTER (expected SLAVE); Step 1 = error
Slave  WR_RX_SIGNAL = UNKNOWN, count = 0
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
```

這不是 Step5 controller 的 pass/fail 證據，而是新映像燒錄後 upstream/runtime
尚未有效啟動的阻斷。尤其 Slave role 顯示為 `MASTER`，不能在此狀態執行
closed-loop 觀測。

## Step5 判定

本輪唯一存在的 1200-sample observer log 是燒錄權限失敗期間的舊映像資料，
已移名為 `observer-coherent-1200-old-image.log`，不可用來評估本輪 source。
因此：

```text
STEP5_VALID_MEASUREMENT = NO
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_COMPLETE = NO
```

## Recovery note

為恢復新映像燒錄後的 upstream state，嘗試透過既有 Pain power-cycle UI 操作。
Edge 頁面的 Pain `開啟` 控制影像信心分數為 `0.424`，低於安全門檻 `0.820`，
所以操作在任何電源切換前安全中止，沒有猜測座標或重試點擊。必須先由使用者
手動完成一次 Pain 實體斷電重開，或在控制頁面恢復可辨識後再執行受控重啟；
重啟後應先取得乾淨的 Master/Slave Step1–4B preflight，才可重新開始 Step5。

## 原始資料

本輪原始輸出、build metadata、program logs、三份 preflight 與無效舊映像
observer 均保存在本資料夾的 `raw/`。Pain archive SHA-256：

```text
5375c7f1444d3b1e810fbbcc7dd5a43bc628611e47a675412f77df3251556c37
```

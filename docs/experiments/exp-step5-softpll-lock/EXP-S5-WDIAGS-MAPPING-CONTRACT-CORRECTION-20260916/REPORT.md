# EXP-S5-WDIAGS-MAPPING-CONTRACT-CORRECTION-20260916

日期：2026-09-16（Asia/Taipei）  
分支：`exp/step5-softpll-lock`  
測試基準 commit：`5c295b7beb63fbe74353b6142b08514e3131ae31`  
硬體：DE5 [1-11.1]（Master）、DE5 [1-11.2]（Slave）

## 目的

驗證 WDIAGS mapping contract 修正後，能否在已燒錄的 JTAG runtime image 上取得 F4L Main 被動診斷 frame，並以同一觀測窗關聯 Helper 狀態、Main update 與 WR/PHY health。這輪不修改 PI、gain、threshold、timeout、控制分支、detector、anti-windup、DAC、RTL 或 SDB。

## 執行與映像

- Master、Slave 均 Full Compilation successful。
- Master SOF：`0x30B89B19`，Slave SOF：`0x30B84088`。
- 兩張板 programming 均 `Configuration succeeded`，0 errors、0 warnings。
- timing 仍未 closed：Master worst setup slack `-0.047 ns`，Slave `-0.268 ns`；此項獨立列出，不混入 Step5 lock 判定。
- 離線 WDIAGS preflight 測試與 F4L analyzer 執行成功返回；F4L analyzer 對本輪資料正確拒絕不完整的 closure，不把 smoke 結束誤判成 PASS。

## 結果

### 1. WDIAGS mapping contract：PASS

修正後的 preflight 使用 source-backed 欄位：snapshot request/ack count、mapping counter、mapping inverse。兩張板的 BEGIN/END sample 均 `valid=1`，request/ack 都是 0，且 inverse 通過 32-bit bitwise-not counter 驗證；`WDIAGS_MAP_RESULT` 兩板皆 `begin_valid=1 end_valid=1`。

因此，本輪已排除先前「reader 使用過期固定 magic」造成的 mapping 誤判。raw：`raw/wdiags-preflight.log`。

### 2. 首次 F4L smoke：frame transport 可用，但 closure 未完成

首次 smoke 的 Slave 取得 4 個 coherent、unique Main F4L frame：

```text
MAIN_F4L_VALID=1
TRANSPORT_COHERENT=1
INIT_GENERATION=1
WR_CORE_VALID=1
PHY_LINK_USABLE=1
HELPER_LOCKED=1
```

frame 頁面分布為 `page0=0 page1=2 page2=2`。`MAIN_F4L_UPDATE_ID` 持續前進，Helper update 也持續增加；但 10 秒 smoke gate 到期時尚未看到 page 0，因此結果為 `SMOKE_NOT_REACHED`。這證明 frame format、seqlock transport 與 page 1/2 的讀取路徑可用，但不足以宣告 F4L diagnostic closure PASS。

同期 `PSTAT_LOCKED=0`，所以 Step5 仍未完成。

### 3. 重測顯示硬體狀態具有啟動相依性

在首次 smoke 後的 retry，Slave 只取得 1 個 page 1 frame，隨後 WR 狀態已是 `CURRENT_WR_STATE=0`、`PD_STATE=4`、`WR_FAILURE_REASON=3`，觀測器依 terminal guard 停止為 `WR_SESSION_ENDED`。

重新以同一已驗證映像初始化兩張板後，兩次短測均在 10 秒 smoke gate 前未取得有效 Main F4L frame；Slave 的 Helper 觀測為 `HELPER_LOCKED=0`、`HELPER_LOCK_COUNT=14`，Main frame 為 invalid，停止原因為 `F4L_SMOKE_SCHEMA_NOT_READY`。這兩次資料是有效的「未完成啟動／未進入 Helper lock」證據，不能當成 mapping failure，也不能當成 Step5 failure 的唯一根因。

## 判定

```text
WDIAGS_MAPPING_CONTRACT = PASS
F4L_FRAME_TRANSPORT     = PASS (首次 smoke 的有效窗口)
F4L_DIAGNOSTIC_CLOSURE  = INCONCLUSIVE
PSTAT_LOCKED             = 0
STEP5_PASS               = NO
MERGE_APPROVED           = NO
```

本輪沒有足夠的三頁、長時間、一致 frame 來完成 F4L analysis；更沒有 `PSTAT_LOCKED=1` 的連續證據。因此不能把 Step5 標成 PASS，也不進行 merge。

## 下一步

依 Fable 的工作包順序，停止繼續擴充 reader 細節，進入下一輪單一功能變因：Helper PI 重標定（F1，`kp=-4500`、`ki=-8`）。其餘 bootstrap、lock detector、Main PI、guard、timeout 與仲裁保持不變；下一輪仍須先做離線測試，再依 Laptop push → Pain pull/build/program → 只讀觀測 → 回傳 raw/report → push 的流程執行。

## 原始資料

- `raw/build/`：Pain build metadata、firmware/MIF/SOF hash 與 build log。
- `raw/program-jtag-master.log`、`raw/program-jtag-slave.log`：首次 programming。
- `raw/program-jtag-master-reinit.log`、`raw/program-jtag-slave-reinit.log`：重初始化 programming。
- `raw/wdiags-preflight.log`：mapping contract preflight。
- `raw/observer-f4l-smoke.log`：首次有效 frame window。
- `raw/observer-f4l-smoke-retry.log`：WR session ended window。
- `raw/observer-f4l-smoke-reinit.log`、`raw/observer-f4l-smoke-postwait.log`：重新初始化後未進入有效 F4L frame 的窗口。
- `analysis/`：四次 F4L raw 的離線分析輸出。


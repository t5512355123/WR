# EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823`
- 日期：2026-08-23
- Branch：`exp/step4-softpll-enable`
- Git commit：`0c3fbea10f8c7ac99f64b6386c6c22226af8e36f`
- 實驗性質：先完成 Step 2 / Step 3 regression，再觀察 Step 4 DMTD qualification abort
- 是否修改功能演算法：否；本輪只增加 read-only diagnostics 與對應 Tcl decode

## 本次想驗證什麼

前一輪證據顯示 `clk_sampled` 有 transition，但 DMTD accept、event、tag、TRR、IRQ、helper update 沒有持續活動。本輪增加兩組飽和唯讀計數器，分別記錄：

- `WAIT_STABLE_0` 中，LOW qualification 已開始後被高電位中止的次數
- `GOT_EDGE` 中，HIGH qualification 已開始後被低電位中止的次數

目的在於區分「輸入不穩定而 qualification 被重置」與「沒有進入 qualification」；不修改 deglitch threshold、FSM、DDMTD polarity、SoftPLL、WR signaling、PI、lock threshold、DCO、SI5340 或 PHY 行為。

## 相較前一版唯一修改

1. `dmtd_with_deglitcher.vhd` 增加 LOW/HIGH qualification abort 的 16-bit 飽和唯讀計數器。
2. `wr_softpll_ng.vhd` 將兩組 counter 接到既有 `SPLL_DMTD_REF_SEEN` / `SPLL_DMTD_FB_SEEN` 讀值：
   - bits `[31:16]`：LOW qualification abort
   - bits `[15:0]`：HIGH qualification abort
3. 既有完整 sampled/accept counter 與 Wishbone 位址不變。
4. Step 4 focused/boundary Tcl 只更新 decode 與輸出，避免把新欄位誤判成舊 packed counter。

## Build provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`d15e1f864029941988cfbc32292da14707e90c872d70d8d2a19b7b35a36fb66a`
- Slave MIF SHA-256：`dc036093710e36a628a3e392be9e95e2122d2823a92d7e140925e6b7a270adcb`
- Master SOF SHA-256：`cc60d043a12be295b877f87c641e103056a86edb8aa7a2bc4f4822f2a72161e8`
- Slave SOF SHA-256：`e9fcacf136b9c67cab618e33fb494bb38c293244753e4ffdeec9f67f1b71750e`
- Master programmer checksum：`0x30A761CC`
- Slave programmer checksum：`0x30AA2B3F`

## 燒錄結果

- Master cable：`DE5 [1-11.1]`，configuration succeeded，0 errors，0 warnings。
- Slave cable：`DE5 [1-11.2]`，configuration succeeded，0 errors，0 warnings。
- 原始 programmer log：pain artifact `artifacts/EXP-WRPC-STEP4-QUAL-ABORT-20260823/program_master.log` 與 `program_slave.log`。

## Runtime 原始證據

原始 log 已保存於本機同名 `raw/EXP-WRPC-STEP4-QUALIFICATION-ABORT-20260823/` 資料夾，來源為 pain 同名 artifact：

- `dashboard.log`
- `regression_step23.log`
- `regression_handshake.log`
- `step4_startup_events.log`
- `dmtd_boundary.log`
- `build_master.log`、`build_slave.log`、`build_provenance.txt`
- `program_master.log`、`program_slave.log`

### Step 1～3 focused regression

| Gate | Master | Slave | 證據 |
|---|---|---|---|
| Step 1 PHY/link | PASS | PASS | dashboard：ready/link/RX/TX/CPU reset 正常，encoding error=0；status=`FF`/`CF` |
| Step 2 Endpoint/PTP | PASS | PASS | 20-sample focused：MAC、MODE、PTP、PTP/MiniNIC activity、RXERR 通過；Slave `FOREIGN=1/0` |
| Step 3 WR handshake | N/A | PASS | 20-sample focused：parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、LOCK_ENABLE=4 |

`read_step23_register_reliability.tcl` 的綜合輸出曾將 Slave `WR_FAILURE_DEBUG` 分類成 `STEP3_INDEPENDENT=INVALID`；這個分類與 focused handshake 的 20 個 accepted samples 不一致，因此本紀錄採用 source-backed focused gate，而不把單一 shadow classification 當成硬體 failure。

以下欄位待燒錄後的 read-only regression 完成後補入：

- Step 2 repeated focused log：
- Step 3 repeated focused log：
- Step 4 startup focused log：
- Step 4 DMTD boundary log：
- qualification abort raw log：

## Observation

每個 counter 均以 accepted read 的 before/after delta 判斷；`TIMEOUT`、stale value、read inconsistency 或 counter decrease 只能標示 measurement invalid/retest，不能直接當成硬體 failure。dashboard 的短窗口中，Slave `PTP_TX delta=0` 被標示為資訊，不影響 Step 2，因為同時有 PTP_RX、MiniNIC TX/RX activity 且 RXERR delta=0。

Step 4 focused 30 samples（gap=250 ms）觀測：

- Master：`SPLL_MODE_SEQUENCE=0x00020009`、`RCER=0`；sampled reference 有增加，但 accept、DMTD event、tag、TRR、IRQ、helper update 都為 delta=0。
- Slave：`SPLL_MODE_SEQUENCE=0x00030009`、`RCER=1`；reference/feedback sampled counter 有增加，但 accept、DMTD event、tag、TRR、IRQ、helper update 都為 delta=0。
- Master/Slave 的 `DMTD_REF_SEEN` 與 `DMTD_FB_SEEN` 都是 `0x0000FFFF`：依本 commit 的 packing，`LOW abort=0`、`HIGH abort=65535`。這代表 HIGH qualification abort counter 已飽和；本次 30-sample window 的 abort delta 為 0，不能宣稱本次仍在持續增加。
- `SPLL_DMTD_STATE=0x0C00000A`，focused decode 為 reference/feedback state=2、threshold reached=1；但 accept/event downstream 仍無活動。
- DMTD boundary script 的 10 samples 也重現同一結果：`QUAL_ABORT REF_LOW=0000 REF_HIGH=FFFF FB_LOW=0000 FB_HIGH=FFFF`，`ACCEPT`、tag grant/valid、TRR write 都不變。

## Conclusion

Step 1、Step 2、Step 3 已由本輪 fresh image 的 repeated read-only evidence 通過；Step 4 仍為 FAIL/NOT PASS。這不是 compile 或 JTAG exception 問題：fresh SOF 已成功燒錄，所有 Step 4 downstream counter 在有效讀值下長時間保持不變。最精確的目前定位是「sampled transition → deglitch qualification/accept」邊界仍未產生新的 accept；新 counter 顯示歷史上 HIGH qualification abort 已飽和，但因已飽和且本窗口 delta=0，不能單獨把它當成即時 fault rate。

本輪結論：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = 尚未由本輪 Step 2/3 證據支持
JTAG/DASHBOARD_MEASUREMENT_FAILURE = 本輪 focused reads 無；dashboard 的單一 TEMP/OCER timeout 僅標示資訊
```

## Next Step

使用本 commit 產出的 fresh SOF 執行：

1. Step 2 focused repeated regression。
2. Step 3 handshake focused repeated sampling。
3. Step 4 startup focused 30 samples。
4. DMTD boundary/qualification-abort 30 samples。

下一輪仍只允許 read-only diagnostics；不要改 threshold、deglitch FSM、DDMTD polarity、SoftPLL algorithm 或任何 control behavior。若要進一步縮小 abort 根因，應新增不改功能的「每個 abort source 分開 sticky/saturating counter」或以 simulation/內部 timing evidence 交叉驗證，並維持 Step 2/3 regression barrier。

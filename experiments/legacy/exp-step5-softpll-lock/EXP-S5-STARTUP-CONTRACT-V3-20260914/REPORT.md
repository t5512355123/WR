# EXP-S5-STARTUP-CONTRACT-V3-20260914

## 結論

N1 startup-contract observer 修正：PASS。

Step5 closed-loop lock：NOT COMPLETE。

本輪只驗證 startup gate 是否把重疊診斷資料誤當成 readiness/generation；不調整 PI、仲裁、timeout 或 SoftPLL。結果確認兩板的 readiness 只能安全判定為 UNKNOWN，因此 gate 維持關閉，沒有送出任何控制命令。

## 實驗身分

- source commit: 2ac1219a8aea791c5f87dc67f951fb5a1d58d1ab
- branch: exp/step5-softpll-lock
- unique source change: scripts/jtag/read_fixed_image_shell_ready_gated_runtime_retest.tcl
- observer SHA-256: 60e85cbbd840d032ff6acc4bd140146760f547794231fbe109cc2d6057e4eeb3
- experiment ID: EXP-S5-STARTUP-CONTRACT-V3-20260914
- configuration: fresh Master/Slave JTAG full build and programming, followed by bounded --audit-only capture
- control parameters: unchanged

工作樹中的既有 dirty report 與未追蹤 raw/artifact 檔案均保留，未清理或覆蓋；本輪只提交上述 Tcl observer。

## N1 修改與安全界線

1. 加入硬體無關 --selftest，在載入 Quartus package 前執行。
2. 加入 --audit-only；只讀取診斷資料，不送 VUART 命令，也不送控制性 Wishbone write。
3. 不再把 ASTAT 的單一 compact generation 複製成三個獨立 generation 證據。
4. 沒有可驗證的 owner/version/同代 RAM marker schema 時，輸出 READINESS=UNKNOWN、REASON=BANK_SCHEMA_UNPROVEN，並強制 GATE=0。
5. 讀出尾端七個 raw word，將已辨識的 SLOCK_TRACE 或歷史 SPLL_REINIT_OR_OVERLAY_CANDIDATE 保留為候選解釋，不提升為 readiness。
6. Master 與 Slave 都有獨立約 30 秒的 bounded audit window。

## 建置與燒錄

Pain 使用 source commit 2ac1219，完成：

- Master firmware build: PASS
- Slave firmware build: PASS
- Master Quartus JTAG full compile: PASS; TIMING_CLOSED=NO
- Slave Quartus JTAG full compile: PASS; TIMING_CLOSED=NO
- Master programming cable DE5 [1-11.1]: PASS, 0 errors
- Slave programming cable DE5 [1-11.2]: PASS, 0 errors

SOF 身分：

| role | MIF SHA-256 | SOF SHA-256 | worst setup slack | timing |
| --- | --- | --- | ---: | --- |
| Master | 83ab55e9f041997d0624214c31711b28e281f5ad1f64b22220d6c05a8c4f1d3d | 8d3d97fcc33975cc3fc804f13ce94c460ac2b5773ed968914b0b1b0cef07101c | -0.058 ns | NO |
| Slave | 404be43a4720ec6bc97c2591a6a1ad1902a7c31fe98e8f52396c7336fe9b6a38 | 964dbf1dfcb10d3e8bb96abf2a8992d176a9eba5aa0060c8341c50f101b9bda3 | +0.015 ns | NO |

## Preflight

標準 WB runtime preflight 完成，transport 路徑可信：

WB_TRANSPORT_PROTOCOL = PRELOAD_THEN_TOGGLE_COMMIT
PROBE_3WAY_MATCH_COUNT = 353
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED

兩板的上游判定並不一致：Master 的 Step2 sample 為 PASS，Slave 有一個 Step2 sample 為 INVALID，因此本輪不把 Step4B 或 Step5 當作硬體里程碑判定。這不影響 N1 observer selftest 與 audit-only 驗收。

## N1 selftest

6/6 cases 通過，所有 audit fixture 的注入次數為 0：

- legacy seven-word fixture: SPLL_REINIT_OR_OVERLAY_CANDIDATE，READINESS=UNKNOWN
- verified readiness fixture: STATUS=READY、CONTROL_ELIGIBLE=1
- generation mismatch fixture: STATUS=NOT_READY、REASON=GENERATION_MISMATCH
- owner unproven fixture: STATUS=UNKNOWN、REASON=BANK_SCHEMA_UNPROVEN
- SLOCK overlay fixture: BANK_SCHEMA=SLOCK_TRACE、READINESS=UNKNOWN
- runtime history nonzero fixture: STATUS=READY、REASON=NO_POST_ARM_RUNTIME_HISTORY、CONTROL_ELIGIBLE=0

N1_SELFTEST_RESULT=PASS cases=6 injection_calls=0

## 硬體 audit-only 結果

兩張板均完成約 30 秒、127 samples 的 read-only capture：

| role | board | samples | elapsed | BANK_SCHEMA | READINESS | reason | control writes |
| --- | --- | ---: | ---: | --- | --- | --- | ---: |
| Master | DE5 [1-11.1] | 127 | 30198 ms | SPLL_REINIT_OR_OVERLAY_CANDIDATE | UNKNOWN | BANK_SCHEMA_UNPROVEN | 0 |
| Slave | DE5 [1-11.2] | 127 | 30197 ms | SLOCK_TRACE | UNKNOWN | BANK_SCHEMA_UNPROVEN | 0 |

可見 raw 證據包括 BOOT_GENERATION=1、ASTAT compact marker bits，以及尾端 bank 的 raw address/value。Master 尾端資料符合歷史 re-init/overlay 候選形狀；Slave 尾端第一字為 5752534C，符合 SLOCK_TRACE magic。這兩種資料都不能當成 readiness。

最重要的安全驗收是：

N1_AUDIT_ONLY_DONE ... READINESS=UNKNOWN ... CONTROL_WRITES=0
N1_READINESS_SUMMARY ... READINESS=UNKNOWN ... CONTROL_WRITES=0

沒有 mode master 注入、沒有 VUART stimulus，也沒有透過 observer 放寬 startup gate。

## 判讀

這輪證明：

- 先前把尾端 overlay 或 re-init/SLOCK trace 當 readiness 的方法不可信。
- BOOT_GENERATION 與 ASTAT compact generation 相同，不足以證明三個 marker producer 同代且各自有效。
- 即使背景 runtime counter 正在更新，observer 仍必須把 readiness 保持 UNKNOWN，而不是猜成 READY 或 GENERATION_MISMATCH。
- N1 的 fail-closed 行為正確避免了在錯誤 gate 下補送命令。

## 下一步與停止條件

本輪在 N1 完成後停止，不進入 PI 或仲裁修改。

下一個允許方向是 N2：用當次已燒錄 image 的 ELF/map，確認真實 debug_precrt_boot_generation、三個 marker 與三個 tag 的地址，以及 JTAG bridge 的 CPU-RAM address translation；若 RAM 路徑仍不可驗證，就維持 READINESS=UNKNOWN。之後才可做同一 session 的 startup 到 WR deadline 到 PLL 時間軸，分辨 acquisition 與 tracking。

本輪不宣稱 Step4B PASS，也不宣稱 Step5 PASS；歷史 Step4B 證據不因這輪 observer audit 被撤銷，但本輪 Slave 的上游 Step2 INVALID 使它不具備新的 Step4B closure window。

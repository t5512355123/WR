# Step7：外接供電拓樸下的 Slave 啟動恢復

## 範圍與基線

- 分支：`step7-physical-measurement`；基線：`f3b2acb60a87018e62d264acc4125be06c13c57d`。
- Master `1-11.1` 已移出 PCIe，使用外接 6-pin；Slave `1-11.2` 留在 PCIe。PCIe 是否同時供電由使用者提出疑問，尚未量測供電軌。
- 主程式 WR servo 維持成功版 `/2 acquisition + /12 tracking`、60/120 ps state threshold。milestone 與保護 archive 完全不改。
- 本輪不代表 SMA 實體精度已通過；目標先恢復兩板取樣 TIME_VALID 持續 300 秒。

## 修改前實測

2026-10-05 13:49 儀表板：Master Helper=1、TIME_VALID/PPS_VALID=1；Slave Helper=0、Main/PSTAT=0、TIME_VALID/PPS_VALID=0。兩板 link/RX/TX 均為 1；ref/DMTD/RX clock counters 均前進。

被動 scalar 讀取：Slave Helper output 五筆均為 5，frequency error 為 +543..+577，update count 前進；獨立 L2 Helper start/completed 固定在 3388，failed=0。Master error −3..+2、output 約 49760，服務持續前進。這支持 Slave 細調落在下限，但不能把非原子 scalar 拼成同 cycle 因果。

Helper 多字 publication frame 全部 epoch guard 失敗，因此不把它當 coherent snapshot；保留原始證據，不放寬 guard。

## 唯一 production 變因

只在 Slave 加入 SI5340 啟動 reset：以獨立板載 50 MHz clock，燒錄後 RSTb 拉低 1 ms，釋放後等待 50 ms 才釋放既有 I2C controller reset。原 controller 再走既有约 42 ms initial-start delay。

原碼 RSTb 直接接 CPU_RESET_n，FPGA warm-program 不保證清除外接晶片狀態。這是測試「啟動狀態不確定」的 intervention，不預先宣稱它是根因。static table 本身重寫 N dividers，故也不能直接宣稱所有 FINC/FDEC 必然累積。

不改 Master startup、3388/2048 bootstrap、PI/gain、normal tracker、arbiter、mailbox、PHY、WR servo 或 TIME_VALID 輸出。

依據：[Skyworks Si5340/41 reference manual §3.1](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf) 說明硬重置還原 NVM 初值；[datasheet Table 5.8](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/data-sheets/Si5341-40-D-DataSheet.pdf) 的 serial-ready 上限為 15 ms。50 ms 是本實驗的保守等待，不做任何 NVM 寫入。

## 流程、驗證與停止條件

1. Laptop 完成 timing reference model、wiring guard、editable workflow 測試，push candidate。
2. Pain pull exact candidate；四步腳本 build → compile → Slave/Master program → read-only dashboard。編譯成功後方可燒錄。產物仍在 `output/`，不新增 SHA acceptance gate。
3. 先查 SI_CONFIG、CPU reset、link、Helper/五項 lock；最多等待 900 秒取得 TIME_VALID。若 JTAG 衝突、transport 無效、reset/generation 異常，保存原因並停止，不終止他人 reader。
4. 成功取得後執行既有 303 秒每板 sequential capture；300 秒 TIME_VALID 判定須完整、每筆有效且 gap <=1000 ms。不能用 observer 跑完當 PASS，也不能宣稱兩板同窗或已量得 SMA skew。
5. 結果、原始 logs、測試紀錄取回 Laptop，寫 REPORT 後 push；不自動 merge main。

Model/structural tests 不等於 HDL simulation；若本機無 HDL simulator，以 Pain fresh Quartus compile 驗證 HDL integration，報告分開說明。

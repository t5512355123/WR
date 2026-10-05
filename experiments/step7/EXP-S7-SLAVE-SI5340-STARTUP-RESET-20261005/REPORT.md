# Step7 外接供電拓樸：Slave SI5340 啟動恢復

## 目前判定

**RESET_CANDIDATE = REJECTED；TIME_VALID_300S = NOT_ESTABLISHED。**

完整編譯與燒錄成功，但 Slave TX_READY=0、兩板 link gate 失敗，未取得 Slave TIME_VALID。停止此 candidate，不將它當可用版本；新一輪撤回 reset 修改。

## 拓樸與修改前 evidence

使用者確認拔離 PCIe 的是 Master `DE5 [1-11.1]`，改用外接 6-pin 供電；Slave `1-11.2` 仍在 PCIe。未量測供電軌電壓／紋波，不能由 JTAG 可用推論電源完全正常，也不能由事件先後直接認定 PCIe 是根因。

2026-10-05 13:49:31+08 儀表板：

| 項目 | Master | Slave |
|---|---:|---:|
| Link / TM / RX / TX | 各為 1 | 各為 1 |
| Helper lock | 1 | 0 |
| Main frequency / phase / Main / PSTAT | 不適用 | 各為 0 |
| TIME_VALID / PPS_VALID | 各為 1 | 各為 0 |
| 伺服狀態 | 不適用 | SYNC_TAI |

兩板 ref、DMTD、RX counters 皆前進；短時 clock activity 僅證明有活動，不是精準頻率或抖動量測。

被動 scalar 五筆：Master Helper frequency error −3..+2、輸出約 49760、更新與服務計數前進；Slave frequency error +543..+577、output=5、更新前進，但服務 start/completed 固定 3388，failed=0。不同 scalar／L2 組間非原子，不宣稱同 cycle 因果。

追加既有 lock-convergence reader：Slave bootstrap 完成 3388、done=1，實際 forced FINC=3388、FDEC=0；normal request/completed=0、DCO error=0、ACK error=0。讀到的 error=150000、output=5 支持細调下限失效。該 legacy reader 的 Helper state/limits 為 INVALID，故不採信其 lock threshold、百分比或完整 coherent-frame 判定；只與獨立 dashboard/scalar/RTL counters 交叉核查。取樣期間 boot/CPU/WR/SI reset 計數增量為 0。

## 唯一 production 變因

Source candidate：`fe1a532f260d0c78306560e2d307004826faead5`。

Slave 的 SI5340 每次 FPGA 燒錄後硬重置 1 ms，再等待 50 ms 才釋放原 I2C controller。使用板載獨立 50 MHz；counter 初始值為 0、飽和後不重複觸發。原 static table、bootstrap=3388、physical code step=64、8 秒 Helper phase guard、Helper/Main PI 與 WR servo `/2+/12`、60/120 ps 都不改。Master production 未改。

這測試「FPGA 與外部 clock IC 啟動狀態未共同重置」是否影響此次失敗。原 static table 重寫 N divider，並不能先認定所有 coarse FINC 必然累積；若此次仍失敗，reset hypothesis 不可當成已證明根因。

參考 [Skyworks Si5340 reset 說明](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf) 與 [datasheet serial-ready timing](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/data-sheets/Si5341-40-D-DataSheet.pdf)。不寫入 NVM。

## 建置、燒錄與結果

Laptop 20 項離線 model/structural/wrapper tests 通過，詳見 OFFLINE_TESTS.md；不是 HDL simulator 結果。Pain pull exact source 後 build/compile 成功，Quartus 正確辨識新增 VHDL entity，兩板 timing_closed=NO，並未以 timing closure 做 acceptance。

Slave programming 14:13:35–14:13:54、Master 14:13:54–14:14:13，兩者各為 0 errors / 0 warnings、configuration succeeded。

14:14:43、14:16:06、14:39:15+08 的獨立 dashboard 均未得到兩板 link；Slave RX_READY=1、TX_READY=0、Helper/Main/PSTAT/TIME_VALID/PPS_VALID=0。Master Helper/TIME_VALID/PPS_VALID=1，但 link=0。14:15 clock activity 顯示兩板 ref/DMTD/RX counters 仍前進。

中斷期間資料夾另出現 14:20:24、14:32:07、14:34:53 開始的三組 programming logs，已一併保留；不是本 agent 發起。重新連線後先確認沒有進行中的 JTAG reader/programmer，未终止使用者程序。

這幾個隔離 snapshot 不構成連續觀測，也不排除中斷期间其他 reset；不能直接認定 reset pin 的 electrical waveform 或某個 PHY causal branch 已被證明。結果只足以拒絕此 candidate。

未啟動 300 秒 acceptance capture（upstream gate 失敗）；未調整 valid 判定、PLL gain 或 threshold。新增 VHDL 留在本實驗 `source/`，不再接入 active Quartus。

Pain 額外保存此輪 output/build/logs 的 recoverable backup：`/tmp/wr-step7-reset-evidence.BVA4NR/reset-build-and-logs.tar.gz`；Laptop 以 raw/build、raw/program、raw/observe 歸檔 evidence。

## 保護與限制

受保護 archive、Step1–6 milestone 未修改。使用者先前的 untracked program logs 與 Laptop 歷史 review 檔案保留。所有新工作在 `step7-physical-measurement`，不 merge main。

若兩板各自完成 TIME_VALID >=300 秒，僅認定恢復數位同步可用性；sequential JTAG capture 不證明 SMA 同步邊緣精度、offset <60 ps、外接電源品質或每次啟動都可重現。

# Step7：Slave bootstrap 512 工作點實驗

## 狀態

`DIGITAL_TIME_VALID_RECOVERY = OBSERVED`：兩板 TIME_VALID/PPS_VALID 恢復；本輪依使用者指示停止追加實驗，只完成歸檔。

`TIME_VALID_300S = NOT_RUN`；`STEP7_PHYSICAL_EDGE_MEASUREMENT = NOT_RUN`。沒有把這次逐點恢復宣稱成新的 300 秒 PASS 或實體 SMA 精度 PASS。

最終有效狀態來源是使用者貼回的 **2026-10-05 15:12:52+08:00** 儀表板輸出，完整保存於 [user-dashboard log](raw/observe/user-dashboard-20261005T151252+0800.log)。這是使用者提供的終端紀錄，不是 agent 新發起的讀取。

Candidate source：`4d7e38189e26707afffb2ecc404f3ad0e8a08326`。Laptop 20 項離線 tests 通過後已 push，Pain pull 到相同 commit；build_current、Master/Slave full compile 與 root output export 均已成功。Timing closed=NO，並非本輪 TIME_VALID 驗收門檻。

## 變因

相對原本 main production，僅 Slave coarse FINC count 3388→512。上一輪 reset intervention 完整撤回。Master bootstrap=2048、code/physical-step=64、Helper/Main PI、8 秒 guard、WR servo `/2+/12`、60/120 ps 與所有 valid 判定不變。

估算依據與限制見 PLAN.md：舊工作點 +543..+577、DAC output=5，fine tracker 無負向 headroom；歷史 plant slope 只是下一點的 seed，不能直接當現在的實測線性模型。

## 拓樸

Master `1-11.1` 使用外接 6-pin 並拔離 PCIe；Slave `1-11.2` 留在 PCIe。供電電壓／紋波、晶振頻率／溫度未量測。先恢復數位同步，再談 SMA 實體精度；不直接把 PCIe 移除宣稱成已證明根因。

## 硬體結果

兩台 fresh full compile 成功，SOF 已放回 Laptop root `output/`：Master 36,818,536 bytes、Slave 36,831,090 bytes。編譯時間分別為 14:50:07、14:54:30（Asia/Taipei）。Master/Slave 都仍有 unconstrained clocks/paths，沒有宣稱完整 timing closure。

14:57:18 Slave 燒錄成功；14:57:36 Master 燒錄成功。燒錄順序 Slave→Master，兩次皆 0 errors、0 warnings。

14:58:14 dashboard：兩板 Link/TM/RX/TX 均為 1，Master Helper/TIME_VALID/PPS_VALID=1；Slave 尚在啟動，Helper/TIME_VALID=0。

14:58:45–14:58:51 Slave 五筆獨立 scalar：frequency error −9、−11、−11、+14、+20；output 63407、63212、62967、63189、63031（範圍 62967..63407，非 5/65531 rail）；update count 112639→135908。L2 Helper start 1913→2466、completed 1913→2465，兩組 failed counters 均 0。各 scalar 與 L2 取樣並非跨組原子，不能宣稱單 cycle 因果；Helper multiword publication epoch guard 尚未形成可信 frame，未使用其 payload 當 coherent data。

14:59:53 dashboard：Slave Helper/Main frequency/Main phase/Main/PSTAT 五項均為 1，Step1–4 gates PASS；TIME_VALID 尚未成立，WR state=SYNC_PHASE、CKO=+697 ps。這證明 Helper 與 Main lock 路徑恢復，不代表 TIME_VALID 300 秒已通過。

15:00:11 啟動最多 900 秒 readiness；到 elapsed=540 秒時仍未取得兩板均有效的 poll。15:09:13 暫停 agent 自己的等待程序，只做唯讀健康檢查，未開始 303 秒 acceptance capture，也沒有重燒或重置。

15:09:39 dashboard：兩板 Link/TM/RX/TX 仍為 1，Slave 五項 PLL locks 仍為 1，但 TIME_VALID=0、state=WAIT_OFFSET_STABLE、CKO=−1633 ps。其後 Helper scalar frequency error +2..+10、output 49351..49918，已明顯離開上下限。

15:10 左右開始 60 秒 CKO/SETP/DMS 診斷。中途發現另一個 shell PID=33099 啟動持續 dashboard（PID=39332，開始時間 15:11:03）；agent 實驗 shell PID=11138、監看 shell PID=19421，確認不是 agent 這兩個 session 啟動的程序。兩個 reader 有末段重疊，故整段 capture 的 raw/analyzer 輸出保留，但不把混合資料用於正式 CKO 精度或因果判定。未代使用者終止 dashboard；未再啟動第二個 reader。

**15:12:52 使用者回傳 dashboard，確認已成功輸出 TIME_VALID：**

| 信號 | Master 1-11.1 | Slave 1-11.2 |
|---|---|---|
| Link / TM / RX / TX | 全部 1 | 全部 1 |
| Helper lock | 1 | 1 |
| Main frequency / phase / Main / PSTAT | 不適用 | 全部 1 |
| TIME_VALID / PPS_VALID | 全部 1 | 全部 1 |
| snapshot valid / stable | 全部 1 | 全部 1 |
| snapshot count | 909 | 64 |
| PPS register TM / PPS validity | 全部 1 | 全部 1 |
| TAI / cycles | 908 / 124999999 | 913 / 124999999 |
| WR servo state / CKO | 不適用 | WAIT_OFFSET_STABLE / −1840 ps |

此 frame 時間距本輪 Master programming 完成約 15 分 16 秒，但不同板子的實際讀取時間並非同時；snapshot count=64 也不能取代逐筆連續有效時間的證明。沒有把 Master/Slave TAI 相差 5 秒直接認定為同步偏差，必須有共同事件時間戳記或同窗量測才可作該判定。

依使用者最新指示「成功輸出 time valid 了，現在寫好實驗報告就好了」，不恢復 readiness、不追加 300 秒觀測、不再修改控制參數。保留目前成功 session，歸檔 build/program/observe/analysis、root SOFs，再推送本 Step7 branch；不 merge main，不重封 Step1–6 milestone。

## 為何 CKO 超過 120 ps，仍顯示 TIME_VALID

目前 source 在 `WAIT_OFFSET_STABLE` 首次 `<60 ps` 時呼叫 `enable_timing_output(...,1)`。後續 `TRACK_PHASE` 遇 `>120 ps` 會退回 `SYNC_PHASE`，但該 fallback 本身不呼叫 disable；其他 PTP/session 路徑仍可能關閉 validity。故 TIME_VALID=1 與當前 WAIT state、CKO=−1840 ps 可以同時成立，並不等於每個新更新都在 ±60/120 ps。

Step5 `INFO/LOCK_ACQUIRED_NOT_STABLE` 是儀表板短觀測窗的判定；此 frame 五項 lock bits 都為 1，但短 frame 仍不證明 PLL 鎖定連續 300 秒。60/120 ps 門檻未放寬、未強制設定 TIME_VALID。

## 目前判讀

3388 原點的 fine output 卡在下限、正常服務不前進；512 候選已離開下限、frequency error 接近零、正常服務前進、五項 PLL locks 恢復，且後續使用者確認兩板 TIME_VALID/PPS_VALID 恢復。這支持「本次啟動的粗調工作點／fine-loop headroom 不適當」這個可處理邊界。不能據此宣稱 PCIe 移除造成特定電源或時鐘故障；本輪沒有量測電壓、reference frequency、溫度或 SMA edge skew，也未證明每次重新啟動都會成功。

SMA_CLKOUT 仍接 `pps_p_o`，Master/Slave routing 未修改；本輪恢復的是後續實體量測所需的數位同步前置條件，不是 Step7 實體量測結果。

## 資料保護

Step1–6 milestone、`04_WR_archive_step6_pass` 未修改。本機 unrelated historical review 與 Pain 原本的 untracked Step6 program logs 保留。上一輪新增 raw 使用 scoped Git stash 保存，另有 archive backup，不刪除。

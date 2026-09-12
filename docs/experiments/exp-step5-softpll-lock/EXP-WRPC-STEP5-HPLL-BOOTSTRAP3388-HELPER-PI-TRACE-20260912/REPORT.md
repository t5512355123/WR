# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-PI-TRACE-20260912

## 判定

Step 5：NOT COMPLETE（尚未通過）。

本輪完成了 PI trace instrumentation 的部署與有效讀取，但未完成原定 3600-sample audit；因此本輪只作為診斷結果，不可作為 continuous Step5 PASS，也不能 merge。

## 實驗目的

前一輪 cold baseline 已重現 Helper lock、Main frequency lock，但 Main phase lock=0。Astra 建議先補齊 PI 內部狀態，分辨 phase error、integrator、輸出飽和與 target-to-DCO admission 的關係，再決定功能變因。

本輪唯一程式變更是將既有 read-only Helper PI snapshot audit 的 experiment label 與 bootstrap metadata 從 3360 對齊目前 baseline 3388，並標示 PI trace enabled。沒有修改 SoftPLL 控制器或 lock semantics。

## 版本與 build

- Branch：exp/step5-softpll-lock
- Source commit：e769d2bfb6f94ca4422e47f4486e138234d3905f
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：b6b2cf8fe94606017fb842d074781e969f35d8088916c9c0ca7d36d204d15ce5
- Slave SOF SHA256：232501b5eadc9a8944b88de2dc8bf2907d23d9c84eeb87571a9042b958a60fa3

## Programming 與 upstream

依 Master -> 45 秒 -> Slave 順序燒錄完成。第一次 preflight 顯示 Slave 尚在 recovery；等待 120 秒後的 settled preflight 為：

- Master Step1 / Step2 / Step3 / Step4A：PASS
- Slave Step1 / Step2 / Step3 / Step4B：PASS
- Helper update count：持續增加
- Helper lock：1
- Main frequency lock：1
- Main phase lock：0
- PSTAT lock：0
- first inactive boundary：MAIN_PHASE_LOCK

因此 PI audit 開始時 upstream 已 ready。

## PI trace diagnostic window

原定命令為 3600 samples、100 ms cadence、double-read snapshot transport。由於每個 sample 需要多次 serialized Wishbone transaction，實際速率約每分鐘 60 samples；為避免把一個超過一小時的低效率 observer 當成正式 Step5 長測，於第 1571 筆 sample 主動停止。

已取得 1571 筆 PI samples。代表性結果：

    PI_TRACE_PRESENT=1
    PI_SNAPSHOT_REJECTS=0
    PASS_A_VALID=1
    PASS_B_VALID=1
    MATCH=YES
    ACK_TIMEOUT=0
    ACK_MISMATCH=0
    EPOCH_GENERATION_MISMATCH=0
    EPOCH_CHANGED_DURING_READ=0

sample 702 曾觀察到：

    RAW_ERROR=-1682441
    LD_ERROR=-150000
    PI_INTEGRATOR_BEFORE=268394714
    PI_PROP_TERM=22500000
    PI_Y_PREROUND=291046762
    PI_UNCLAMPED_OUTPUT=71061
    PI_CLAMPED_OUTPUT=65531
    PI_CLAMP_SIDE=1
    HELPER_OUTPUT=65531

到 sample 1571，trace 已回到非飽和輸出：

    RAW_ERROR=-706
    LD_ERROR=-706
    PI_INTEGRATOR_BEFORE=263358467
    PI_PROP_TERM=105900
    PI_Y_PREROUND=263693325
    PI_UNCLAMPED_OUTPUT=64383
    PI_CLAMPED_OUTPUT=64383
    PI_CLAMP_SIDE=0
    HELPER_OUTPUT=64383

這表示 PI trace 確實能分辨「raw error 被 Helper error clamp」與「PI output 是否再被 actuator rail clamp」，且 snapshot transport 本身沒有出現 timeout、ACK mismatch 或 double-read mismatch。

## Interpretation

本輪最重要的結果不是 Step5 lock，而是把前一輪看不到的內部狀態補出來：

- Helper PI trace 可可靠取得。
- 啟動後曾有明顯的高側 PI clamp；之後 output 回到合法範圍。
- integrator 仍維持很大的正值，表示啟動/追趕階段的 PI 狀態會長時間影響後續 actuator operating point。
- 這個 audit 的 PI snapshot 讀取成本太高，不能直接拿未完成的 1571 samples 宣告長時間穩定。
- PI audit 中部分 live lock fields 出現 0，與同一部署前的 settled preflight 不一致，因此這些欄位只能作為 snapshot audit 的輔助資訊；Step5 判定仍以 coherent runtime observer 與 preflight gate 為準。

Step 5 仍未成立：Main phase lock=0、PSTAT lock=0，且沒有 continuous 300 秒的完整判定窗口。

## 下一輪

下一輪改讀既有 Main PI prelock trace，將 bootstrap metadata 同樣對齊 3388，直接取得 Main phase branch 的 error、PI output、clamp side、lock counter 與 phase-lock transition。這能把目前第一個失敗邊界從「Main phase lock=0」進一步定位到 Main controller 的實際控制狀態。

在 Main trace 完成前，不再盲調 Helper Kp、Ki 或 cooldown。若 Main trace 顯示 phase error 長期超出 1200，才針對 phase measurement/authority 做單一功能 A/B；若 phase error 已在 band 內但 counter 不累積，則改查 lock-detector/phase-state transition。

## 原始資料

- Raw archive：raw-observer.tar.gz
- Raw archive SHA256：5239d444c4643167da713a802e803a11958a083dc62f1b06ed1ba6add62fdc73
- archive 內含 preflight、settled preflight、build、program 與截至停止時的 PI audit log。

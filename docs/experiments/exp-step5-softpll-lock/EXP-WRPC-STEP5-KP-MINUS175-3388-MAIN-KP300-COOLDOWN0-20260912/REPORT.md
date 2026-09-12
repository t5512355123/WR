# EXP-WRPC-STEP5-KP-MINUS175-3388-MAIN-KP300-COOLDOWN0-20260912

## 判定

**Step 5：NOT COMPLETE（未通過）**

這輪雖然在觀測結束時 `HELPER_LOCKED_FINAL=1`、`MAIN_LOCKED_FINAL=1`、`PSTAT_LOCKED_FINAL=1`，但完整 lock chain 只有 18.006 秒，沒有達到 Step 5 要求的 300 秒連續閉迴路鎖定；同時仍觀察到 actuator hunting 與 360 次 error-band exit。因此不能把這輪標記為 Step 5 PASS。

## 實驗目的

在已通過 accounting 修正的基準上，單獨測試提高 Helper proportional gain：

- Helper Kp：`-150` → `-175`
- Helper Ki：`-1`
- Main Kp：`+300`
- Main Ki：`+1`
- bootstrap completed：`3388`
- physical DCO step：`64`
- normal HPLL cooldown loads：`0`
- Helper PI update decimation：`1`
- Helper lock threshold：`2000`
- Helper lock samples：`1000`

其他功能路徑、DCO page/mask sequence、bootstrap、lock gate、observer accounting 均未修改。

## 軟體與建置

- Branch：`exp/step5-softpll-lock`
- Source commit：`fd4b2e4bb566ae6b5a54f638a4de70e168295cb7`
- Quartus：17.0.0 Build 595 Standard Edition
- Master compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.058 ns`
- Slave compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.001 ns`
- Master SOF SHA-256：`dee68fcbd8f74c41bd7e98acceee8546e4dc7a6b96897ad59b54656927215e35`
- Slave SOF SHA-256：`d9fe01fd93aed152219abe9cea71d82d7dd6c4a775ebdc16428096e1a1a28fa3`

## 燒錄與觀測

- Master programming：成功，0 errors / 0 warnings，18:01:00–18:01:19
- Slave programming：成功，0 errors / 0 warnings，18:02:22–18:02:40
- 觀測：3600 samples，100 ms cadence，約 360 秒
- `POST_BOOTSTRAP_BASELINE_SET=1`
- transport / coherent measurement：PASS
- position accounting：PASS
- reset stability：PASS

## White Rabbit runtime 結果

Step 1–4B transport/runtime gate 皆通過；Step 5 的最後判定如下：

- coherent measurement snapshots：3600
- rejected accounting candidates：5
- measurement accounting fails：0
- position invariant fails：0
- transaction invariant fails：0
- DCO lower-bound fails：0
- frequency error mean：`0.0192`
- frequency error RMS：`9.3163`
- frequency error range：`-31 .. 33`
- Helper error mean：`-6.3542`
- Helper error RMS：`1746.3915`
- Helper error max absolute：`5963`
- `FRACTION_ABS_ERROR_LE_200=0.1872`
- low rail fraction：`0.0`
- high rail fraction：`0.0`
- no-rail fraction：`1.0`
- Helper lock count max/final：`1000 / 1000`
- Helper lock rise/fall events：`514 / 352`
- error-band exit events：`360`
- actuator hunt observed：`YES`
- Helper dynamics：`UNDERDAMPED_OR_OVERAGGRESSIVE`
- Helper locked seen：`2161` samples；final：`1`
- first Helper lock sample：`29`
- Main enabled/frequency/phase/main/PSTAT final：`1 / 1 / 1 / 1 / 1`
- full-chain maximum：`18.006 s`
- full-chain 300 s：`0`
- Step5 chain result：`NOT_COMPLETE`
- SPLL delock count first/max/final：`0 / 5 / 0`
- boot generation / CPU / WR-core / SI-config drops：`0 / 0 / 0 / 0`

## 結論與下一步

Kp `-175` 沒有改善穩定性。相較可信的 Kp `-150`、cooldown `0`、bootstrap `3388` 基準，本輪 Helper RMS 由約 `1026` 上升到 `1746`，完整 chain 由約 `113.791 s` 降至 `18.006 s`，因此淘汰 Kp `-175`。

下一輪只測試 Helper integral 的作用速度：恢復 Kp `-150`，保留 Ki base `-1`，但每 4 次 Helper PI update 才套用一次積分項，使有效 Ki 約為 `-0.25`；比例項仍每次 update 生效。不得放寬任何 Step 5 判定門檻。

## 原始資料

- Raw archive：`step5-kp175-raw.tar.gz`
- Raw archive SHA-256：`fe50d49b07b523d324cb10f4b470a237a0142e22f20d490bc190d2ff0f4d5185`
- 內容：Pain build logs、build metadata、programming summary、preflight log、3600-sample coherent observer log


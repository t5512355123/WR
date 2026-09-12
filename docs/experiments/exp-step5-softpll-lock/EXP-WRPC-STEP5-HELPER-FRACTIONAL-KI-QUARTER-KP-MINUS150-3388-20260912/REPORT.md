# EXP-WRPC-STEP5-HELPER-FRACTIONAL-KI-QUARTER-KP-MINUS150-3388-20260912

## 判定

**Step 5：NOT COMPLETE（未通過）**

本輪將 Helper 積分項改為每 4 次 PI update 套用一次，等效 Ki 約為 `-0.25`。完整觀測雖然 transport、coherent measurement、position accounting、reset stability 都通過，但最後 `MAIN_PHASE_LOCKED=0`、`MAIN_LOCKED=0`、`PSTAT_LOCKED=0`，且 `FULL_CHAIN_300S=0`，所以不能標記 Step 5 PASS。

## 實驗目的與唯一變因

以可信的 Kp `-150`、bootstrap `3388` 基準，降低量化 actuator 上積分項的作用速度：

- Helper Kp：`-150`
- Helper Ki source value：`-1`
- Helper integral decimation：`4`
- effective Helper Ki：約 `-0.25`
- Main Kp/Ki：`+300 / +1`
- bootstrap completed：`3388`
- physical DCO step：`64`
- normal HPLL cooldown loads：`0`
- Helper PI update decimation：`1`
- Helper threshold / lock samples：`2000 / 1000`

比例項仍在每個 accepted Helper update 生效；只在每 4 次 update 才保留 Ki，沒有放寬任何 lock 或 Step 5 判定門檻，也沒有修改 DCO page/mask、bootstrap、Main lock gate 或 observer accounting。

## 軟體與建置

- Branch：`exp/step5-softpll-lock`
- Source commit：`0f7e030d68e8249456d1f11c79e0bfdef4df0383`
- Quartus：17.0.0 Build 595 Standard Edition
- Master compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.058 ns`
- Slave compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.001 ns`
- Master SOF SHA-256：`51978cff20f0ebab6c69b0e5948240db94b93ee31fed24323cfb6c3438d7e141`
- Slave SOF SHA-256：`29befbca76e0228de2340acdb4dc6b8fbb254ea60bc90f8facf76c69ffcebff1`

## 燒錄與觀測

- Master programming：成功，0 errors / 0 warnings，18:32:04–18:32:23
- Slave programming：成功，0 errors / 0 warnings，18:33:28–18:33:46
- 燒錄後等待初始化：120 秒
- preflight：transport PASS；Step 1–4B PASS；Step 5 啟動窗未完成
- coherent observer：3600 samples，100 ms cadence，約 360 秒

## Runtime summary

- `POST_BOOTSTRAP_BASELINE_SET=1`
- coherent measurement snapshots：3600
- rejected accounting candidates：3
- measurement accounting fails：0
- position snapshots：3370
- position invariant fails：0
- transaction invariant fails：0
- DCO lower-bound fails：0
- measurement coherence：`PASS`
- position accounting：`PASS`
- reset stability：`PASS`
- frequency error mean/RMS：`-0.1783 / 7.1380`
- frequency error range：`-31 .. 29`
- Helper error mean：`-58.5889`
- Helper error RMS：`10551.5917`
- Helper error max absolute：`3677`
- `FRACTION_ABS_ERROR_LE_200=0.1561`
- low/high/no-rail fraction：`0.0 / 0.0 / 1.0`
- Helper lock count max/final：`1000 / 1000`
- Helper lock rise/fall events：`208 / 121`
- error-band exit events：`268`
- actuator hunt observed：`YES`
- Helper dynamics：`UNDERDAMPED_OR_OVERAGGRESSIVE`
- Helper locked seen/final：`2644 / 1`
- first Helper lock sample：`1`
- Main enabled/frequency/phase/main/PSTAT final：`1 / 1 / 0 / 0 / 0`
- full-chain maximum：`0.000 s`
- full-chain 300 s：`0`
- Step5 chain result：`NOT_COMPLETE`
- SPLL delock count first/max/final：`0 / 5 / 0`
- boot generation / CPU / WR-core / SI-config drops：`0 / 0 / 0 / 0`
- final Helper error/output：`8 / 64127`

## 結論與下一步

這個方向被實體實驗否定：減慢積分作用沒有改善穩定性，反而造成 Helper 平均偏差與 RMS 大幅增加，並使 Main phase lock 無法建立。相較可信的 Kp `-150`、Ki `-1`、integral 每次更新的基準（Helper RMS 約 `1026`、full chain 約 `113.791 s`），本輪 Helper RMS 為 `10551.5917`、full chain 為 `0 s`，因此淘汰 fractional-Ki=quarter。

下一輪應恢復有效 Ki `-1` 與 Kp `-150`，不要再沿著單純降低積分增益的方向；優先測量並修正「Helper lock 狀態已成立但 Main phase/PSTAT 仍反覆掉鎖」的實際觸發條件，維持所有嚴格 Step 5 gates。

## 原始資料

- Raw archive：`step5-fractional-ki-raw.tar.gz`
- Raw archive SHA-256：`504e716fe5b237c92f25632110897cfeb0e87a41f525a8ef1f87c51a3f5cdc6d`
- 內容：Pain build logs、build metadata、programming logs、preflight log、3600-sample coherent observer log


# EXP-WRPC-STEP5-TRUE-BASELINE-REVALIDATION-KP-MINUS150-3388-COOLDOWN0-20260912

## 判定

**Step 5：NOT COMPLETE（未通過）**

這是第一次由 fitted Slave top-level 明確固定 `STEP5_NORMAL_HPLL_COOLDOWN_LOADS => 0` 的 true baseline revalidation。Step 1–4B、coherent measurement、position accounting 與 reset stability 均通過，但 Helper 最終未鎖定、Main phase/PSTAT 未鎖定，且完整 300 秒 chain 為 0，因此不能標記 Step 5 PASS。

## 實驗設定

本輪恢復可信 PI 設定，並修正前幾輪的 cooldown provenance：

- Helper Kp：`-150`
- Helper Ki：`-1`，每次 accepted Helper update 套用
- Main Kp/Ki：`+300 / +1`
- bootstrap completed：`3388`
- bootstrap reverse：`1`
- physical DCO step：`64`
- `STEP5_NORMAL_HPLL_COOLDOWN_LOADS`：`0`（Slave top-level 實際值）
- Helper threshold / lock samples：`2000 / 1000`
- observer bootstrap steps：`3388`

唯一功能性差異是恢復 Helper 完整 Ki；同時將 Slave top-level cooldown 從實際的 8 固定為 0。沒有放寬 lock、accounting 或 Step 5 判定門檻。

## 軟體與建置

- Branch：`exp/step5-softpll-lock`
- Source commit：`4fa3f3b2ffbe5f09907d0df4529b985de7e75c5f`
- Quartus：17.0.0 Build 595 Standard Edition
- Master compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.058 ns`
- Slave compilation：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.209 ns`
- Master SOF SHA-256：`f29b50cd3614b6498f0312a60216c81e451ed0d24f78f9f7614749c50257f63c`
- Slave SOF SHA-256：`9cd02a9203fd15044a667a4c5d3dac5cd7bd56e1c4fc2a567029dcf1593d89ae`

## 燒錄與 preflight

- Master programming：成功，0 errors / 0 warnings，19:04:16–19:04:35
- Slave programming：成功，0 errors / 0 warnings，19:05:38–19:05:56
- 燒錄後等待初始化：120 秒
- JTAG/WB transport：PASS
- Step 1–4B：PASS
- preflight Step 5 first inactive boundary：`MAIN_PHASE_LOCK`

## 3600-sample coherent observer

- samples：`3600`
- elapsed：約 `486.457 s`
- post-bootstrap baseline：`SET`
- coherent measurement snapshots：`3600`
- rejected accounting candidates：`102`
- measurement accounting fails：`0`
- position snapshots：`3434`
- position invariant fails：`0`
- transaction invariant fails：`0`
- DCO lower-bound fails：`0`
- measurement coherence：`PASS`
- position accounting：`PASS`
- reset stability：`PASS`

Runtime dynamics：

- frequency error mean/RMS：`-0.0225 / 9.8805`
- frequency error range：`-37 .. 36`
- Helper error mean：`36.9683`
- Helper error RMS：`2786.8456`
- Helper error max absolute：`6513`
- `FRACTION_ABS_ERROR_LE_200=0.0422`
- low/high/no-rail fraction：`0.0 / 0.0 / 1.0`
- Helper lock count max/final：`1000 / 203`
- Helper lock rise/fall events：`1364 / 889`
- error-band exit events：`152`
- actuator hunt observed：`YES`
- Helper dynamics：`UNDERDAMPED_OR_OVERAGGRESSIVE`
- Helper locked seen/final：`157 / 0`
- first Helper lock sample：`1`
- Main enabled/frequency/phase/main/PSTAT final：`1 / 1 / 0 / 0 / 0`
- full-chain maximum：`0.000 s`
- full-chain 300 s：`0`
- Step5 chain result：`NOT_COMPLETE`
- SPLL delock count first/max/final：`0 / 250 / 0`
- boot generation / CPU / WR-core / SI-config drops：`0 / 0 / 0 / 0`
- final Helper error/output：`2675 / 63329`

## 結論

真正 cooldown=0 並沒有改善 Step5，反而比實際 cooldown=8 的 Kp=-150 基準更差：Helper RMS 約由 `1026` 上升至 `2786.85`，Helper 最終 lock count 只有 `203`，並出現 `250` 次 SPLL delock counter peak。這排除了「只要把 cooldown 設為 0 就能解除失鎖」的假說；本輪仍不能宣稱 Step5 PASS。

後續實驗已依使用者要求暫停。Branch 上已保留完整 raw archive 與本報告；尚未詢問 merge，也沒有 merge 到 main。

## 原始資料

- Raw archive：`step5-baseline-cooldown0-raw.tar.gz`
- Raw archive SHA-256：`00312e0a42f47bf356061ef2900f9e5f59c6a28a0f9bd4072b35ca400e2ec100`
- 內容：Pain build logs、build metadata、programming logs、preflight log、3600-sample coherent observer log


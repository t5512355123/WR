# Step5：Slave SoftPLL Closed-loop Lock

本資料夾記錄 `exp/step5-softpll-lock`。基線為 `main@a89b2df`，也就是已經
合併 Step4B 的版本。本輪先完成 source-backed observability 與 fresh-program
baseline；沒有修改 SoftPLL、PI、DCO、SI5340、PTP、WR signaling、PHY 或
任何控制流程。

## 本輪目的

把目前模糊的：

```text
Step 4 SoftPLL Startup = error
Step 5 Closed-loop Lock = NA
```

拆成可定位的狀態：

```text
NEVER_LOCKED
LOCK_ACQUIRED
LOCK_ACQUIRED_THEN_LOST
STABLE_LOCK
```

其中 `LOCK_ACQUIRED` 只代表單一觀測窗看見 source-backed lock，不代表
Step5 PASS；`STABLE_LOCK` 才需要同一張板、同一個 JTAG session 的長時間
連續樣本與零 delock 證據。

## Source-backed Step5 signals

`task-diags.c` 將下列欄位寫入唯讀 WDIAGS shadow，dashboard 只讀取與解碼：

| Shadow | 來源語意 |
|---|---|
| `0x00100ABC` | helper locked、lock_changed、reference source、lock counter |
| `0x00100AC0` | helper threshold、required lock samples |
| `0x00100AC4` | main enabled、main locked、frequency locked、phase locked、兩個 lock counter |
| `0x00100AC8` | main frequency threshold、required lock samples |
| `0x00100ACC` | main phase threshold、required lock samples |
| `0x00100A0C` bit 1 | `PSTAT.locked` 的上層 WR lock 結果 |
| `0x00100AA0` bits 31:24 | SoftPLL `delock_count` |

本輪判定不能以 DAC 數值、單一 counter delta 或單次 `PSTAT.locked` 取代
上述 lock detector 語意。

## 執行順序

1. 在 laptop 建立本 branch、完成 source audit 與唯讀腳本修改並 push。
2. 在 pain 端 pull 同一個 commit，fresh compile Master/Slave、full compile、
   fresh-program 兩張 DE5a。
3. 先跑 `read_wb_runtime.tcl --raw`，確認 Step1–4B upstream gate；再於同一
   JTAG session 跑至少 60 筆、每秒一筆的 `read_wb_timeseries_session.tcl`。
4. 將 build、program、dashboard、timeseries raw evidence 放入本資料夾並
   push；只有實測 evidence 才能更新 Step5 狀態。

## 判定邊界

- Step4B upstream 未通過：Step5 必須是 `NA`/`UPSTREAM_NOT_READY`，不可宣稱
  SoftPLL lock failure。
- helper 未 lock：第一個 inactive boundary 是 `HELPER_LOCK`。
- helper 已 lock、main frequency 未 lock：boundary 是 `MAIN_FREQUENCY_LOCK`。
- main frequency 已 lock、main phase/main locked 未 lock：boundary 是
  `MAIN_PHASE_LOCK`。
- 四個 source-backed lock 與 `PSTAT.locked` 均成立：最多先記為
  `LOCK_ACQUIRED_NOT_STABLE`。
- 長時間窗口內曾成立後又失去任一 lock 或 `delock_count` 增加：
  `LOCK_ACQUIRED_THEN_LOST`。
- 只有在分支5明確審核實驗紀錄、同意 Step5 完成後，才可詢問並執行 merge。


# EXP-S5-EVIDENCE-V2-20260912

## 判定

**Step 5：NOT COMPLETE（未通過）**

本輪是 Astra 建議的 L0 離線證據修復，不是新的硬體燒錄輪。它沒有修改 PI、RTL actuator、startup 或 lock 門檻，也沒有改變 Pain 的狀態。四份既有 raw 重新解析後，沒有任何一份被提升為 Step5 PASS。

使用者目前看到的即時狀態是：

```text
Step 1 PHY / Link       error
Step 2 Endpoint / PTP   NA
Step 3 WR Handshake     NA
Step 4 SoftPLL Startup  error
Step 5 Closed-loop Lock NA
Step 6 Global Time      NA
```

這表示目前不能進行 Step5 鎖定判定；先前某次燒錄後 preflight 的 `Step 1–4B PASS` 只代表那一次 settled hardware window，不代表現在板卡仍處於同一狀態。L0 沒有重新讀取板卡，因此本輪不把這兩個時間點混為同一次結果。

## Astra 診斷與本輪依據

已讀取 `C:\Users\zenbook\我的雲端硬碟\Astra建議\_2.md`。其明確路線是先完成 L0，再做 L1 共用 I2C liveness／完成語意驗證，暫時不要再次掃 PI。這一輪也已向 `@實作WR Astra` 發送目前結果與矛盾狀態；該任務的 API turn 顯示 completed，但沒有可讀的 assistant 文字，因此本報告只採用已存在的建議文件與可重算 raw，不臆造額外診斷。

## 實作內容

- `scripts/analysis/step5_replay.py`：以 key/value 解析 sample，不依賴固定欄位位置；`INVALID` 保留為 unknown。
- measurement、position、full-chain 三種 validity 分開計算。
- `COHERENT`（measurement seqlock）不再被 `FRAME_VALID` 錯誤淘汰；兩者各自統計。
- full-chain 遇到 invalid、時間倒退、generation 改變、過大 gap 或不可證明的新鮮度時，不延長已驗證片段。
- 以 `elapsed_ms` 計時；8／16-bit counter 以相鄰樣本 modulo delta 計算，gap 過大時回報 ambiguous。
- `BAND_200` 與實際 Helper threshold `±2000` 分開；locked bit transition 與 lock counter 增減分開。
- `scripts/tests/test_step5_replay.py`：7 個硬體無關測試全部通過。
- `scripts/experiment/step5_manifest.py`：產生／比對 source、角色、cable、lane、top-level override、控制參數、observer 與 image provenance。

## 四份 raw 重算結果

以下數字均來自本輪 `verdict.json`／`comparison.csv`，不是舊報告抄錄。`FRAME_VALID` 與 `COHERENT` 是不同有效性域；Helper RMS 只使用 coherent measurement 中的有效 Helper error。

| raw／source | Helper Kp / Ki policy | 實際 cooldown | coherent measurements | FRAME_VALID | Helper RMS | max abs | 保守 full-chain 片段 | freshness | Step5 |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| `4fa3f3b` true cooldown=0 revalidation | -150 / -1，每次 update | 0 | 3600 | 3388 | 2786.8456489 | 6513 | 0 ms | unknown | NOT COMPLETE |
| `0f7e030` fractional-Ki | -150 / -1，每 4 次積分 | 8 | 3600 | 2996 | **1051.5916706** | 3677 | 0 ms | unknown | NOT COMPLETE |
| `fd4b2e4` Kp=-175 | -175 / -1 | 8 | 3600 | 3305 | 1746.3914676 | 5963 | 4524 ms | unknown | NOT COMPLETE |
| `17f20ad` accounting-fix baseline | -150 / -1 | 8 | 3600 | 3295 | 1026.1968516 | 5369 | 4532 ms | unknown | NOT COMPLETE |

fractional-Ki 的正確 RMS 是 `1051.5916706`，舊報告的 `10551.5917` 是誤植。最後兩列的幾秒級片段是 host log 在保守 validity 規則下可驗證的取樣片段，不是物理連續鎖定；因現有 sample 沒有 Main producer update sequence，不能把它們宣稱為完整 fresh full-chain。

## Provenance

- 分支：`exp/step5-softpll-lock`
- workspace HEAD：`fb9d963f9fcea3f61a434fa51f92ec29d4b4c5bf`
- 最近硬體 image source：`4fa3f3b2ffbe5f09907d0df4529b985de7e75c5f`
- Master cable：`DE5 [1-11.1]`；Slave cable：`DE5 [1-11.2]`
- lane：既有實驗使用的 `QSFPA lane 2`
- 現行 Slave top-level：bootstrap `3388`、reverse `1`、HPLL code-per-physical-step `64`、DPLL `16`、normal cooldown `0`、plant test `0`、normal tracker `1`
- Helper：Kp `-150`、Ki `-1`、update／integral decimation `1`、threshold `2000`、lock samples `1000`
- Main：Kp `+300`、Ki `+1`、frequency threshold／lock samples／delock floor `50 / 50 / 10`；phase `1200 / 1000 / 100`
- 本輪 manifest 自身已用 comparator 比對，`provenance_ok=true`

原始輸入 SHA-256：

```text
F4626C8AC0C2026D73DDFF99DDC2ABD69F64F5F193A7DD447004FBC7A0216B4D  true cooldown=0 observer log
7203832CF8418FE98D76416991842AEDB638E875E20C663DAC78BDE22322288F  fractional-Ki observer log
0240E15AA66E5BB69881559280FC823651AF40275CFB292863760F352790CD60  Kp=-175 observer log
583B0C67B0E5653A5645BFFE0883A4715A2A77164F54C29AAEF9B174AC9CBFC2  17f20ad raw-observer.tar.gz
```

## 下一步與停止條件

本輪停止在 L0，符合 `Astra建議_2.md` 的「L0 完成後停止，下一回合才進 L1」。下一輪只做離線 DCO 共用 I2C liveness／transaction completion test，拆開 page contract、absolute target 與 liveness；不在同一輪改 arbiter、ACK、PI 或 startup。

若後續回到硬體流程，必須先以同一 source／image manifest 取得 settled Step1–4B PASS；若 upstream gate 仍為 error，保存 `UPSTREAM_BLOCKED` 並停止，不啟動長時間 Step5 observer。只有在 diagnostic smoke 的 freshness、first-loss、per-loop wait、transaction ACK／timeout 與 reset evidence 都有效時，才可依證據選一個功能修改。這些條件尚未達成，因此目前不詢問 merge，也不合併到 main。


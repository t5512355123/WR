# EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916

日期：2026-09-16（Asia/Taipei）
Branch：`exp/step5-softpll-lock`
最終部署來源：`5f55c383c11c2214b44e9649b5bf06bb67ce7c75`

## 結論

本輪 F4J diagnostic verdict：**`PRODUCER_HANDOFF_CONFIRMED`**。
本輪 Step5 verdict：**`NO`**。
本輪 merge：**`NO`**。

這一輪證明 Main 的 producer-side snapshot 確實能把同一個 Main update
中的 frequency/phase branch、signed error、PI input/output、detector 狀態
與 DAC/freeze 狀態，以一致 frame 傳到 WDIAGS。它沒有證明 clock 已鎖定，
也沒有修改任何 PI 或 runtime 控制參數。

## 實驗目的與限制

F4I 已取得 Main frequency/phase handoff 的長時間資料，但資料由
`task-diags.c` 在控制迭代後讀取 live state，不能證明欄位屬於同一個 producer
iteration。F4J 只增加獨立的 Main producer seqlock snapshot 與明確的 WDIAGS
schema，回答：

```text
實際 Main producer update
→ frequency / phase branch
→ 最終 signed PI input
→ phase detector
→ DAC write / freeze
→ WDIAGS publication
```

本輪保持：

- Main：`kp=+300`、`ki=+1`、`freq_prelock_gain_boost=20`
- Helper：`kp=-2250`、`ki=-2`
- candidate：`0/0`
- timeout：`60000 ms`
- 不修改 detector、PI common function、gain/boost/threshold、anti-windup、
  DAC ordering、tag/wrap、gain scheduling、timeout/retry、bootstrap、arbiter、
  mailbox、PHY、reset 或 Master mode
- observer：single reader、JTAG probe 0、read-only、無 control write、無
  Helper PI snapshot、無 debug FIFO drain

## 流程與版本

1. Laptop 完成 F4J firmware/RTL-independent observability 與 host observer，
   離線 6 組測試通過後，push `6c946d5f`。
2. Pain fast-forward pull `6c946d5f`，Master/Slave clean build 成功並燒錄。
3. 第一次 smoke 發現 observer 將 Master 未讀 Helper 誤送入共用 F4G health
   gate，約 11 秒錯誤停止為 `DATA_UNRESOLVED`；該次資料保留在
   `raw/remote/observer-smoke.log`，不列入正式 verdict。
4. Laptop 只修正 host observer 的 Master WR-only health isolation，push
   `5f55c383`。
5. Pain fast-forward pull `5f55c383`，重新 clean build、重新燒錄，再完成
   v2 smoke 與正式 120 秒 capture。

## Build 與燒錄證據

Master/Slave 的 firmware 與 Quartus clean compilation 均回報
`Full Compilation was successful`，兩張板 programming 均回報
`Configuration succeeded`、`Successfully performed operation(s)`、0 errors。

| image | ELF SHA-256 | BIN SHA-256 | MIF SHA-256 | SOF SHA-256 |
|---|---|---|---|---|
| Master `DE5 [1-11.1]` | `735fda963e9e562ec893c05c7801acbcf1f2d0fde1b569fecc5ce340057fec24` | `aaa974cc7f283a084cb55ec4e59646c913088225d6e9de3b82e8a3eae6971b6b` | `51ef27bcb6383f2d5dc1bd363d948d0ae680ea77bdf3f3dab715abc374215f3b` | `047c2f421fe55ad8e2b02347e665dede39b7a047c9eb0eb007841b81e03ae5e8` |
| Slave `DE5 [1-11.2]` | `067d2128057bf838323269a1c7d4a1c934628ccc3ef7124cec67cafcd4a01f35` | `aab097cc2b22873914ef36319630405971bcae7129a77d999b5ae49c1ff3c910` | `0f6b4c7f5d72a72b49d183442039a5206319bc8614ab04d220fecc097c456d87` | `848e6ff87ab6a43369ab62488fdb8c4f889a4a7b9d4c9549193fee4b5af3ad78` |

Quartus timing 仍未 closed，這是 implementation caveat，不是本輪功能判定：

- Master worst setup slack：`-0.047 ns`，`TIMING_CLOSED=NO`
- Slave worst setup slack：`-0.268 ns`，`TIMING_CLOSED=NO`

## Observer 執行

Smoke：

```text
samples=200, gap=100 ms, target=10000 ms, hard=13000 ms, role=f4j
```

v2 smoke 到達 `TARGET_REACHED`，`stop_reason=NONE`。

Formal：

```text
samples=2000, gap=100 ms, target=120000 ms, hard=130000 ms, role=f4j
```

Formal 到達目標時間而非錯誤停止：

```text
session_elapsed_ms = 120375
run_end_reason     = TARGET_REACHED
stop_reason        = NONE
```

## Formal 結果

由 `analysis/formal/verdict.json` 重播原始 log 的結果：

| 項目 | 結果 |
|---|---:|
| raw Main producer rows | 127 |
| valid frame rows | 127 |
| frame errors | 0 |
| publication context mismatches | 0 |
| unique producer updates | 64 |
| unique span | 119683 ms |
| update progress | 63 |
| valid background bins | 12 |
| source-gate PHY rows | 159/159 valid |
| PHY decoder mismatches | 0 |
| Slave WR core valid | 159/159 |
| Master WR background valid | 32/32 |
| Helper state valid/locked | 127/127 |
| cycle stop reason | `NONE` for 127/127 |
| boot generation | 1，觀測期間未變 |
| WR core reset增量 | 0 |
| SI config drop增量 | 0 |
| PSTAT.locked | 0/159 WR rows |

Main producer frame 的 branch 結果如下：

- unique frame 中 phase branch 為 63 筆，frequency branch 為 1 筆；raw
  frame 的 branch 分布為 phase 125、frequency 2。
- phase detector 在 phase branch 上持續被呼叫；raw frame 計數為 125。
- phase in-band 18 筆、phase out-of-band 107 筆（raw frame）。
- producer frame 的 `phase lock after` flag 沒有成立；`PSTAT_LOCKED` 也
  全程為 0。
- producer frame 的 publication epoch 前後一致且為 even；producer epoch
  為 even；magic=`0x4D50344A`、version=`1`、frame words=`30` 全部一致。
- frequency branch 的 `branch_error = -20 * freq_error` 檢查通過；phase
  branch 使用 producer 當下捕獲的 signed error，沒有由 host 重算。

因此，這一輪把問題邊界從「Main producer 是否真的走到 phase path」推進到：

```text
Main producer handoff = 已確認
phase detector call   = 已確認
phase lock            = 尚未成立
PSTAT.locked          = 尚未成立
```

## 正式判定

```text
source_gate_pass      = YES
publication_coherent  = YES
producer_handoff      = YES
diagnostic_pass       = YES
step5_runtime_ready   = YES（只代表觀測前置資料充分）
step5_complete        = NO
step5_pass            = NO
merge_approved        = NO
```

F4J 本身是 diagnostic experiment，不是 Step5 pass gate。由於沒有
`PSTAT.locked=1`、Main phase lock flag 也未成立，不能 merge，也不能宣稱
Step5 已通過。

## 下一步

先保留本輪證據，不自動調 PI。下一輪應以這個正式結果重新審查 phase
acquisition/lock convergence，並維持本輪 observer 的 producer contract；若
需要修改 production control，必須另立明確的單一變因實驗，重新走
Laptop push → Pain pull/build/program → observer → report → push 流程。

## 原始資料與分析

- `raw/remote/observer-formal.log`：120 秒 formal raw capture
- `raw/remote/observer-smoke-v2.log`：修正後 smoke
- `raw/remote/observer-smoke.log`：observer health-isolation bug 的保留證據
- `raw/remote/build/`：兩張板的 build identity、Quartus log、firmware hash
- `raw/remote/program-*-v2.log`：兩張板燒錄結果
- `analysis/formal/verdict.json`：正式 replay verdict
- `analysis/formal/main_producer_unique.csv`：去重後 producer frame
- `source_audit.md`：source/schema/deployment audit

# EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916

日期：2026-09-16（Asia/Taipei）
Branch：`exp/step5-softpll-lock`

## 本輪唯一問題

F4I 已證明既有 Main WDIAGS trace 可以觀察到 frequency/phase domain 的
變化，但它由 `task-diags.c` 在控制迭代完成後讀取 live `softpll.mpll` 欄位，
因此不能證明欄位來自同一個 Main producer iteration。本輪只增加 producer-side
snapshot，回答：

```text
同一個 Main update 中，實際採用的 branch、PI input、phase detector 與 DAC
結果是否真的被完整、相干地交給觀測器？
```

本輪不是 Step5 lock test，也不調整 PI、threshold、timeout、bootstrap、arbiter
或任何 WR control。

## 實際 source path

```text
mpll_update()
  -> valid tag_ref/tag_out pair
  -> freq_error = dout_dt - dref_dt
  -> original frequency/phase if/else
  -> final signed err after existing wrap mask
  -> pi_update(err)
  -> existing DAC write / freeze decision
  -> existing phase detector and gain schedule
  -> producer diagnostic frame commit
       odd source epoch
       barrier
       complete 30-word payload
       barrier
       even source epoch
  -> task-diags bounded source-frame copy
  -> WDIAGS F4J publication epoch
  -> one JTAG reader
```

`struct spll_main_state` 沒有擴充；新 frame 位於獨立的
`softpll/spll_main_diag.h` RAM object。只有 `dac_index == 0` 的 Main frame 會
被記錄。未完成 tag pair、disabled early return 與其他 channel 不會產生假造的
producer record。

## Frame contract

- Source epoch 與 WDIAGS publication epoch 是兩個不同的 seqlock identity。
- WDIAGS overlay 仍使用既有 `0x158..0x1dc` dynamic window，沒有擴充 DPRAM/SDB。
- F4J magic=`0x4D50344A`、version=`1`、frame words=`30`；舊 reader 不得 fallback。
- Frame 直接記錄實際 branch ID、frequency error、final signed PI input、PI output、
  clamp/freeze、frequency lock detector before/after、phase detector
  called/lock-count before/after、累積 branch/detector/band/transition counters。
- Frequency branch 的離線檢查是 `branch_error == -20 * freq_error`；phase branch
  不由 host 以稀疏 tag 重算，只接受 producer 已捕獲的 signed error。
- Task 只 bounded-copy 完成的 RAM frame；不以 live Main state 補欄位，不發出
  Helper PI snapshot request，不開第二 reader。

## Functional-equivalence guard

`mpll_update()` 的 production ordering、branch condition、PI/DAC 呼叫、phase
detector、gain schedule 與 return path 保持原狀。新增的 producer commit 放在
原本 `SPLL_LOCKED` return 前，但 return 仍對所有 channel 維持原本的條件。

離線測試涵蓋 disabled/incomplete pair、frequency/phase handoff、wrapped phase
error、freeze、re-entry、seqlock invalid frame、cross-publication mismatch 與
同一 event trace 的 instrumentation on/off output equality。硬體 build 後仍須
記錄 image/size/timing cost；本輪不宣稱 zero perturbation。

## Deployment and verdict policy

```text
Laptop source audit/offline tests
  -> push exact commit
Pain exact pull, clean Master+Slave build/program
  -> 10 s F4J schema/producer-coherence smoke
  -> smoke pass only: 120 s formal capture (hard limit 130 s)
  -> raw/checksum back to Laptop
  -> report/analyzer verdict, push
```

任何 schema/identity/reset/generation/transport/reader conflict 都立即停止。即使
producer handoff 被確認，本輪 `STEP5_PASS` 仍固定為 `NO`；只有完整 Step5
closed-loop lock criteria 才能將 Step5 判為 PASS。

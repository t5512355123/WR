# EXP-WRPC-STEP4-STAB-MAX-DIAGNOSTIC-20260825

## 實驗狀態

- 實驗名稱：`WAIT_STABLE_0` state-gated `stab_cntr` 最大值唯讀觀測
- 研究分支：`exp/step4-softpll-enable`
- 本次狀態：已完成 source 與 diagnostics 修改，尚未 compile、program 或進行板端量測
- Step 4 判定：尚未判定

## 想驗證什麼

前一輪已確認 native/sample activity 存在，但既有 `WAIT_EDGE_ENTRY`、accept、TAG、TRR、IRQ 與 helper 計數器沒有新增活動。現有 `SPLL_DMTD_STATE` 只有取樣後的 state/bucket，無法回答 functional `stab_cntr` 在 `WAIT_STABLE_0` 中實際累積到多少。

本輪只增加一個觀測問題：

```text
在 WAIT_STABLE_0 狀態內，functional stab_cntr 的歷史最大值是多少？
```

## 唯一修改變因

在 `dmtd_with_deglitcher.vhd` 新增 `dbg_wait_stable0_max_stab_o`：

- 只在 `state = WAIT_STABLE_0` 時，比較並保存現有 functional `stab_cntr` 的最大值
- 計數值只從 DMTD clock domain 同步到 system clock domain
- 不修改 `stab_cntr` 的累加/清除行為
- 不修改 `r_deglitch_threshold_i`
- 不修改 FSM transition、tag、TRR、SoftPLL、servo、DCO、SI5340 或 PHY

`wr_softpll_ng.vhd` 只負責 fan-out REF/FB 觀測值；`spll_wb_slave.vhd` 只增加 read-side alias，原本 write side 保持不變。

## Readback mapping

- `0x00100274[31:16]`：REF `WAIT_STABLE_0` max `stab_cntr`
- `0x00100278[31:18]`：FB max `stab_cntr` 的飽和 14-bit view
- `0x00100278[17:0]`：保留既有 DFR host status 欄位

FB 使用 14-bit 是因為 `0x00100278` 的 bits 16、17 已有既有 DFR host status；`0x3FFF` 表示原始 FB 16-bit max 已達到或超過 `0x4000`。目前 threshold 為 1000，足以判斷是否跨過 qualification 門檻。

## 板端驗證計畫

由 laptop push exact commit 後，pain 才可 checkout 該 commit：

1. Quartus 17 clean firmware/Quartus build。
2. 保存 MIF、QSF、SDC、SOF SHA256 與 programmer output。
3. 雙板 program 後先重跑 Step 1～3 focused regression。
4. 使用 `read_step4_startup_focused.tcl` 讀取 threshold、REF/FB max、`WAIT_EDGE_ENTRY`、accept 與 downstream event。

## 預期判讀

```text
max_stab << threshold
    qualification 從未接近門檻

max_stab 接近 threshold
    qualification 接近完成，但尚未形成 WAIT_EDGE_ENTRY

max_stab >= threshold 且 WAIT_EDGE_ENTRY=0
    需要重新稽核 predicate、state snapshot 與 readout semantics

WAIT_EDGE_ENTRY > 0
    blocker 往 WAIT_EDGE -> GOT_EDGE 或更下游移動
```

本文件只記錄設計變更與驗證計畫；真正的硬體結論必須等 fresh build、program 與 raw JTAG log 完成後另行記錄。

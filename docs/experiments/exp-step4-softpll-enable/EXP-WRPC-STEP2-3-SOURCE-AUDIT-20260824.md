# EXP-WRPC-STEP2-3-SOURCE-AUDIT-20260824

## 1. 審查範圍

- 審查日期：2026-08-24
- 目前 branch：`exp/step4-softpll-enable`
- 目前文件 HEAD：`5faefe5bc374de0fbcf8d48656372c3f65e007c6`
- 已知 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 早期 Step 3 source reference：`b7d262b5321d0d273c36b6aeb6a8fc57d76ea82e`
- 已知 fresh control 回歸成功 reference：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- 本次失敗 fresh image source：`1bcbd379581134b3bd7a6cab2bd8edd02b09490a`

本文件只記錄 source-only audit。沒有修改 functional source，沒有 Quartus compile，也沒有 program FPGA。

## 2. 為什麼要做這次 audit

`1bcbd37` 已完成 fresh firmware build、clean Quartus compile 與雙板 program，但 read-only Step 2/3 regression 失敗：兩板都停在 `WDIAGS_PTP=4 LISTENING`。因此必須先分開：

1. 會改變 WR/PTP/SoftPLL/DMTD 行為的 functional delta。
2. 只增加觀測、register export 或 Tcl 顯示的 read-only delta。

在重新建立 Step 2/3 之前，不允許進入 Step 4 解讀。

## 3. 已知成功 control 與目前 source 的差異

### 3.1 `51864b874...` 到 `7dd298bb...`

這段主要新增 DMTD/SoftPLL read-only observability，例如 sampled transition、accept、native edge、deglitch state 與 register read aliases。對照 top-level `DE5a_wr_master_jtag.vhd`、`DE5a_wr_slave_jtag.vhd`，沒有看到 role switching、PTP role 或 Slave reverse-DMTD generic 的變更。

`7dd298bb` 的 fresh experiment record 顯示：等待 startup transition 後，Master `MODE=2/PTP=6`，Slave `MODE=3/PTP=9`，Foreign Master、parent、`SLAVE_PRESENT`、`LOCK` 與 `LOCK_ENABLE=4` 均通過 focused repeated sampling。

### 3.2 `7dd298bb...` 到 `1bcbd37...`

這段需要分成兩類：

#### A. 可能影響 functional image 的變更

目前 Slave top-level 新增：

```vhdl
g_softpll_reverse_dmtds => true
```

這個 generic 位於 `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd` 的 `xwr_core` instance，會改變 Slave SoftPLL DMTD 方向，因此不是單純 Tcl/UI 變更。此設定在 `b7d262b` 已出現，但在已知 fresh control `7dd298bb` 中未設定；目前 `1bcbd37` 的 fresh regression 失敗，因此它是第一個應做單一變因 A/B 的 source-backed candidate，但尚未證明是 root cause。

#### B. read-only observability / mapping 變更

目前另有：

- firmware-side `wrpc_spll_trr_pop_count` 與 WDIAGS offset `0x00100B54`
- `g_wdiags_num_words` 由 85 擴充為 86
- `spll_wb_slave.vhd` 的若干 read-side diagnostic aliases 重新指向不同 counter
- DMTD diagnostic ports 與 JTAG scripts 的讀取更新

這些變更的設計目的都是觀測，沒有刻意寫入 SoftPLL control；但它們仍會改變 compile 出來的 netlist、BRAM/logic mapping、timing 與 firmware task 的執行負載，所以在沒有 A/B 前不能假設「一定完全不影響啟動」。

## 4. 目前證據如何解讀

`1bcbd37` fresh image：

```text
Step 1 PHY/link                 PASS
Master MODE=2                   PASS
Slave MODE=3                    PASS
Master/Slave PTP                4 LISTENING
MiniNIC/PTP counters            有 activity
RXERR                           delta=0
Step 2                          FAIL / INVALID
Step 3                          FAIL
Step 4                          NOT ALLOWED
```

這表示目前有 CPU、PHY、Endpoint、MiniNIC 與部分 PTP packet activity，但不能得到 Step 2/3 的穩態 role/parent/WR signaling acceptance。這不是單一 JTAG timeout 可以完整解釋的結果。

然而這次沒有以相同 build 流程測試「移除 reverse-DMTD、保留其他內容」的 image，因此目前只能寫成：

```text
REGRESSION CANDIDATE = Slave g_softpll_reverse_dmtds
ROOT CAUSE            = NOT PROVEN
```

## 5. 最小 recovery tree

下一個 recovery experiment 應使用：

1. `51864b874...` 的已知 functional behavior。
2. 保留必要的 JTAG/read-only diagnostics，但不要帶入其他 DMTD/SoftPLL functional experiment。
3. Slave `g_softpll_reverse_dmtds` 回到 control baseline（未設定/false）。
4. 若要保留 `TRR_POP`，只能作為獨立 read-only observability，必須與 functional recovery 分開記錄 provenance。
5. fresh build、fresh SOF、雙板 program 後等待至少 60 秒，再用同一個 focused Step 2/3 script 驗證：

```text
Master: MODE=2, PTP=6
Slave : MODE=3, PTP=9
Slave : FOREIGN/parent/SLAVE_PRESENT/LOCK/LOCK_ENABLE
valid_samples=20/20
invalid_samples=0
counter_decreased=0
```

只有上述 gate 重新通過後，才可以讀 `TRR_POP` 並判讀 Step 4。

## 6. 本輪結論

```text
SOURCE_AUDIT                  = COMPLETE
STEP1_REGRESSION              = PASS
STEP2_REGRESSION              = FAIL / INVALID
STEP3_REGRESSION              = FAIL
STEP4_ALLOWED                 = NO
HARDWARE/FIRMWARE_ROOT_CAUSE = NOT PROVEN
NEXT_CANDIDATE                = Slave reverse-DMTD generic
```

本輪沒有修改、compile、program 或 merge。下一輪若要驗證 recovery candidate，必須先建立獨立 commit，再保存 MIF/SOF hash、programmer output、JTAG raw output 與新的實驗紀錄。

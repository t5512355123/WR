# EXP-WRPC-STEP4-HIGH-ABORT-WB-PROVENANCE-AUDIT-20260826

## 稽核基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-WB-PROVENANCE-AUDIT-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Audited source commit：`d26ae39`（atomic GOT_EDGE 實驗紀錄）
- 稽核類型：source-only、read-only provenance audit
- 本輪依分支2建議：不修改 RTL、不重新編譯、不重新燒錄

## 稽核範圍

本輪只追蹤 `HIGH_QUAL_ABORT` 的 REF/FB readback path，並與新的 atomic GOT_EDGE path 對照：

```text
dmtd_with_deglitcher
  -> dbg_high_qual_abort_count_o
  -> wr_softpll_ng dmtd_ref/fb_high_abort_count
  -> U_WB_SLAVE read-only alias
  -> 0x001002A0 / 0x001002A4
  -> scripts/jtag/read_step4_startup_focused.tcl
```

對照路徑為：

```text
dmtd_with_deglitcher
  -> dbg_atomic_got_edge_entry_count_o
  -> wr_softpll_ng dmtd_ref/fb_atomic_got_edge_entry_count
  -> U_WB_SLAVE read-only alias
  -> 0x001002F0 / 0x001002F4
  -> scripts/jtag/read_step4_startup_focused.tcl
```

## 稽核結果

### 1. DMTD source predicate

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd` 中，既有 `dbg_high_qual_abort_count` 在 `p_deglitch` 的 `GOT_EDGE` 狀態、`clk_sampled = '0'` 且 `stab_cntr /= 0` 的條件下遞增，並經 Gray CDC 後由 `dbg_high_qual_abort_count_o` 輸出。新的 atomic counter 也在同一個 process、同一個 `WAIT_EDGE -> GOT_EDGE` 進入條件下更新，但屬於獨立的 counter 與 readback alias。

### 2. REF/FB wrapper mapping

`wr_softpll_ng.vhd` 的 named port map 確認：

```text
REF dbg_high_qual_abort_count_o -> dmtd_ref_high_abort_count(i)
FB  dbg_high_qual_abort_count_o -> dmtd_fb_high_abort_count(i)
REF atomic output               -> dmtd_ref_atomic_got_edge_entry_count(i)
FB  atomic output               -> dmtd_fb_atomic_got_edge_entry_count(i)
```

REF/FB 沒有對調，也沒有接到 sampled counter、native counter 或 D0 path。外部 DMTD instance 的這些 debug output 仍為 `open`，不會混入內部 REF/FB readback。

### 3. Wishbone decode and alias

`spll_wb_slave.vhd` 的 read-only decode 確認：

```text
0x001002A0 -> diag_dmtd_ref_seen_i
0x001002A4 -> diag_dmtd_fb_seen_i
0x001002F0 -> diag_dmtd_ref_atomic_got_edge_entry_count_i
0x001002F4 -> diag_dmtd_fb_atomic_got_edge_entry_count_i
```

在 `wr_softpll_ng.vhd` 的 `U_WB_SLAVE` named association 中：

```text
diag_dmtd_ref_seen_i -> dmtd_ref_high_abort_count(0)
diag_dmtd_fb_seen_i  -> dmtd_fb_high_abort_count(0)
```

因此 A0/A4 雖然經過名稱為 `diag_dmtd_*_seen_i` 的 32-bit alias，電氣連接實際上仍是 REF/FB `dmtd_*_high_abort_count(0)`。`.wb` 註解、`spll_wbgen2_pkg.vhd` 的介面拓樸與 VHDL decode 一致；A0/A4 是既有 read-side alias，不是另一個 sampled/native/D0 register field。F0/F4 則讀取獨立的 atomic inputs，沒有與 A0/A4 共用資料來源。

### 4. Tcl and documentation mapping

`scripts/jtag/read_step4_startup_focused.tcl` 及 `scripts/jtag/read_event_group` 對應如下：

```text
A0 -> DMTD_REF_HIGH_QUAL_ABORT_COUNT
A4 -> DMTD_FB_HIGH_QUAL_ABORT_COUNT
F0 -> DMTD_REF_ATOMIC_GOT_EDGE_ENTRY
F4 -> DMTD_FB_ATOMIC_GOT_EDGE_ENTRY
```

`softpll_regs.h` 與 `jtag_register_map.md` 也使用相同的位址和 REF/FB 語意。Tcl 的 32-bit modulo readback 處理同時覆蓋 high-abort 與 atomic counter。

## 正式判定

```text
HIGH_ABORT_WB_PROVENANCE = PASS（電氣 mapping 正確）
REF_FB_SWAP              = NOT_FOUND
SAMPLED_NATIVE_D0_ALIAS  = NOT_FOUND
ATOMIC_ALIAS_COLLISION    = NOT_FOUND
IDENTIFIER_NAMING         = MISLEADING（diag_dmtd_*_seen_i 是 high-abort vector alias）
MAPPING_FIX_REQUIRED      = NO
FRESH_BUILD_PROGRAM       = NOT_REQUIRED（本輪無 source/functional change）
ROOT_CAUSE                = NOT_PROVEN
```

`diag_dmtd_ref_seen_i` / `diag_dmtd_fb_seen_i` 的命名是可維護性風險，且容易讓後續 audit 誤以為它們是 scalar event-sticky signal；但目前 named association 已將它們接到正確的 high-abort 32-bit vector。為避免把單純 rename 擴大成新的 RTL 變更，本輪不修改這個 read-only mapping。

本稽核只能證明 address provenance；它不能把先前硬體觀察到的 `HIGH_QUAL_ABORT > 0` 與 `ATOMIC_GOT_EDGE_ENTRY = 0` 解讀成可信的 live event-rate 證據，也不能據此宣稱已找到 `ROOT_CAUSE`。


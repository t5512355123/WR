# EXP-WRPC-STEP4-SAMPLED-TRANSITION-20260823

## 實驗基本資料

- 實驗名稱：Step 4 DMTD sampled transition 與 deglitch accept 邊界唯讀驗證
- 日期：2026-08-23
- Git branch：`exp/step4-softpll-enable`
- Git commit：`67aa10b86951a6352659dddb55c1adba60bbe4a1`
- 實驗目的：確認 DMTD sampler 產生的 `clk_sampled` transition 是否有活動，並將它與 deglitch accepted edge、post-CDC DMTD event、tag/TRR/IRQ/helper activity 分開。
- 唯一變因：把既有 source counter `dbg_sampled_transition_count_o[31:0]` 以兩個 dedicated、read-only Wishbone register 暴露出來。

## 本次明確沒有修改

本次沒有修改 Master/Slave role switching、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或任何功能控制路徑；沒有新增 counter，也沒有寫入任何 runtime Wishbone control register。

新增觀測欄位直接連到既有 source counter：

```text
DMTD_REF_SAMPLED_TRANSITION_COUNT = dbg_sampled_transition_count_o(0)
DMTD_FB_SAMPLED_TRANSITION_COUNT  = dbg_sampled_transition_count_o(1)
```

這些 counter 的 source 更新條件是 `clk_sampled /= clk_sampled_d`，因此只用來回答 sampler output 是否有 transition，不等同於 accepted edge 或 SoftPLL lock。

## Fresh build provenance

pain 在 exact HEAD `67aa10b86951a6352659dddb55c1adba60bbe4a1` 執行 JTAG firmware build 與 Quartus clean compile。Quartus 版本為 `17.0.0 Build 595 04/25/2017 SJ Standard Edition`；兩個 project 均回報 `Full Compilation was successful`。

### Master

- Project：`DE5a_wr_master_jtag`
- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`c52b05da936871439793cc31f80e15772104d24be6020c68c4e7694f259f5535`
- SOF SHA256：`10ec155599dd07c8663d320c46fe5dd0a810207fcd7726e62bd2ffdbf4a0505c`
- Programmer checksum：`0x30A62A4E`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.281 ns`

### Slave

- Project：`DE5a_wr_slave_jtag`
- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`1f6acd6c6faaa8e88344ae04df97a3e657fe10b9554d53dc2bf288851def406d`
- SOF SHA256：`291065527e358b905a7f2188068de7b74f09bfb5daa13b4632433b46a7196a7f`
- Programmer checksum：`0x30A83E9F`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.173 ns`

## 燒錄結果

- Master 使用 `DE5 [1-11.1]`：`Configuration succeeded`，Quartus Programmer 0 errors、0 warnings。
- Slave 使用 `DE5 [1-11.2]`：`Configuration succeeded`，Quartus Programmer 0 errors、0 warnings。
- 燒錄後等待約 30 秒，才執行下列 read-only regression。

Programmer raw logs：

- `raw/program_sampled_count_67aa10b_master_20260823.log`
- `raw/program_sampled_count_67aa10b_slave_20260823.log`

## Step 1～Step 3 regression

### Step 1：PHY / Link

Focused samples 中 Master status low byte 為 `0xFF`；Slave 為 `0xCF` 或 `0xEF`，變化只涉及尚未完成的 timing-valid bit，PHY/link/ready/encoding-error 相關條件仍正常。這次沒有看到 RX encoding error 增加，且兩片 CPU/runtime probe 都有有效資料。

結果：`STEP1_REGRESSION=PASS`

### Step 2：Endpoint / MiniNIC / PTP

`read_step23_register_reliability.tcl 30 500 all` 結果：

- Master 與 Slave 的 MAC、MODE、PTP 都是 30/30 valid，且符合唯一身份與 role。
- Master：`02:00:22:33:44:01`、MODE `2`、PTP `6`。
- Slave：`02:00:22:33:44:02`、MODE `3`、PTP `9`。
- PTP RX/TX 與 MiniNIC TX/RX counters 在 30 samples 中持續增加。
- 兩片 `RXERR` 都是 0 且沒有增加。
- Slave `FOREIGN_META=03000001`，30/30 符合 foreign count `1`、best index `0`。

結果：`STEP2_REGRESSION=PASS`

### Step 3：WR Parent / Signaling Handshake

`read_wr_handshake_focused.tcl 30 500` 的 Slave 結果為：

```text
valid_samples=30
invalid_samples=0
signal_good=30
signal_bad=0
FOREIGN=1/0
parent=1/0/1
RX=0x1001 LOCK
TX=0x1000 SLAVE_PRESENT
LOCK_ENABLE=4
```

focused gate 回報：

```text
STEP2_REGRESSION=PASS
STEP3_REGRESSION=PASS
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
```

`WDIAGS_TEMP` 的 live state 30 次讀到 `WRS_IDLE`，但同一批 sample 持續保留 `LOCK`、`SLAVE_PRESENT`、`LOCK_ENABLE=4` 與 `WRS_S_LOCK` failure evidence。因此本紀錄將它分成「Step 3 handshake PASS」與「進入後續 lock stage 的 timeout / live state inconsistency」，不把單一 live shadow 直接判成 Step 3 功能失敗。

結果：`STEP3_REGRESSION=PASS`，`STATE_EVIDENCE=READ_INCONSISTENT`。

## Step 4 DMTD boundary 結果

執行：

```text
quartus_stp -t scripts/jtag/read_step4_dmtd_boundary.tcl 20 500
```

Tcl 與 Quartus SignalTap II 均正常結束，0 errors、0 warnings。所有 register 都以 read-only mailbox 讀取，沒有讀取 `TRR_R0`，沒有寫入控制 register。

### 20 samples 的 counter delta

以下是 32-bit counter 的 modulo-2^32 delta：

| 板卡 | sampled REF | sampled FB | accept REF | accept FB | DMTD REF event | DMTD FB event |
|---|---:|---:|---:|---:|---:|---:|
| Master | `1768165512` | `1765193057` | `0` | `0` | `0` | `0` |
| Slave | `1765323741` | `1768984581` | `0` | `0` | `0` | `0` |

Raw sampled counter 範例：

```text
Master sampled REF: A4EF95CF -> 0E53A657
Master sampled FB : AB59D5F5 -> 14908B56
Slave  sampled REF: 20E3A2BF -> 8A1C569C
Slave  sampled FB : 325D0CAE -> 9BCD9CB3
```

相對地，兩片的 `ACCEPT_REF/ACCEPT_FB` 在 20 samples 內維持原值；直接的 `DMTD_BOUNDARY_EVENT REF/FB` 也沒有增加。`TAG_PENDING`、`TAG_GRANT`、`TAG_VALID`、`TRR_WRITE` 等 downstream 欄位沒有形成持續 activity。

### Step 4 判讀

source-backed 的判定鏈為：

```text
clk_sampled transition
    -> deglitch stability qualification
    -> new_edge_p_dmtdclk / accept counter
    -> post-CDC DMTD event
    -> tag / TRR / IRQ / helper
```

本次觀測是：

```text
sampled transition delta > 0
accept delta = 0
post-CDC event delta = 0
tag/TRR/IRQ/helper 沒有 sustained activity
```

因此目前第一個已被證據定位的 inactive boundary 是：

```text
clk_sampled -> deglitch stability qualification -> new_edge_p_dmtdclk
```

這可以排除「sampler 完全沒有 transition」與「目前已證明是 CDC 漏 pulse」兩種過度簡化的說法；但仍不能把 deglitch threshold、clock quality、polarity 或 SoftPLL algorithm 說成已證明的 root cause。

Step 4 仍未通過，因為尚未看到 accepted DMTD edge、post-CDC event、tag/TRR/IRQ/helper 的 sustained activity。

結果：`STEP4=NOT_PASS`。

## 科學結論與限制

本次證據支持：

1. Fresh exact HEAD 的 build、program 與 JTAG read-only execution 都成功。
2. Step 2 與 Step 3 的 regression gate 通過，且無效 mailbox sample 沒有混入 focused gate。
3. Sampled transition counter 有 activity，但 accept counter 沒有 activity；第一 inactive boundary 可收斂到 deglitch qualification / accepted-edge generation。
4. Step 4 尚未通過，但目前不能據此宣稱是 hardware/firmware failure，也不能宣稱已找到 SoftPLL 演算法根因。
5. `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT` 必須和 Step 3 handshake evidence 分開保存。

目前分類：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4           = NOT_PASS
STEP4_ALLOWED   = YES  (允許繼續單一變因的 Step 4 read-only 診斷)
```

## 原始證據

- Build：`raw/quartus_jtag_master_compile.log`、`raw/quartus_jtag_slave_compile.log`
- Build provenance：`raw/build_info_jtag_master.txt`、`raw/build_info_jtag_slave.txt`
- Programmer：`raw/program_sampled_count_67aa10b_master_20260823.log`、`raw/program_sampled_count_67aa10b_slave_20260823.log`
- Step 2/3 reliability：`raw/regression_sampled_count_67aa10b_step23_reliability_20260823.log`
- Step 3 focused handshake：`raw/regression_sampled_count_67aa10b_step3_focused_20260823.log`
- Step 4 boundary：`raw/regression_sampled_count_67aa10b_step4_dmtd_boundary_20260823.log`

## Next Step

保留目前 exact HEAD 與 fresh SOF 不變。下一個實驗仍只能是 diagnostic-only、single-variable、read-only；應觀測既有 deglitch FSM 的 current qualification/stability shadow，或使用 source-backed 的現有欄位判斷 `WAIT_STABLE_0 / WAIT_EDGE / GOT_EDGE` 是否真的達到 accepted edge。不要修改 deglitch threshold、DDMTD polarity、reverse/divide-by-2、SoftPLL、WR signaling、PI、lock、DCO、SI5340 或 PHY。

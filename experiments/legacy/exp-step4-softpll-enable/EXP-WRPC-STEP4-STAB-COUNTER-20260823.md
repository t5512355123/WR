# EXP-WRPC-STEP4-STAB-COUNTER-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-STAB-COUNTER-20260823`
- 日期：2026-08-23（台北時間）
- Branch：`exp/step4-softpll-enable`
- Git commit：`8859959bd39c7ddd1a0b50bb609b943c9a89479b`
- 實驗名稱：DMTD deglitch 穩定計數器唯讀觀測
- 目的：在不改變 deglitcher、SoftPLL 或 WR signaling 行為的前提下，觀察 `stab_cntr` 是否能持續通過穩定 qualification。

本次燒錄使用的是上述 exact HEAD 重新 clean build 的 fresh SOF，不是 historical `c88cc05` SOF。

## 本次唯一變更

本輪只新增一個診斷觀測變因：將 reference/feedback `dmtd_with_deglitcher` 內既有的 16-bit `stab_cntr`，經 `gc_sync_register` 同步到 `clk_sys`，再由唯讀 Wishbone register `0x0010023C` 提供讀取。

沒有改變：

- `WAIT_STABLE_0 -> WAIT_EDGE -> GOT_EDGE` FSM
- deglitch threshold
- `new_edge_p_dmtdclk` 或後續 CDC
- tag/TRR/IRQ/helper/servo
- SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold
- DCO、SI5340、PHY、PTP、WR signaling、Master/Slave role

`SPLL_DMTD_STAB_COUNTERS` 的 bits 15..0 為 reference，bits 31..16 為 feedback。這是瞬時值，不是累加 counter；必須和 `DMTD_BOUNDARY_STATE` 及重複取樣一起解讀。

## Build / SOF provenance

Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`

| 項目 | Master | Slave |
|---|---|---|
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| MIF SHA256 | `c52b05da936871439793cc31f80e15772104d24be6020c68c4e7694f259f5535` | `1f6acd6c6faaa8e88344ae04df97a3e657fe10b9554d53dc2bf288851def406d` |
| SOF SHA256 | `55de8760fab87bf70c79acf436dcc909432aab4c5846b292441535d568ae7440` | `24c38c1eea5d7f0328d333fcdee6aba98ef25b3e163223a9f8dd34778d40ad95` |
| programmer checksum | `0x30A80048` | `0x30A78766` |
| programmer cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |
| compile result | Full Compilation was successful | Full Compilation was successful |
| timing | `TIMING_CLOSED=NO`, WNS `-0.179 ns` | `TIMING_CLOSED=NO`, WNS `-0.182 ns` |

兩片均回報：`Configuration succeeded`、`Successfully performed operation(s)`、0 errors、0 warnings。

## 使用的只讀腳本

所有 JTAG 腳本都從 commit `8859959` 執行，沒有寫入 Wishbone control register，也沒有寫入 `DATA_SNAPSHOT`。

1. `read_step23_register_reliability.tcl 30 500 all`
2. `read_wr_handshake_focused.tcl 30 500`
3. `read_step4_dmtd_boundary.tcl 100 200`
4. `read_wb_runtime.tcl`

Quartus SignalTap II 對上述 Tcl 均回報 `Evaluation of Tcl script ... successful`、0 errors、0 warnings。

原始資料：

- `raw/program_8859959_master_20260823.log`
- `raw/program_8859959_slave_20260823.log`
- `raw/build_info_8859959_master_20260823.txt`
- `raw/build_info_8859959_slave_20260823.txt`
- `raw/quartus_8859959_master_compile_20260823.log`
- `raw/quartus_8859959_slave_compile_20260823.log`
- `raw/regression_8859959_step23_20260823.log`
- `raw/regression_8859959_step3_focused_20260823.log`
- `raw/regression_8859959_step4_stab_counter_20260823.log`
- `raw/dashboard_8859959_20260823.log`

## Step 2 / Step 3 regression gate

### Step 2：PASS

`read_step23_register_reliability.tcl`：Master 與 Slave 都是 30/30 valid samples。

- Master：MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`
- Slave：MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`
- 兩板 MiniNIC TX/RX 與 PPSI PTP RX 有 activity
- `RXERR` 30/30 維持 zero
- Slave `FOREIGN_META=03000001`
- Slave `PTP_TX` 在 reliability script 的部分窗口出現 decrease/reset，focused script 重新取樣後仍有正 delta；因此只列為 counter retest，不作 Step 2 failure

結論：Step 2 的 packet-path regression 通過，沒有把 invalid/decreased mailbox sample 當成硬體失敗。

### Step 3：PASS，但 state evidence 不一致

`read_wr_handshake_focused.tcl`：Slave 30/30 valid samples，其中 23 筆同時具備：

- Foreign Master `1/0`
- `parentIsWRnode=1`
- `parentCalibrated=1`
- RX `0x1001 LOCK`
- TX `0x1000 SLAVE_PRESENT`
- `LOCK_ENABLE=4`

另有 7 筆的 current state / message snapshot 不一致，但沒有出現 invalid sample；全窗口的 current state 都是 `WRS_IDLE`，而 `WR_FAILURE_DEBUG` 保留 `WRS_S_LOCK` 失敗資訊。因此這次仍將 Step 3 gate 判定為 PASS，並將後續狀態記為 `STATE_EVIDENCE=READ_INCONSISTENT`、`POST_STEP3_LOCK_STAGE=TIMEOUT`，不把它改寫成 Step 3 FAIL。

## Step 4 DMTD stability 觀測

觀測設定：每片板 100 samples，sample gap 200 ms。

`dmtd_with_deglitcher` state 定義：

- `0 = WAIT_STABLE_0`
- `1 = WAIT_EDGE`
- `2 = GOT_EDGE`

### Master

- 100/100 boundary samples 讀取完成
- state distribution：`(REF=0, FB=2)` 98 次，`(REF=0, FB=0)` 2 次
- `STAB_REF` 主要為 0/1；`STAB_FB` 主要為 0/1
- 少數高值和同一筆 mailbox snapshot 其他欄位同時出現跨欄位錯位，列為 non-atomic/invalid read evidence，不用來宣稱 counter 已接近 threshold

### Slave

- 100/100 boundary samples 讀取完成
- state distribution：`(REF=2, FB=0)` 95 次，`(REF=0, FB=0)` 5 次
- `STAB_REF`、`STAB_FB` 的主要分佈同樣是 0/1
- 少數高值與同一 snapshot 的 `DEGLITCH_THR`、enable/status 欄位一起出現錯位，不能當成真實持續累積值

兩板的 sampled-transition counters 會變化，表示 sampled clock 觀測點有 activity；但在這個窗口沒有形成可以穩定通過 qualification 的 `stab_cntr` 行為，也沒有形成可供下游使用的 sustained DMTD event/tag/TRR/IRQ/helper chain。這把目前觀測邊界收斂到：

```text
clk_sampled transition
    -> stab_cntr qualification / deglitch FSM
    -> new_edge_p_dmtdclk
```

這是第一個未形成持續有效 activity 的已觀測區段，不等同於已證明 PHY、光纖、firmware 或 SoftPLL 演算法是根因。

## Dashboard UI 驗證

新的預設 `read_wb_runtime.tcl` 已實際執行成功。預設輸出為單行：

```text
[pass] WDIAGS_PTP_RX            結果: Δ=3/Δ>0
[info] WDIAGS_PTP_TX            結果: Δ=0/NA
Step 4 error
```

`--raw` 才輸出額外 raw snapshot、regression classification 與 before/after 資訊。`TIMEOUT`、`DECREASED`、invalid mailbox read 不會因數值比較而中止後續 Step，也不會被轉成硬體 FAIL。

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
```

目前證據支持：

1. fresh HEAD 的 PHY、Endpoint、MiniNIC、PPSI/PTP 與 Step 3 parent/signaling gate 可以重現。
2. 取樣 clock 本身有 transition activity。
3. DMTD deglitch stability qualification 沒有產生持續 downstream event。

目前證據不支持：

- 已完成 SoftPLL closed-loop lock
- `PSTAT.locked=1`
- `time_valid=1`
- 已確定是硬體、光纖、CPU/firmware 或 SoftPLL 演算法根因

因此本輪沒有進行 Step 4 functional tuning，也沒有修改 Step 5 的 PI、threshold、DDMTD polarity、DCO 或 SI5340 行為。

## Next Step

先保留這個 diagnostic commit 與所有 raw logs。下一步若要繼續，只能在不改功能的前提下，針對 `stab_cntr` 與 `WAIT_STABLE_0/WAIT_EDGE/GOT_EDGE` 的 accepted-edge 條件增加更精確的 read-only observability；不要直接調 threshold、polarity、FSM 或 SoftPLL 參數。

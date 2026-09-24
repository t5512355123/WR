# EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827

## 實驗目的

依分支 2 在 `b885058` 的 post-fit audit 後給出的單一步驟建議 `MASTER_SAME_SOURCE_DIFFERENT_FIT_SEED_A_B`，固定 Master RTL、Master MIF、Quartus 17.0、constraints 與 diagnostic probes，只把 Quartus fitter seed 從 A=`1` 改成 B=`2`，判斷 first-load raw `q_b` 是否跟著 fitted placement/routing 改變。

本輪唯一 source 變更是 Master QSF 新增：

```text
set_global_assignment -name SEED 2
```

沒有修改 RTL、MIF、SDC、probes、RAM mode、read-during-write 設定或 Slave QSF。

## Build provenance

- branch：`exp/step4-softpll-enable`
- A baseline build/source：`0b3b012df2697e785431a43f8ca77cd5f0f94a14`
- B seed change commit：`956ac6b48a9273a4c102b15abce402bb3ed21476`
- Quartus：`17.0.0 Build 595 Standard Edition`
- device：`10AX115N2F45E1SG`
- Master A fitter seed：`1`
- Master B fitter seed：`2`
- Master RTL VHDL SHA-256：`8d2793f5dcd507421f6dba7b0cb716c0ba1efdf66a64ffc95a5e334598648671`
- Master SDC SHA-256：`921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b`
- Master MIF SHA-256（A/B 相同）：`b035fe65dbf1bead7e278e87872d043f2150030a1eb1068ae737a352886301fd`

A/B SOF、fit/map/sta、generated TDF、M20K set 與 runtime log 的 hash 見 [build_provenance.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/build_provenance.txt) 及 [artifact_sha256.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/artifact_sha256.txt)。

## Post-fit A/B 差異

| 項目 | A：seed 1 | B：seed 2 | 判讀 |
|---|---:|---:|---|
| Fitter initial placement seed | `1` | `2` | 受控唯一變數 |
| SOF SHA-256 | `d94cc19d0bd198b52b818e935df3b82e9df54de6583dc39de0eb39905f7b5102` | `dbbb1dd92b0dec8049229585b8f8bef9a71c3318be92bff711caf57f8b272b6f` | image 不同 |
| Master MIF SHA-256 | `b035fe65dbf1bead7e278e87872d043f2150030a1eb1068ae737a352886301fd` | 相同 | initialization input 固定 |
| generated `altsyncram_vv44.tdf` SHA-256 | `c9f8c9a5723eb50fdaeffeea071edc7090c0f24bed522382346a3ab65edb107a` | 相同 | seed 沒改 generated primitive TDF |
| U_iram M20K count | `96` | `96` | 資源數量相同 |
| U_iram M20K locations common | — | `82/96` 相對 A | placement 有改變 |
| A-only / B-only M20K locations | — | `14 / 14` | 實體 mapping 改變 |
| first reported setup slack | `-0.217 ns` | `-0.213 ns` | timing 仍未 fully constrained |
| first reported hold slack | `0.038 ns` | `0.039 ns` | timing 仍未 fully constrained |

A-only location examples：`M20K_X150_Y16_N0`, `M20K_X150_Y17_N0`, `M20K_X150_Y24_N0`, `M20K_X150_Y44_N0`, `M20K_X176_Y16_N0`。

B-only location examples：`M20K_X150_Y14_N0`, `M20K_X150_Y15_N0`, `M20K_X150_Y26_N0`, `M20K_X176_Y20_N0`, `M20K_X176_Y21_N0`。

完整集合比較與 raw excerpt hash 見 [fit_seed_m20k_diff.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/fit_seed_m20k_diff.txt)。

## Runtime A/B evidence

同一支既有 reader `scripts/jtag/read_cpu_ram_direct_q_b_diag.tcl`，四個組合均 fresh-program 後執行：

| Board | Image | q_b before load | q_b at first load | q_b after load | dm_mem_rdata at load | q_b=dm | reader |
|---|---|---:|---:|---:|---:|---:|---|
| `DE5 [1-11.1]` | A / seed 1 | `0x00000000` | `0x00017956` | `0x00017956` | `0x00017956` | `1` | 0 errors / 0 warnings |
| `DE5 [1-11.1]` | B / seed 2 | `0x00000000` | `0x00017956` | `0x00017956` | `0x00017956` | `1` | 0 errors / 0 warnings |
| `DE5 [1-11.2]` | A / seed 1 | `0x00000000` | `0x00017956` | `0x00017956` | `0x00017956` | `1` | 0 errors / 0 warnings |
| `DE5 [1-11.2]` | B / seed 2 | `0x00000000` | `0x00017956` | `0x00017956` | `0x00017956` | `1` | 0 errors / 0 warnings |

所有 reader 均為 `FIRST_INTERNAL_LOAD_SEEN=1`、`AFTER_LOAD_SEEN=1`、`CAPTURE_STATE=2`、`RESET_ASSERTED_NOW=0`、`CPU_RESET_ACTIVE_NOW=0`。四次 programming 也均成功、0 errors、0 warnings；A checksum=`0x30B32BFA`，B checksum=`0x30B1C0C2`，JTAG ID 均為 `0x02E660DD`。原始摘要見 [runtime_ab_summary.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/runtime_ab_summary.txt)。

本輪最後兩片 DE5 都恢復為 A / baseline image。

## 判讀

1. seed 1→2 確實產生不同 SOF，且 U_iram 的 M20K placement 改變（`82/96` 共用、`14` 顆各自移動）；因此本輪的 fitted physical implementation 變數確實生效。
2. 在 MIF、RTL、SDC、probe 與 generated `altsyncram_vv44.tdf` 不變的條件下，A/B 的 first-load raw `q_b` 在兩片板都維持 `0x00017956`。這一個 alternate seed 沒有重現或消除異常。
3. 因此「`0x17956` 只由這次 seed 造成的 M20K placement/routing 差異決定」的假說被大幅削弱；但單一 alternate seed 不能排除更廣義的 timing-sensitive physical implementation 或其他 fit variation。
4. 結合 `b885058`：Master/Slave primitive 參數已大致一致、MIF/role binding 與 physical mapping 仍是可區分因素；本輪固定 MIF 後結果不變，下一輪可由分支 2 再決定是否集中查 embedded MIF-to-memory mapping、generated alias/decode wiring 或更廣的 physical/timing variation。

`ROOT_CAUSE = NOT_PROVEN`。

## 限制與交接

- 本輪只重新編譯 Master seed-B；沒有重新編譯 Slave，符合「固定 Master source/MIF 只換 seed」的單一 A/B 設計。
- timing report 仍顯示 setup/hold requirements 未 fully constrained；seed A/B 的 slack 變化只能作背景，不可直接當作 q_b root cause。
- 只測試 seed 2 一個 alternate fit，不能宣稱所有 placement/routing 變異都不影響 q_b。
- 依流程，本報告推送後將把結果交給分支 2，等待下一個單一步驟；在新建議前不改 RAM mode、MIF 或加入 workaround。

## 原始證據

- [build_provenance.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/build_provenance.txt)
- [fit_seed_m20k_diff.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/fit_seed_m20k_diff.txt)
- [runtime_ab_summary.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/runtime_ab_summary.txt)
- [artifact_sha256.txt](raw/EXP-WRPC-STEP4-MASTER-SAME-SOURCE-DIFFERENT-FIT-SEED-A-B-20260827/artifact_sha256.txt)


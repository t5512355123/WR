# EXP-WRPC-DIVIDE-ONLY-SOURCE-AUDIT-20260824

## 審計目的

確認下一輪 Step 4 A/B 是否真的只改變 DMTD input divide，而不是重複先前 `g_softpll_reverse_dmtds=true` 的 coupled 變因。

## Control source

- control base：`exp/step4-post-div-edge-observability@48ba8b1`
- Master/Slave top：沒有設定 `g_softpll_reverse_dmtds`，因此使用 source default `false`
- 原始 SoftPLL mapping：`g_divide_input_by_2 => not g_pcs_16bit and not g_softpll_reverse_dmtds`
- DE5A 設定：`g_pcs_16bit=false`，所以 control 的 effective divide 是 `true`

## B source

本分支只增加一個獨立 generic：

```text
top xwr_core
  -> xwr_core.g_softpll_divide_input_by_2
  -> wr_core.g_softpll_divide_input_by_2
  -> xwr_softpll_ng.g_divide_input_by_2
  -> dmtd_with_deglitcher / dmtd_sampler
```

Master 與 Slave top 都明確設定：

```vhdl
g_softpll_reverse_dmtds     => false（保持 default）
g_softpll_divide_input_by_2 => false（唯一 B 變因）
```

`g_reverse_dmtds` 的 source path 沒有修改；`g_pcs_16bit` 仍為 `false`。`wrcore_pkg.vhd` 只同步 component generic declaration，沒有新增功能路徑。

## 不變項

- Master / Slave role 與 firmware MIF
- PTP algorithm、WR signaling algorithm
- SoftPLL algorithm、PI gain、lock threshold
- DDMTD polarity / reverse topology
- DCO、SI5340
- PHY / PCS functional wiring
- Step 4 deglitch threshold

## 驗證順序

1. exact commit fresh firmware build
2. Quartus 17 clean compile Master/Slave
3. 保存 MIF、QSF、SDC、SOF hash 與 programmer checksum
4. program 雙板
5. 先做 20～30 samples Step 1/2/3 barrier
6. barrier 全部 PASS 才做 Step 4 T0/T1

若 Step 2/3 regression，立即停止；不得把 B 的 Step 4 結果解讀成有效證據。

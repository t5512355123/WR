# EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827

## 實驗目的

依分支 2 對 `1250e4f` 的單一步驟建議，補捉 RAM port-B read 的 request 邊緣前後連續 q 值，區分 RAM Q 本身錯誤與 wrapper 取錯 latency：

```text
B_ADDR_REQUEST
B_ADDR_REGISTERED
B_RDEN
B_Q_CYCLE_0
B_Q_CYCLE_1
B_Q_CYCLE_2
```

本輪只加入 read-only sticky capture，不修改 RAM mode、latency、address、byte enable 或資料。`B_Q_CYCLE_0` 是 request 被偵測的同一個 clock edge 取樣到的既有 `dm_mem_rdata`；`B_Q_CYCLE_1/2` 是後續兩個 clock edge 的 q 取樣。`B_ADDR_REGISTERED` 是 wrapper 對直接連到 `U_iram.ab_i` 的 clocked port-B address-register input 所做的一拍 mirror。

目前 `generic_dpram` 的 Altera port map 沒有獨立 `rden_b` port，因此 `B_RDEN=NOT_EXPOSED`；`REQUEST_SEEN=1` 僅表示 wrapper 的 `dm_load` internal-memory request 被觀測到。

## Provenance

- build commit：`568fcbd`
- branch：`exp/step4-softpll-enable`
- build tool：Quartus 17.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- worst setup slack：Master `-0.458 ns`、Slave `-0.167 ns`
- Master fresh program：successful，SOF checksum `0x30AF2BEA`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`
- Slave fresh program：successful，SOF checksum `0x30B324BA`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`

Current MIF 的 pointer storage 仍為：

```text
70c1 : 00017938;
```

## Runtime evidence

兩片各自 fresh program 後，以單板 filter 讀取 probes 11/12/13/14：

| Board | `B_ADDR_REQUEST` | `B_ADDR_REGISTERED` | `B_Q_CYCLE_0` | `B_Q_CYCLE_1` | `B_Q_CYCLE_2` | byte enable | seen flags | expected match |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| Master `DE5 [1-11.1]` | `0x0001C304` | `0x0001C304` | `0x00017956` | `0x00017956` | `0x000A8B93` | `F` | request/q1/q2=`1/1/1` | `1` |
| Slave `DE5 [1-11.2]` | `0x0001C304` | `0x0001C304` | `0x00017938` | `0x00017938` | `0x000A8B93` | `F` | request/q1/q2=`1/1/1` | `1` |

Master 與 Slave 的 request/registered address 完全一致。兩片的 q cycle 2 也一致；差異只在 q cycle 0 與 q cycle 1，Master 都是 `0x00017956`，Slave 都是 expected `0x00017938`。

## 判讀

1. **沒有觀測到 request edge 到 q cycle 1 的 Master-only q transition。** Master 在 q0、q1 都是 `0x00017956`；Slave 在 q0、q1 都是 `0x00017938`。
2. **address/register 對齊仍正常。** 兩片都是 `B_ADDR_REQUEST=B_ADDR_REGISTERED=0x0001C304`，且 expected match=1。
3. **byte enable 與 request/return pipeline control 正常。** 兩片 byte enable 都是 `F`，q1/q2 seen 都是 1；q2 兩片同為 `0x000A8B93`，顯示後續 q pipeline 可對齊。
4. 目前證據更支持：Master 在 port-B request 邊界附近的 q 值本身已是 `0x00017956`，而不是 wrapper 只在某一個錯誤 latency 拍取到 `0x00017956`。但 q0 是 request edge 前的既有 q，不能單獨當成「request 前已讀到該 storage address」的獨立證明；它與 q1 的一致性才是本輪關鍵。
5. 結合 `0c5b7ce` 的 q1 結果，fault boundary 可再收斂到 Master `generic_dpram` port-B 第一拍 q／初始化或 reset/read-during-write behavior；目前不再優先懷疑 CPU address generation 或單純 wrapper return sampling offset。

## 限制與下一步

- `B_ADDR_REGISTERED` 是 wrapper 邊界 mirror，不是 Quartus 內部 altsyncram register net 的獨立 tap。
- `B_RDEN` 在目前 RAM primitive port map 未暴露，不能由本輪結果宣稱 RAM 有或沒有 read-enable gating。
- q0/q1 取樣反映 wrapper `dm_mem_rdata` 在連續 clock edge 的觀測；本輪尚未直接取得 physical BRAM bit-cell、配置載入瞬間或 reset release 瞬間的獨立 port-B snapshot。
- 下一輪應只追 Master/Slave port-B 的 initialization/reset/read-during-write boundary，例如加入不改功能的 reset/config state 與 RAM q 初始序列觀測；不要直接套用 RAM workaround。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/program_slave_fresh.log)
- [`ram_port_b_cycle_alignment_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/ram_port_b_cycle_alignment_master.log)
- [`ram_port_b_cycle_alignment_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-CYCLE-ALIGNMENT-20260827/ram_port_b_cycle_alignment_slave.log)

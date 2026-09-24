# EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827

## 實驗目的

依分支 2 對 `1250e4f` 的單一步驟建議，將觀測點移到 `U_iram` 的 CPU data-port / RAM port-B 邊界，保存第一次 internal load 的：

```text
PORT_B_ADDR_REQUEST
PORT_B_ADDR_REGISTERED
PORT_B_Q_CYCLE_1
PORT_B_Q_CYCLE_2
```

本輪仍是 read-only sticky capture，不修改 RAM mode、latency、address、byte enable 或 return data。`PORT_B_ADDR_REGISTERED` 是 wrapper 內對直接接到 `U_iram.ab_i` 的 clocked port-B address register input 做的一拍 mirror；`generic_dpram` 在本設計使用同一 `clk_sys_i`，且 Altera port-B address register 設為 clocked。`PORT_B_RDEN` 在目前 generic RAM 介面沒有獨立輸出，因此記為 `NOT_EXPOSED`。

## Provenance

- build commit：`bff1190`
- branch：`exp/step4-softpll-enable`
- build tool：Quartus 17.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- worst setup slack：Master `-0.410 ns`、Slave `-0.150 ns`
- Master fresh program：successful，SOF checksum `0x30B32019`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`
- Slave fresh program：successful，SOF checksum `0x30B22E72`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`

Current MIF 仍在 `0x0001C304`（word address `0x70C1`）放置 expected `0x00017938`；兩份 MIF 的該行均為：

```text
70c1 : 00017938;
```

## Runtime evidence

兩片各自 fresh program 後，以單板 filter 讀取 probes 11/12/13：

| Board | request addr | registered addr mirror | q cycle 1 | q cycle 2 | byte enable | seen flags | expected match |
|---|---:|---:|---:|---:|---:|---|---:|
| Master `DE5 [1-11.1]` | `0x0001C304` | `0x0001C304` | `0x00017956` | `0x000A8B93` | `F` | request/q1/q2=`1/1/1` | `1` |
| Slave `DE5 [1-11.2]` | `0x0001C304` | `0x0001C304` | `0x00017938` | `0x000A8B93` | `F` | request/q1/q2=`1/1/1` | `1` |

兩片的 address request 與 clocked registered-address mirror 都一致且正確；q cycle 2 也一致。唯一差異在第一個 port-B q：Master 為 `0x00017956`，Slave 為 expected `0x00017938`。

## 判讀

1. **不是 request address 錯誤。** Master/Slave 都將 `0x0001C304` 送到 port-B address input，且 registered-address mirror 仍是 `0x0001C304`。
2. **不是 byte enable 或未完成讀取。** 兩片 `BYTE_ENABLE=F`，request、q1、q2 都 seen，expected-address match 都是 1。
3. **不是 wrapper 只在 return sampling 時才把資料改錯。** 在同一個 port-B pipeline 的 `Q_CYCLE_1`，Master 已經是 `0x00017956`；Slave 同點是 `0x00017938`。`Q_CYCLE_2` 兩片相同，作為 pipeline control。
4. fault boundary 因此進一步收斂到 Master `generic_dpram` port-B 的第一拍 q／dual-port RAM implementation：可能涉及 port-B 初始化內容、clocked address/q 行為、configuration/reset-time memory state 或 read-during-write interaction。本輪尚未區分其中哪一項。
5. 結合前輪 `1250e4f`：Master CPU data-port 的 effective address 正確，但 `dm_mem_rdata` 與本輪 port-B `Q_CYCLE_1` 都是 `0x00017956`；Slave 全部維持 `0x00017938`。因此可以停止追查 CPU address generation、pointer、parser、CRT 與一般 wrapper address mapping。

## 限制與下一步

- `PORT_B_ADDR_REGISTERED` 是在 wrapper 邊界對 `ab_i` 的 clocked mirror，不是 Quartus 內部 altsyncram register net 的獨立 SignalTap tap；它直接驗證送入該 register 的 address 以及與 `clk_sys_i` 的對齊。
- 目前 `generic_dpram` port 沒有獨立 `rden_b` 訊號，故不能從此 probe 宣稱 RAM 有或沒有額外 read-enable gating。
- 本輪沒有修改 RAM primitive 的 initialization 或 read mode，也沒有更動 `p`、parser、CRT、DMTD、SoftPLL、FSM 或 Step4。
- 下一輪應只做 Master/Slave 的 RAM port-B initialization/reset/read-during-write boundary diagnostic，例如在不改功能的前提下比對 `generic_dpram` 進入 port-B 前後的 reset/config 狀態與第一拍 q；不要直接套用 RAM workaround。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/program_slave_fresh.log)
- [`ram_port_b_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/ram_port_b_master.log)
- [`ram_port_b_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PIPELINE-20260827/ram_port_b_slave.log)

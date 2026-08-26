# EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827

## 實驗目的

依分支 2 對 `03c5f90` 的單一步驟建議，只在第一次 internal port-B load 的同一個 `clk_sys_i` edge 捕捉 `generic_dpram` port-A activity，判斷 Master 的 raw primitive `q_b=0x00017956` 是否伴隨 port-A 同址寫入碰撞。

本輪不修改 RAM mode、latency、reset、資料內容或 arbitration。`0b3b012` 只修正 capture metadata 的 `INTERNAL_LOAD` 旗標接線；port-A、port-B 與 q_b capture 路徑不變。

## Capture 定義

`wrc_urv_wrapper.U_iram` 的 port-A 來源為：

- `aa_i`：`im_addr_muxed(f_log2_size(g_IRAM_SIZE)+1 downto 2)`；capture 保存其 byte-address source `im_addr_muxed`。
- `wea_i`：`ha_im_write`。
- `bwea_i`：固定為 `ha_im_bwea="1111"`。
- `da_i`：`ha_im_wdata`。

port-B 同時保存 `dm_addr` byte-address source 與 `generic_dpram` 內 Altera primitive `q_b` 的 raw fanout `dm_ram_q_b_raw`。capture 條件為第一個 `dm_load='1' and dm_is_wishbone='0'`。

Port A 的 `generic_dpram`/`altsyncram` 介面沒有獨立 read-enable；因此本輪以 `wea_i` 與 `bwea_i` 完整描述 port-A 的寫入側 activity，並保留 port-A address/data 供判讀。

| Probe | 內容 |
|---|---|
| 23 | port-A byte address `[63:32]`、port-A write data `[31:0]` |
| 24 | port-B byte address `[63:32]`、primitive q_b at first load `[31:0]` |
| 25 | bit 0 capture seen、bit 1 port-A write enable、bits 5:2 port-A byte enable、bit 6 same primitive word address、bit 7 internal load、bits 8–9 reset/CPU-reset now |

## Provenance

- code commit：`0b3b012df2697e785431a43f8ca77cd5f0f94a14`
- port-A capture code commit：`c7e6a8a`
- branch：`exp/step4-softpll-enable`
- Quartus build：17.0.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `timing_closed`：`NO`
- Master timing corners：setup/hold `-0.217/0.038 ns`, `-0.641/0.034 ns`, `0.787/-0.501 ns`, `1.419/0.012 ns`
- Slave timing corners：setup/hold `-0.239/0.039 ns`, `-0.654/0.033 ns`, `0.870/-0.492 ns`, `1.408/0.011 ns`
- Master SOF SHA-256：`d94cc19d0bd198b52b818e935df3b82e9df54de6583dc39de0eb39905f7b5102`
- Slave SOF SHA-256：`ed0e3a12cd426ca1b57f610b20e9609d671b8c8a0c0994204b1fd4668312480d`
- Master MIF SHA-256：`b035fe65dbf1bead7e278e87872d043f2150030a1eb1068ae737a352886301fd`
- Slave MIF SHA-256：`85f9cb7b1b4d6fc9c2cf61bf9b0d9e083a600adb8d4ec282ecca4dbea48ece01`
- Master SOF checksum：`0x30B32BFA`
- Slave SOF checksum：`0x30B1E32B`
- 兩片 JTAG ID：`0x02E660DD`
- Master/Slave programming：successful，均為 `0 errors, 0 warnings`
- reader 初次與 repeat：successful，均為 `0 errors, 0 warnings`

完整 provenance 見 [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/build_provenance.txt)。

## Runtime evidence

兩片均在 fresh program 後讀取；每片再重讀一次，結果完全一致。

| Board | PORT_A_ADDR | PORT_A_WE | PORT_A_BWE | PORT_A_WDATA | PORT_B_ADDR | PRIMITIVE_Q_B | same primitive word address | internal load |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | `0x00000040` | `0` | `0xF` | `0x00000000` | `0x0001C304` | `0x00017956` | `0` | `1` |
| Slave `DE5 [1-11.2]` | `0x00000040` | `0` | `0xF` | `0x00000000` | `0x0001C304` | `0x00017938` | `0` | `1` |

Raw reader 輸出：

- [`port_a_activity_master_fixed.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_master_fixed.log)
- [`port_a_activity_slave_fixed.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_slave_fixed.log)
- [`port_a_activity_master_fixed_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_master_fixed_repeat.log)
- [`port_a_activity_slave_fixed_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_slave_fixed_repeat.log)

## 判讀

1. Master/Slave 在 q_b 分歧的同一個 first-load edge，port-A activity 完全一致：byte address 為 `0x00000040`、`wea_i=0`、byte enable 為 `0xF`、write data 為 `0x00000000`。
2. port-B address 兩片都是 target `0x0001C304`，而 port-A 與 port-B 的 primitive word address 比較旗標都是 `0`；因此本輪沒有觀察到 port-A 對 target address 的同址 write collision，也沒有 Master-only 的 port-A write enable 差異。
3. 在相同的 port-A read-side address/activity 與相同的 port-B address 下，Master raw primitive q_b 仍為 `0x00017956`，Slave 為 `0x00017938`。結合 `03c5f90`，錯值仍直接存在於 primitive q_b；結合 `661fd1d` 與 `d2b595a`，錯值也不是 reset/release 前已存在或 previous-address 的合法 MIF data。
4. 因此，最直接的 mixed-port **同址 port-A write / port-B read** 假說在這個 first-load edge 沒有獲得支持；fault boundary 進一步收斂到不依賴同址寫入的 primitive configuration、read-side dual-port interaction、fitted RAM implementation、hidden primitive control/register behavior 或 physical implementation 差異。

## 限制與後續

- capture 是 wrapper clock edge 對 HDL 層級 port-A source signals 的 sticky sample，不是 Quartus fitted netlist 內部獨立的 primitive address/control tap。
- 目前介面沒有獨立 `rden_a` port；本輪不能宣稱已觀察到 primitive 內部所有 read-enable/clock-control 細節。
- port-A 與 port-B address 以 byte-address source 保存，same-address 旗標則比較送入 primitive 的 word-address slice。
- 本輪不應直接改 `read_during_write_mode_mixed_ports`、RAM latency、reset 或加入 workaround；應將結果交給分支 2，等待下一個單一步驟。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/program_slave_fresh.log)
- [`port_a_activity_master_fixed.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_master_fixed.log)
- [`port_a_activity_slave_fixed.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_slave_fixed.log)
- [`port_a_activity_master_fixed_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_master_fixed_repeat.log)
- [`port_a_activity_slave_fixed_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-FIRST-LOAD-PORT-A-ACTIVITY-20260827/port_a_activity_slave_fixed_repeat.log)

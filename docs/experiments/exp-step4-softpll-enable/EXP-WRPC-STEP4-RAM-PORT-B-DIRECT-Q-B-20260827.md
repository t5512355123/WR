# EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827

## 實驗目的

依分支 2 對 `661fd1d` 的單一步驟建議，將觀測點從 `wrc_urv_wrapper.dm_mem_rdata` 往內推到 `generic_dpram` 的 Altera primitive `q_b` 輸出，區分：

1. Altera dual-port RAM primitive / port-B interaction 本身輸出錯值；或
2. primitive 之後的 `generic_dpram` / wrapper return path 造成錯值。

本輪只將 primitive 的 raw `qb` 以額外唯讀輸出扇出到診斷 probes，不修改 RAM mode、latency、address、reset、資料或 arbitration。

## Capture 定義

`vendor/wr-cores/ip_cores/general-cores/modules/genrams/altera/generic_dpram.vhd` 新增 `qb_raw_o`，直接由 primitive 的 `qb` signal 扇出；`qb_o` 與既有 `dm_mem_rdata` 路徑維持不變。

新增 `scripts/jtag/read_cpu_ram_direct_q_b_diag.tcl`，透過 JTAG probes 20–22 保存：

| Probe | 內容 |
|---|---|
| 20 | primitive q_b 的 first-load 前一拍、first-load 當下 |
| 21 | primitive q_b 的 first-load 後一拍、`dm_mem_rdata` first-load 當下 |
| 22 | first-load/after-load seen、primitive/dm equality 與狀態旗標 |

`PRIMITIVE_Q_B_BEFORE_LOAD` 是 raw q_b 的前一個 system-clock sample；`PRIMITIVE_Q_B_AT_LOAD` 與 `DM_MEM_RDATA_AT_LOAD` 都是在偵測第一個 internal `dm_load` 的同一個 clock edge 取樣。

## Provenance

- build commit：`1a1a932`
- branch：`exp/step4-softpll-enable`
- Quartus：17.0.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- worst setup slack：Master `-0.218 ns`、Slave `-0.430 ns`
- worst hold slack：Master `0.038 ns`、Slave `0.037 ns`
- Master SOF SHA-256：`3f4b627be25ba71b1e812f07ef07c1289b4774ae2a1d28e1b63045f80b66b2629`
- Slave SOF SHA-256：`4e6da89f662d8105f24a10e55a267a1d9c97cb58bfd387cb88b439276d77ff92`
- Master SOF checksum：`0x30B02D1F`
- Slave SOF checksum：`0x30B2AE2F`
- 兩片 JTAG ID：`0x02E660DD`
- Master/Slave programming：successful，均為 `0 errors, 0 warnings`
- reader：successful，均為 `0 errors, 0 warnings`

完整 provenance 見 [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/build_provenance.txt)。

## Runtime evidence

兩片各自 fresh program 後，分別使用：

```text
quartus_stp -t scripts/jtag/read_cpu_ram_direct_q_b_diag.tcl 1-11.1
quartus_stp -t scripts/jtag/read_cpu_ram_direct_q_b_diag.tcl 1-11.2
```

| Board | primitive q_b before load | primitive q_b at load | primitive q_b after load | dm_mem_rdata at load | q_b/dm equal |
|---|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | `0x00000000` | `0x00017956` | `0x00017956` | `0x00017956` | `1` |
| Slave `DE5 [1-11.2]` | `0x00000000` | `0x00017938` | `0x00017938` | `0x00017938` | `1` |

兩片狀態旗標均為：

```text
FIRST_INTERNAL_LOAD_SEEN=1
AFTER_LOAD_SEEN=1
CAPTURE_STATE=2
RESET_ASSERTED_NOW=0
CPU_RESET_ACTIVE_NOW=0
```

原始 reader 輸出：

- [`direct_q_b_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/direct_q_b_master.log)
- [`direct_q_b_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/direct_q_b_slave.log)

## 判讀

1. Master 的 raw primitive `q_b` 在 first-load edge 已經是 `0x00017956`，而 Slave 在相同觀測點是 expected `0x00017938`。
2. Master/Slave 各自的 raw primitive q_b 與 `dm_mem_rdata` 在 first-load edge 完全相等，after-load 也維持相同；因此目前沒有證據顯示 wrapper 在 primitive 之後額外改寫或取錯資料。
3. 結合 `661fd1d`：reset/release 前四拍與 first-load 前一拍兩片一致；差異在 first-load edge 的 primitive q_b 才出現。結合 `d2b595a`：target/registered address 都是 `0x0001C304`，且錯值不是 previous-address 的合法 MIF data。
4. fault boundary 現在收斂到 Altera `altsyncram` dual-port RAM 的 first-access/read-during-write/port-A–port-B interaction、primitive configuration/physical implementation，或該邊界實際接收到的 port-A/port-B simultaneous activity。這輪尚未判定其中哪一項。

## 限制與後續

- `qb_raw_o` 是 HDL 層級直接扇出自 `generic_dpram` 內部 `qb`（由 Altera primitive `q_b` 驅動），不是 Quartus netlist 內部不可見節點的獨立 SignalTap tap。
- `PRIMITIVE_Q_B_AT_LOAD` 與 `DM_MEM_RDATA_AT_LOAD` 取樣於同一個 wrapper clock edge；本輪證明兩者相等，但不等於已重建 primitive 內部所有 read-during-write 時序。
- 目前仍沒有獨立 `rden_b`、primitive address-register net 或同時 port-A activity 的 capture。
- 不應根據本輪結果先修改 `read_during_write_mode`、RAM latency、reset 或加入 workaround；應將本輪結果交給分支 2，等待下一個單一步驟。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/program_slave_fresh.log)
- [`direct_q_b_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/direct_q_b_master.log)
- [`direct_q_b_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-DIRECT-Q-B-20260827/direct_q_b_slave.log)

# EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827

## 實驗目的

依分支 2 對 `d2b595a` 的單一步驟建議，確認 Master 的錯值 `0x00017956` 是否在第一次 internal load 之前就已經存在於 RAM port-B q，藉此區分：

1. reset/configuration/initialization 階段已經產生錯值；或
2. 第一次 internal load / port-B interaction 才產生差異。

本輪只加入 read-only capture，不修改 RAM mode、latency、reset 行為、資料內容、`p`、parser、DMTD、SoftPLL 或 Step4。

## Capture 定義

新增 `scripts/jtag/read_cpu_ram_port_b_reset_release_initial_q_diag.tcl`，透過 JTAG probes 15–19 讀取：

| Probe | 內容 |
|---|---|
| 15 | reset 期間最後一拍 q、release cycle 0 q |
| 16 | release cycle 1 q、release cycle 2 q |
| 17 | release cycle 3 q、第一次 internal load 前一拍 q |
| 18 | 第一次 internal load 邊界的 q |
| 19 | reset/release/first-load seen flags 與 release state |

`Q_WHILE_RESET` 是 `rst_n_i='0'` 期間最後一次 system-clock sample；它不是非同步 reset 邊緣的類比瞬時值。`Q_AT_FIRST_INTERNAL_LOAD` 是 wrapper 在偵測到第一個 internal `dm_load` 的同一個 clock edge 所看到的 `dm_mem_rdata`。

## Provenance

- build commit：`7fdeb97`
- branch：`exp/step4-softpll-enable`
- Quartus：17.0.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- worst setup slack：Master `-0.162 ns`、Slave `-0.205 ns`
- worst hold slack：Master `0.031 ns`、Slave `0.040 ns`
- Master SOF checksum：`0x30B230DA`
- Slave SOF checksum：`0x30B257DC`
- 兩片 JTAG ID：`0x02E660DD`
- Master/Slave programming：successful，均為 `0 errors, 0 warnings`
- reader：successful，均為 `0 errors, 0 warnings`

完整 provenance 見 [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/build_provenance.txt)。

## Runtime evidence

兩片各自 fresh program 後，分別使用：

```text
quartus_stp -t scripts/jtag/read_cpu_ram_port_b_reset_release_initial_q_diag.tcl 1-11.1
quartus_stp -t scripts/jtag/read_cpu_ram_port_b_reset_release_initial_q_diag.tcl 1-11.2
```

| Board | Q while reset | release 0 | release 1 | release 2 | release 3 | q before first load | q at first internal load |
|---|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x00000000` | `0x00017956` |
| Slave `DE5 [1-11.2]` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x02C0006F` | `0x00000000` | `0x00017938` |

兩片 flags 完全一致：

```text
RESET_Q_SEEN=1
RESET_RELEASE_SEEN=1
RELEASE_SEQUENCE_COMPLETE=1
FIRST_INTERNAL_LOAD_SEEN=1
RELEASE_STATE=4
RESET_ASSERTED_NOW=0
CPU_RESET_ACTIVE_NOW=0
```

原始 reader 輸出：

- [`reset_release_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/reset_release_master.log)
- [`reset_release_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/reset_release_slave.log)

## 判讀

1. reset 期間與 release 後前四拍，Master/Slave 的 q 完全相同，且都不是 target 的 `0x00017938` 或 Master 的 `0x00017956`。因此本輪不支持「Master 在 reset/config release 後就已經固定成 `0x17956`」的假說。
2. 第一次 internal load 前一拍 q 兩片也相同為 `0x00000000`；直到第一次 internal load 邊界，Master 才觀察到 `0x00017956`，Slave 則觀察到 expected `0x00017938`。
3. 結合 `d2b595a`：兩片 target/registered address 都是 `0x0001C304`，Master 的錯值不是 previous-address 的合法 MIF data；目前 fault boundary 進一步收斂到第一次 port-B load interaction 的 read-during-write、dual-port arbitration、port-B primitive 行為，或 wrapper/RAM q 在該邊界的 timing 差異。
4. 這輪尚未能單獨區分「Altera RAM primitive 真正輸出錯值」與「wrapper 在同一 edge 看到的 q 與 primitive 內部 read timing 不同」；因此不應據此修改 RAM 參數或加入 workaround。

## 限制與後續

- capture 觀察的是 `wrc_urv_wrapper` 的 `dm_mem_rdata`，不是 Quartus `altsyncram` 內部的獨立 `q_b` tap。
- reset q 是最後一個 reset-clock sample；release q 僅取連續四拍。
- 目前 primitive 介面沒有獨立暴露 `rden_b`，所以本輪沒有 `rden` 證據。
- 建議將本輪結果與 raw logs 交給分支 2，等待下一個單一步驟；在取得新建議前不改 RAM mode、latency 或 reset 行為。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/program_slave_fresh.log)
- [`reset_release_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/reset_release_master.log)
- [`reset_release_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-RESET-RELEASE-INITIAL-Q-20260827/reset_release_slave.log)

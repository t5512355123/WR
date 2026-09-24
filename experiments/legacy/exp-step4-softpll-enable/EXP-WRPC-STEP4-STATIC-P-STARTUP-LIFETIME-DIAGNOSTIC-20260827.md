# EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-DIAGNOSTIC-20260827

## 實驗目的

依分支 2 對前一輪 `d68ae19` 的建議，建立 `STATIC_P_STARTUP_LIFETIME_CHECKPOINT_DIAGNOSTIC`。本輪只在 startup 時序讀取 `build_init_readcmd()` 的 static `p`，比較下列六個 checkpoint 的 `p - shell_init_cmd` offset：

1. `P_AT_RESET_EARLY`
2. `P_AFTER_BSS_DATA_INIT`
3. `P_AFTER_BOARD_INIT`
4. `P_AFTER_SHELL_INIT`
5. `P_BEFORE_SHELL_BOOT_SCRIPT`
6. `P_AT_BOOT_SCRIPT_ENTRY`

本輪沒有重設 `p`、修正 parser、修改 DMTD、threshold、reverse、SoftPLL 或 FSM 控制流程。診斷介面只保存相對 offset，不保存 raw pointer。

## Source 與實作

- firmware/build source commit：`e2bb1aac0efe38d1bb270887d66f1f5294f7c0a6`
- evidence commit：`d425150`
- branch：`exp/step4-softpll-enable`
- `build_init_readcmd_p` 改為 file-scope pointer，初始值仍為 `shell_init_cmd`
- parser 的分號分隔、`p += i`、跳過 delimiter，以及 `i == 0` 回到 `shell_init_cmd` 均維持原行為
- `PSTAT/ASTAT` 高位重新作為六個 6-bit offset 與 valid mask；低位 link/locked/AUX 欄位保留
- JTAG reader：`scripts/jtag/read_boot_init_static_p_startup_lifetime_diag.tcl`

## Build 與 program provenance

本輪使用含 Wishbone JTAG mailbox 的 `jtag_runtime_diag` top-level；RS422 top-level 只有 status probe，不能用來讀取 mailbox。

| Item | Master | Slave |
|---|---:|---:|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| Full Quartus compile | successful | successful |
| `TIMING_CLOSED` | `NO` | `NO` |
| worst setup slack | `-0.389 ns` | `-0.412 ns` |
| SOF checksum | `0x30B1722A` | `0x30B05EEB` |
| MIF SHA256 | `0a0539e824f430cda5eeec0dcc4c46a88f87505cc381c3db5eacacc375c04ca8` | `e6036333dd9f1a31f1e6fce5049c59f45b56021b4cc63f491da88b158a6211b5` |
| SOF SHA256 | `ce06052ee79fdab091255f8eb13a50bcbf1f29b431599906dade4b9afe5026f7` | `b8b6693e46f1ed2a4bb5c2459b340e4afa5f7667b39d88315d8bd7012493d525` |

兩端 Programmer 均回報 `Configuration succeeded -- 1 device(s) configured`、`0 errors, 0 warnings`，JTAG ID 均為 `0x02E660DD`。

## Runtime evidence

使用最後一次 program 後的 12-sample read-only JTAG session。兩板所有樣本 `TRACE_VALID=1`、`VALID_MASK=0x3F`，沒有 timeout 或 invalid sample。

| Board | Raw PSTAT | Raw ASTAT | Link | Locked | AUX | 六個 checkpoint offset | 12-sample stability |
|---|---:|---:|---:|---:|---:|---|---:|
| Master `DE5 [1-11.1]` | `79E79E79` | `001FDE00` | 1 | 0 | 0 | `30, 30, 30, 30, 30, 30` | 12/12 |
| Slave `DE5 [1-11.2]` | `00000001` | `001FC000` | 1 | 0 | 0 | `0, 0, 0, 0, 0, 0` | 12/12 |

對應欄位順序為：

```text
P_AT_RESET_EARLY
P_AFTER_BSS_DATA_INIT
P_AFTER_BOARD_INIT
P_AFTER_SHELL_INIT
P_BEFORE_SHELL_BOOT_SCRIPT
P_AT_BOOT_SCRIPT_ENTRY
```

## 判讀

1. Master 在最早可觀測的 C `main()` checkpoint 已經是 offset 30；經過 board init、shell init、shell boot task wrapper 與 `shell_boot_script()` entry，仍固定為 offset 30。
2. Slave 在同一組 checkpoint 全部是 offset 0，且直到 boot script entry 都沒有變化。
3. 因此在本輪 instrumented startup window 內，沒有觀察到 `p: 0 -> 30` 的 transition。前一輪 Master first-call `P_OFFSET_BEFORE=30` 不是由 `wrc_board_init()`、`shell_init()` 或 boot script entry 期間的 transition 造成。
4. 目前最保守的結論是：Master/Slave 的 static `p` 差異已存在於進入 `main()` 時，或更早的 reset/C runtime/data initialization 路徑；本輪尚未證明更早的確切 write site。
5. 這個結果不支持再修改 parser 或 SoftPLL。下一輪應繼續檢查 current build 的 reset/C runtime pointer storage、startup prologue 與 Master/Slave memory image 差異。

## 原始證據

完整 raw evidence 位於：

```text
docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-20260827/
```

其中包含：

- `startup_lifetime_jtag_after_program.log`
- `startup_lifetime_jtag.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `artifact_sha256.txt`
- `program_jtag_master.log`
- `program_jtag_slave.log`


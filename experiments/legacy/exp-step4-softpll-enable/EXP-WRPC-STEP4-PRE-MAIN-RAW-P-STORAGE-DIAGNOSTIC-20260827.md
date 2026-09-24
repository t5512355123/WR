# EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827

## 實驗目的

依分支 2 對 `5469cf2` current-image provenance recheck 的建議，將觀測點移到 `main()` 之前，直接觀察 `build_init_readcmd_p` storage 的 raw 32-bit word。本輪只在 RISC-V `_entry` 的兩個位置讀取 pointer storage，不修改其內容：

1. `P_RAW_AT_RESET_ENTRY`：進入 `_entry` 後、任何 BSS 清除或 data initialization 之前。
2. `P_RAW_AFTER_DATA_INIT`：BSS 清除與可選 `.data` copy 完成後、呼叫 `main()` 之前。

兩個 raw word 由 firmware 寫入固定 `.debug_precrt` 區，再透過 CPU hold + host RAM read 取回。`.debug_precrt` 放在 `_end` 之後，因此第一個樣本不會被 BSS clear 清掉。沒有修改 parser、p reset、DMTD、threshold、reverse、SoftPLL、FSM 或 Step4 行為。

## Provenance

- firmware/build commit：`8f359778bbb2403b215f1e15832ecac3a30db64f`
- firmware/build branch：`exp/step4-softpll-enable`
- reader endian/format correction commit：`7560a52`
- report/evidence commit：本報告提交後建立
- build tool：Quartus 17.0 Build 595
- target top：含 Wishbone JTAG mailbox 的 `DE5a_wr_{master,slave}_jtag`

兩端 full Quartus compile 均成功；`TIMING_CLOSED=NO`，Master worst setup `-0.389 ns`，Slave `-0.412 ns`。兩片配置均成功，JTAG ID 都是 `0x02E660DD`，programmer 均回報 `0 errors, 0 warnings`。

## Current image static-p layout

本次實際 build 的 Master/Slave ELF placement 一致：

| Item | Master | Slave |
|---|---:|---:|
| `_start` | `0x00000000` | `0x00000000` |
| `_entry` | `0x0000002c` | `0x0000002c` |
| `shell_init_cmd` | `0x00017938`, `.rodata` | `0x00017938`, `.rodata` |
| `shell_init_cmd` size | 40 bytes | 39 bytes |
| `build_init_readcmd_p` storage | `0x0001c304`, `.sdata` | `0x0001c304`, `.sdata` |
| `.debug_precrt` | `0x0002e010`..`0x0002e017` | `0x0002e010`..`0x0002e017` |
| MIF word for p storage | `0x70c1 : 00017938` | `0x70c1 : 00017938` |
| `readelf -rW` | no relocations | no relocations |

因此 current image 的預期 pointer raw word 是：

```text
0x00017938
```

## Runtime raw evidence

Reader 先將 CPU hold，再用 CPU host access 讀取 `.debug_precrt` word addresses `0xB804` (`0x2e010`) 與 `0xB805` (`0x2e014`)。`RESET_READS` / `AFTER_DATA_READS` 是 host-endian 表示；`CPU_WORDS` 是經 reader byte-swap 後的 CPU 32-bit raw word。

| Board | Host reset read | CPU reset raw | Host after-data read | CPU after-data raw | Expected | Read result |
|---|---|---:|---|---:|---:|---|
| Master `DE5 [1-11.1]` | `56790100 / 56790100` | `0x00017956` | `56790100 / 56790100` | `0x00017956` | `0x00017938` | `+0x1e` = +30 |
| Slave `DE5 [1-11.2]` | `38790100 / 38790100` | `0x00017938` | `38790100 / 38790100` | `0x00017938` | `0x00017938` | offset 0 |

每個 host read 都重讀兩次，兩次相同；reader 與 SignalTap 執行均成功，無 timeout。

## 判讀

1. Master 在 `_entry` 的最早 raw capture 已經是 `0x00017956`，而 `shell_init_cmd` 是 `0x00017938`，差值 `0x1e = 30`。
2. Master 在 BSS/data initialization 後仍是 `0x00017956`，所以本輪觀測的 `_entry → after-data-init` 區間沒有 `0 → +30` transition。
3. Slave 在兩個 checkpoint 都是 expected `0x00017938`，作為同一套 image/reader 的 control。
4. 結合前一輪 `5469cf2` 已證明 current ELF/MIF initializer 是 `0x00017938`，目前可排除「current ELF/MIF 直接把 pointer 初值編成 +30」以及本輪 CRT data-init 區間發生的 transition。
5. 目前 fault boundary 已推到 `_entry` 之前或 CPU 第一個 data load 所見的 memory path：FPGA RAM/MIF configuration、CPU-visible RAM mapping/address alias、reset release 前後的 memory state，或更早的 reset/initialization interaction。這輪尚未證明確切 write site，也不應直接宣告 CRT bug。

## 原始證據

- [`pre_main_raw_p_storage_jtag_final.log`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/pre_main_raw_p_storage_jtag_final.log)
- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/artifact_sha256.txt)
- [`build_info_jtag_master.txt`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/build_info_jtag_master.txt)
- [`build_info_jtag_slave.txt`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/build_info_jtag_slave.txt)
- [`program_jtag_master.log`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/program_jtag_master.log)
- [`program_jtag_slave.log`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/program_jtag_slave.log)

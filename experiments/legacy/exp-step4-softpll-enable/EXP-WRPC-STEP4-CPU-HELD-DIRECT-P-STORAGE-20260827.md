# EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827

## 實驗目的

依分支 2 對 `365aafe` pre-main raw capture 的建議，直接讀取 current image 中 `build_init_readcmd_p` 的 storage address，不使用 firmware 的 `.debug_precrt` capture。目標是比較：

```text
MIF expected word
    vs.
CPU-held host/JTAG direct RAM read
    vs.
前一輪 CPU 在 _entry 的 load capture
```

本輪只讀一個 address：`build_init_readcmd_p` storage byte address `0x0001c304`，對應 CPU host word address `0x000070c1`。每片都 fresh program 後立即由單板 filter reader assert CPU hold，再讀取 CPU host UDATA 兩次；沒有修改 pointer、parser、CRT、RAM、DMTD、SoftPLL、FSM 或 Step4。

## Provenance

- firmware/build commit：`8f359778bbb2403b215f1e15832ecac3a30db64f`
- firmware/build branch：`exp/step4-softpll-enable`
- direct reader commit：`ae9064c`
- build tool：Quartus 17.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- Master/Slave fresh program：successful，JTAG ID `0x02E660DD`，各 `0 errors, 0 warnings`
- Master SOF checksum：`0x30B1722A`
- Slave SOF checksum：`0x30B05EEB`

## Current image address map

| Item | Master | Slave |
|---|---:|---:|
| `shell_init_cmd` | `0x00017938`, `.rodata` | `0x00017938`, `.rodata` |
| `build_init_readcmd_p` storage | `0x0001c304`, `.sdata` | `0x0001c304`, `.sdata` |
| MIF word for p storage | `0x70c1 : 00017938` | `0x70c1 : 00017938` |
| expected raw pointer word | `0x00017938` | `0x00017938` |

這些 ELF/MIF 結果來自同一個實際編譯 image；前一輪已確認兩份 final ELF 沒有 relocation。

## Direct host evidence

reader 在各片 fresh program 後立即選取單板、送出 CPU hold command（mailbox command response 為 `CPU_HOLD=00000000`），設定 `CPU_UADDR=0x70c1`，並對 `CPU_UDATA` 做兩次讀取。`HOST_READS` 是 host-endian CSR 表示；`DIRECT_STORAGE_CPU_WORD` 是 byte-swap 後的 CPU 32-bit word。

| Board | Host reads | Direct storage CPU word | MIF expected | 兩次 read |
|---|---|---:|---:|---|
| Master `DE5 [1-11.1]` | `38790100 / 38790100` | `0x00017938` | `0x00017938` | 一致 |
| Slave `DE5 [1-11.2]` | `38790100 / 38790100` | `0x00017938` | `0x00017938` | 一致 |

兩片 direct host read 都與 MIF expected 完全相同，reader 執行成功且無 timeout。

## 與 CPU `_entry` capture 的對照

同一 firmware image 在前一輪 `365aafe` 的 pre-main capture 是：

| Board | CPU `_entry` raw load capture | CPU after-data raw load capture |
|---|---:|---:|
| Master | `0x00017956` | `0x00017956` |
| Slave | `0x00017938` | `0x00017938` |

因此 Master 的關鍵三方對照為：

```text
MIF word @ p storage       = 0x00017938
CPU-held host direct read  = 0x00017938
CPU _entry data load       = 0x00017956
```

Slave 三者則都是 `0x00017938`。

## 判讀與限制

1. Master 與 Slave 的 CPU-held host/JTAG direct read 都讀回 MIF 預期值，表示目前 host/IRAM access path 看到的 pointer storage 內容是正確的。
2. Master 在 `_entry` 的 CPU data-side load 卻讀到 `0x00017956`，即 `shell_init_cmd + 30`；Slave data-side load 正常。
3. 這使 fault boundary 從「RAM/MIF initializer 內容錯誤」進一步收斂到 Master 的 CPU-visible data access path：data address mapping/alias、data-port byte lane、CPU load path 或與 reset/dual-port RAM arbitration 相關的差異。
4. direct host read 是經由 CPU hold 時的 instruction/host RAM access path，不是另一顆獨立 RAM；因此它強力支持「host/IRAM path 正確、Master CPU data-side path 異常」，但仍不單獨證明 physical BRAM 每一個 port 的內部內容都相同。
5. 本輪 reader 是在 fresh program 後的第一個可用 JTAG mailbox 流程中 assert CPU hold；它沒有硬體層級的「在 CPU 第一個 instruction 前就已 hold」保證。因此 `DIRECT_STORAGE_CPU_WORD` 應解讀為 CPU hold 時 host path 的直接讀值，不把它過度宣稱成 power-up 瞬間的 RAM snapshot。

目前不應修改 parser、重設 `p` 或碰 Step4。下一輪可依分支 2 的後續建議，單獨追 Master/Slave 的 CPU data-port address/load mapping 或 reset-time RAM port behavior；仍不要同時改功能邏輯。

## 原始證據

- [`direct_p_master.log`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/direct_p_master.log)
- [`direct_p_slave.log`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/direct_p_slave.log)
- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-CPU-HELD-DIRECT-P-STORAGE-20260827/program_slave_fresh.log)
- [`pre_main_raw_p_storage_jtag_final.log`](raw/EXP-WRPC-STEP4-PRE-MAIN-RAW-P-STORAGE-DIAGNOSTIC-20260827/pre_main_raw_p_storage_jtag_final.log)

# EXP-WRPC-STEP4-CURRENT-IMAGE-STATIC-P-ELF-MIF-PROVENANCE-RECHECK-20260827

## 實驗目的

依分支 2 對最新 startup lifetime 結果 `054a1fc` 的建議，重新稽核**實際編譯並燒錄的 `e2bb1aa` Master/Slave image**。上一輪 ELF/MIF provenance audit 查的是舊版 function-static `p`；本輪確認目前 source 改成 file-scope `build_init_readcmd_p` 後，實際 image 中的 pointer storage 與 initializer 是否仍正確。

本輪只回答一個問題：

> current image 的 `build_init_readcmd_p` 在 ELF 與 MIF 中，是否都以 `&shell_init_cmd[0]` 初始化？

沒有修改 firmware、parser、startup、DMTD、threshold、reverse、SoftPLL 或 FSM，也沒有重新燒錄。

## Provenance

- source/build commit：`e2bb1aac0efe38d1bb270887d66f1f5294f7c0a6`
- source/build branch：`exp/step4-softpll-enable`
- remote worktree 當時 HEAD：`d425150`
- current report commit：本報告提交後建立
- 受稽核 artifact：pain `build/firmware/master/wrc.elf`, `wrc.mif` 與 slave 對應檔案
- build info：`raw/EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-20260827/build_info_jtag_master.txt`、`build_info_jtag_slave.txt`

Build info 中的 MIF SHA256 與本輪重算值一致：

| Artifact | Master | Slave |
|---|---|---|
| `wrc.elf` SHA256 | `c6884c846c98b0323c7a42e46c313c92c703a8a99bed5db48b8c023229da0462` | `c30c933907085fe7b60820102c6c307c0704f16d7b5cfe77e398d2e53704a5b7` |
| `wrc.mif` SHA256 | `0a0539e824f430cda5eeec0dcc4c46a88f87505cc381c3db5eacacc375c04ca8` | `e6036333dd9f1a31f1e6fce5049c59f45b56021b4cc63f491da88b158a6211b5` |

## ELF 結果

兩端 symbol placement 相同：

| Item | Master | Slave |
|---|---:|---:|
| `shell_init_cmd` symbol | `0x00017908`, `.rodata` | `0x00017908`, `.rodata` |
| `shell_init_cmd` size | 40 bytes | 39 bytes |
| `build_init_readcmd_p` storage | `0x0001c2d4`, `.sdata` | `0x0001c2d4`, `.sdata` |
| ELF initial word at `p` storage | `0x00017908` | `0x00017908` |
| ELF initial offset from `shell_init_cmd` | 0 | 0 |
| `readelf -rW` | no relocations | no relocations |

`.sdata` 的 bytes `08 79 01 00` 位於 `0x0001c2d4`，以 little-endian 解讀為 `0x00017908`。兩端的 `.rodata` init string 分別是：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave:  vlan off;ptp stop;mode slave;ptp start
```

## MIF 結果

`build_init_readcmd_p` 的 byte address `0x0001c2d4` 除以 4 對應 MIF word address `0x70b5`。兩端實際 MIF 都是：

```text
70b5 : 00017908;
```

因此 current image 的 ELF 與 MIF 都保留：

```text
build_init_readcmd_p = shell_init_cmd + 0
```

沒有看到 compiler/linker initializer、ELF relocation 或 ELF→MIF embedding 將 pointer 改成 `+30`。

## 與 runtime 的邊界判讀

上一輪 `054a1fc` 的實際 runtime 結果是：

| Board | 最早 `main()` checkpoint | 後續五個 checkpoint |
|---|---:|---:|
| Master | 30 | 全部 30 |
| Slave | 0 | 全部 0 |

本輪已確認：

```text
current ELF p = shell_init_cmd + 0
current MIF p = shell_init_cmd + 0
runtime main() Master p = shell_init_cmd + 30
```

因此目前可將 fault boundary 從 build artifact 往後推到：

```text
MIF / image initializer 正確
    ↓
FPGA configuration / CPU reset
    ↓
reset vector、CRT `.data` 初始化、startup prologue、RAM image loading
    ↓
進入 C main() 前或 main() 最早觀測點
    ↓
Master p = shell_init_cmd + 30
```

這仍然**沒有證明**確切的 write site，也不能單憑本輪宣告是 CRT bug；但已排除 current image 的 pointer initializer/layout 造成 `+30`。下一步可依分支 2 建議，單獨檢查 reset vector、CRT/data-copy、startup assembly 與 Master/Slave memory image 差異。

## 原始證據

- [`elf_mif_provenance_recheck.log`](raw/EXP-WRPC-STEP4-CURRENT-IMAGE-STATIC-P-ELF-MIF-PROVENANCE-RECHECK-20260827/elf_mif_provenance_recheck.log)
- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-CURRENT-IMAGE-STATIC-P-ELF-MIF-PROVENANCE-RECHECK-20260827/artifact_sha256.txt)
- [`build_info_jtag_master.txt`](raw/EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-20260827/build_info_jtag_master.txt)
- [`build_info_jtag_slave.txt`](raw/EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-20260827/build_info_jtag_slave.txt)
- [`startup_lifetime_jtag_after_program.log`](raw/EXP-WRPC-STEP4-STATIC-P-STARTUP-LIFETIME-20260827/startup_lifetime_jtag_after_program.log)

# EXP-WRPC-STEP4-STATIC-P-ELF-INITIALIZER-PROVENANCE-AUDIT-20260827

## 實驗目的

依分支 2 對 `523985f` 的建議，本輪不修改 firmware 行為，只比較 Master/Slave build artifact，確認 `static const char *p = shell_init_cmd` 在 ELF 與 MIF 中的初始內容是否已經錯誤。目標是切分 build-time corruption 與 runtime corruption。

## 版本與 artifact

- diagnostic firmware code：`233903e`
- Master/Slave ELF、MIF、SOF 均由 `233903e` 編譯
- raw audit evidence：`0fdbcfa`
- Master build：成功，`timing_closed=NO`；worst setup slack `-0.389 ns`
- Slave build：成功，`timing_closed=NO`；worst setup slack `-0.412 ns`
- Master SOF：`DE5 [1-11.1]`，checksum `0x30B1722A`
- Slave SOF：`DE5 [1-11.2]`，checksum `0x30B05EEB`

## ELF symbol、section 與初始值

兩個 final ELF 的符號與配置完全一致：

| Item | Master | Slave |
|---|---:|---:|
| `shell_init_cmd` address | `0x00017bc8` | `0x00017bc8` |
| `shell_init_cmd` section | `.rodata` | `.rodata` |
| `shell_init_cmd` size | 40 bytes | 39 bytes |
| `p.3055` storage address | `0x0001c3cc` | `0x0001c3cc` |
| `p.3055` section | `.sdata` | `.sdata` |
| initial word at `p.3055` | `0x00017bc8` | `0x00017bc8` |

`p.3055` 的 initial word 正好等於 `shell_init_cmd` 的 base address，即預期的 offset 0，不是 `shell_init_cmd + 30`。final executable 的 `readelf -rW` 結果為 `There are no relocations in this file.`，沒有未解 relocation 留到燒錄階段。

ELF 內的 init string 也完整存在：

```text
Master: vlan off;ptp stop;mode master;ptp start
Slave:  vlan off;ptp stop;mode slave;ptp start
```

## MIF embedding 檢查

`p.3055` 的 byte address `0x1c3cc` 對應 MIF word address `0x70f3`。兩個 MIF 的實際內容都是：

```text
70f3 : 00017BC8;
```

因此 ELF→MIF 的 embedding 沒有把 static pointer 改成 offset 30。MIF 的 artifact hash 如下：

```text
Master MIF SHA256 = 2e93a34bf3a7e0ccf993ef0efa4089f6f0b58a9fd41e493b10148f39c12e83a5
Slave  MIF SHA256 = aa640b21228c0db6447bfa1b196e1102017efc5bce73e5246c074324caf86909c
```

完整原始 audit：

`raw/EXP-WRPC-STEP4-STATIC-P-ELF-INITIALIZER-PROVENANCE-AUDIT-20260827/static_p_elf_initializer_provenance_audit_final.txt`

## 與 runtime evidence 對照

前一輪 first-call runtime evidence 顯示：

```text
Master: GLOBAL_BUILD_INIT_CALL_COUNT=1, PREBOOT_LAST_CALLER=NONE,
        CALL1_P_OFFSET_BEFORE=30, CALL1_RETURN_P_OFFSET_STICKY=39
Slave:  GLOBAL_BUILD_INIT_CALL_COUNT=1, PREBOOT_LAST_CALLER=NONE,
        CALL1_P_OFFSET_BEFORE=0,  CALL1_RETURN_P_OFFSET_STICKY=9
```

也就是 Master 在沒有任何可觀察 preboot `build_init_readcmd()` caller 的情況下，runtime 第一次進入時已經從 offset 30 開始；但相同位置的 ELF/MIF 初始 word 都是 `&shell_init_cmd[0]`。

## 判定

1. Master/Slave final ELF 的 `shell_init_cmd`、`p.3055` storage address、section layout 與 initial pointer value 一致；Master ELF 本身沒有 `p = shell_init_cmd + 30`。
2. Master/Slave MIF 在 `p.3055` 對應的 word 也一致為 `0x00017bc8`；不是 ELF→MIF generation 或 Quartus memory initialization 將 pointer 改壞。
3. 因此目前可排除：

   - compiler/linker 將 static initializer 生成为 `+30`
   - final ELF 的未解 relocation
   - MIF embedding 將 pointer word 改為 `+30`

4. 結合 `PREBOOT_CALL_COUNT=0` 與 runtime `p_offset=30`，錯誤分類已移到：映像載入/啟動完成後、第一次 `build_init_readcmd()` 前的 runtime memory 或 state change。這仍不是完整 root cause proof，不能在本輪宣告是哪一個 startup writer 造成。

## Step 4 判定

`STEP4_ALLOWED=NO` 維持不變。本輪沒有進行 DMTD /2、threshold、reverse、SoftPLL/FSM 或 PTP functional behavior 的修改或解讀。

## 下一步邊界

等待分支 2 讀取本報告與 raw audit 後提出下一個單一實驗；在收到新建議前不加入 `p` reset workaround，也不修改 parser 或 Step 4 功能。

# EXP-WRPC-STEP4-TARGET-WORD-EMBEDDED-INIT-MAPPING-AUDIT-20260827

## 實驗目的

依分支 2 在 `b46ee89`（Master same-source different-fit-seed A/B）之後給出的單一步驟建議 `TARGET_WORD_EMBEDDED_INIT_MAPPING_AUDIT`，追蹤 CPU `U_iram` target word `0x000070C1` 從 MIF、generated `twentynm_ram_block`，到 post-fit embedded initialization bits 的實際內容。

本輪是只讀稽核：不修改 RTL、MIF、RAM mode、read-during-write 設定，不加入 runtime probe，不重新編譯，也不重新燒錄。使用 Quartus EDA Netlist Writer 對既有 Master seed2 與 Slave fit database 產生 functional VHDL netlist，讀取其中的 `mem_init0..7` 與 memory location 標記。

## 分支 2 要求的輸出

```text
LOGICAL_BYTE_ADDR = 0x0001C304
LOGICAL_WORD_ADDR = 0x000070C1

MASTER_MIF_WORD   = 0x00017938
SLAVE_MIF_WORD    = 0x00017938

MASTER_PHYSICAL_M20K = bit0..bit31 對應 32 個 M20K（見下表）
SLAVE_PHYSICAL_M20K  = bit0..bit31 對應 32 個 M20K（見下表）

MASTER_BLOCK_LOCAL_ADDR = 0x000030C1，ram_block1a32..ram_block1a63
SLAVE_BLOCK_LOCAL_ADDR  = 0x000030C1，ram_block1a32..ram_block1a63

MASTER_EMBEDDED_INIT_WORD = 0x00017938
SLAVE_EMBEDDED_INIT_WORD  = 0x00017938
```

這個 32-bit word 不是單獨落在一顆 M20K；Quartus 將它 stripe 成 32 個 1-bit `twentynm_ram_block`。`ram_block1a32..63` 分別承載 logical bit0..31。

## MIF → logical block mapping

Master 與 Slave 的 MIF 在 `0x70C1` 都是 `0x00017938`；相鄰內容也一致：

| MIF word address | Master | Slave |
|---:|---:|---:|
| `0x70BF` | `0xFFFFFFFF` | `0xFFFFFFFF` |
| `0x70C0` | `0xFFFFFFFF` | `0xFFFFFFFF` |
| `0x70C1` | `0x00017938` | `0x00017938` |
| `0x70C2` | `0x000003E8` | `0x000003E8` |
| `0x70C3` | `0x0000FFFF` | `0x0000FFFF` |

`U_iram` 的深度為 49152。由 generated TDF 的 block ranges 可得：

- `ram_block1a32..63` 的 logical range 是 `0x4000..0x7FFF`。
- `0x70C1 - 0x4000 = 0x30C1`，所以每個 target bit 的 block-local address 都是 `0x30C1`。
- `0x30C1 = 6 * 2048 + 193`，因此 target bit 位於每個 block 的 `mem_init6`，offset `193`。
- 以 Quartus VHO 的 MSB-first init string 解碼（string bit position `2047 - 193 = 1854`）後，兩個 image 的 32 個 bit 都組成 `0x00017938`。

## Post-fit physical M20K 與 embedded init

下表中的 `M20K_X...` 是將 EDA VHO 的 `EC_X...` location 標記與 fit RAM summary 的 `M20K_X...` 座標對齊後的名稱。`MEM_INIT6_CHAR` 是 target bit 所在的 VHO init hex character，`TARGET_BIT` 是解出的 logical bit。

### Master（目前 fit：seed2；同一份 MIF，A/B 只改 fitter seed）

| block | logical bit | physical M20K | mem_init6 char | target bit |
|---:|---:|---|---:|---:|
| 32 | 0 | `M20K_X150_Y6_N0` | `9` | 0 |
| 33 | 1 | `M20K_X176_Y38_N0` | `9` | 0 |
| 34 | 2 | `M20K_X194_Y18_N0` | `9` | 0 |
| 35 | 3 | `M20K_X176_Y15_N0` | `F` | 1 |
| 36 | 4 | `M20K_X176_Y22_N0` | `B` | 1 |
| 37 | 5 | `M20K_X150_Y32_N0` | `F` | 1 |
| 38 | 6 | `M20K_X150_Y5_N0` | `D` | 0 |
| 39 | 7 | `M20K_X150_Y28_N0` | `D` | 0 |
| 40 | 8 | `M20K_X150_Y18_N0` | `F` | 1 |
| 41 | 9 | `M20K_X150_Y34_N0` | `D` | 0 |
| 42 | 10 | `M20K_X150_Y13_N0` | `9` | 0 |
| 43 | 11 | `M20K_X176_Y40_N0` | `B` | 1 |
| 44 | 12 | `M20K_X194_Y14_N0` | `B` | 1 |
| 45 | 13 | `M20K_X176_Y12_N0` | `B` | 1 |
| 46 | 14 | `M20K_X150_Y10_N0` | `B` | 1 |
| 47 | 15 | `M20K_X176_Y9_N0` | `9` | 0 |
| 48 | 16 | `M20K_X176_Y4_N0` | `3` | 1 |
| 49 | 17 | `M20K_X150_Y8_N0` | `1` | 0 |
| 50 | 18 | `M20K_X194_Y9_N0` | `1` | 0 |
| 51 | 19 | `M20K_X194_Y24_N0` | `1` | 0 |
| 52 | 20 | `M20K_X176_Y30_N0` | `1` | 0 |
| 53 | 21 | `M20K_X176_Y41_N0` | `1` | 0 |
| 54 | 22 | `M20K_X150_Y42_N0` | `1` | 0 |
| 55 | 23 | `M20K_X150_Y27_N0` | `1` | 0 |
| 56 | 24 | `M20K_X150_Y30_N0` | `1` | 0 |
| 57 | 25 | `M20K_X194_Y5_N0` | `1` | 0 |
| 58 | 26 | `M20K_X194_Y35_N0` | `1` | 0 |
| 59 | 27 | `M20K_X176_Y5_N0` | `1` | 0 |
| 60 | 28 | `M20K_X150_Y19_N0` | `1` | 0 |
| 61 | 29 | `M20K_X150_Y40_N0` | `1` | 0 |
| 62 | 30 | `M20K_X150_Y33_N0` | `1` | 0 |
| 63 | 31 | `M20K_X150_Y12_N0` | `1` | 0 |

`MASTER_EMBEDDED_INIT_WORD = 0x00017938`。

### Slave

| block | logical bit | physical M20K | mem_init6 char | target bit |
|---:|---:|---|---:|---:|
| 32 | 0 | `M20K_X150_Y24_N0` | `9` | 0 |
| 33 | 1 | `M20K_X150_Y38_N0` | `9` | 0 |
| 34 | 2 | `M20K_X176_Y25_N0` | `9` | 0 |
| 35 | 3 | `M20K_X176_Y37_N0` | `F` | 1 |
| 36 | 4 | `M20K_X176_Y14_N0` | `B` | 1 |
| 37 | 5 | `M20K_X150_Y8_N0` | `F` | 1 |
| 38 | 6 | `M20K_X176_Y11_N0` | `D` | 0 |
| 39 | 7 | `M20K_X150_Y16_N0` | `D` | 0 |
| 40 | 8 | `M20K_X176_Y10_N0` | `F` | 1 |
| 41 | 9 | `M20K_X194_Y19_N0` | `D` | 0 |
| 42 | 10 | `M20K_X150_Y11_N0` | `9` | 0 |
| 43 | 11 | `M20K_X176_Y19_N0` | `B` | 1 |
| 44 | 12 | `M20K_X150_Y17_N0` | `B` | 1 |
| 45 | 13 | `M20K_X150_Y39_N0` | `B` | 1 |
| 46 | 14 | `M20K_X206_Y10_N0` | `B` | 1 |
| 47 | 15 | `M20K_X176_Y36_N0` | `9` | 0 |
| 48 | 16 | `M20K_X194_Y17_N0` | `3` | 1 |
| 49 | 17 | `M20K_X194_Y26_N0` | `1` | 0 |
| 50 | 18 | `M20K_X194_Y30_N0` | `1` | 0 |
| 51 | 19 | `M20K_X206_Y22_N0` | `1` | 0 |
| 52 | 20 | `M20K_X150_Y9_N0` | `1` | 0 |
| 53 | 21 | `M20K_X150_Y15_N0` | `1` | 0 |
| 54 | 22 | `M20K_X206_Y11_N0` | `1` | 0 |
| 55 | 23 | `M20K_X176_Y31_N0` | `1` | 0 |
| 56 | 24 | `M20K_X194_Y25_N0` | `1` | 0 |
| 57 | 25 | `M20K_X194_Y8_N0` | `1` | 0 |
| 58 | 26 | `M20K_X176_Y29_N0` | `1` | 0 |
| 59 | 27 | `M20K_X176_Y22_N0` | `1` | 0 |
| 60 | 28 | `M20K_X194_Y28_N0` | `1` | 0 |
| 61 | 29 | `M20K_X150_Y34_N0` | `1` | 0 |
| 62 | 30 | `M20K_X176_Y9_N0` | `1` | 0 |
| 63 | 31 | `M20K_X176_Y8_N0` | `1` | 0 |

`SLAVE_EMBEDDED_INIT_WORD = 0x00017938`。

## 判讀

這一輪抓到分支 2 所指定的結果：Master 與 Slave 的 target word 在 MIF 以及 post-fit embedded init 都是 `0x00017938`。因此，既有 runtime raw `q_b` 差異（Master `0x00017956`、Slave `0x00017938`）不能再由「MIF target word 已被嵌入成不同內容」解釋。

目前 fault boundary 應往 read/decode path 收斂，優先檢查：

1. generated alias/decode 對 block group `ram_block1a32..63` 的選擇與 mux。
2. primitive 內部 Port-B address/control 在 first-load edge 的實際取樣。
3. timing-sensitive memory read/address behavior；目前 fit report 仍有未完全 constrained 的 timing 狀態。

`ROOT_CAUSE = NOT_PROVEN`。本輪排除了「target word 的 embedded initialization content 本身不同」這個具體分支，但尚未唯一定位造成 Master first-load `0x17956` 的 read/decode/timing 機制。

## 重要範圍說明

- EDA VHO 是從目前 Master seed2 fit database 產生；seed1 與 seed2 的 Master `altsyncram_vv44.tdf` hash 相同，MIF 也相同，A/B runtime target word 結果相同，所以這輪的 init-content 結論不依賴 fitter seed。表中的 Master physical M20K 是 seed2 placement。
- 本輪沒有重新編譯或燒錄；沒有改動本地 RTL/MIF。pain 上由 EDA writer 產生的 QSF 輸出設定已撤回，qdb 暫存資料已移出專案目錄。

## 原始證據

- [mif_target_word.txt](raw/EXP-WRPC-STEP4-TARGET-WORD-EMBEDDED-INIT-MAPPING-AUDIT-20260827/mif_target_word.txt)
- [embedded_init_mapping.txt](raw/EXP-WRPC-STEP4-TARGET-WORD-EMBEDDED-INIT-MAPPING-AUDIT-20260827/embedded_init_mapping.txt)
- [build_provenance.txt](raw/EXP-WRPC-STEP4-TARGET-WORD-EMBEDDED-INIT-MAPPING-AUDIT-20260827/build_provenance.txt)
- [artifact_sha256.txt](raw/EXP-WRPC-STEP4-TARGET-WORD-EMBEDDED-INIT-MAPPING-AUDIT-20260827/artifact_sha256.txt)


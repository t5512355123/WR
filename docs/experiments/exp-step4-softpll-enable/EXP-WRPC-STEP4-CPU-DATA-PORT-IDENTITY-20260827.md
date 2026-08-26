# EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827

## 實驗目的

依分支 2 對 `331b17c` 的單一步驟建議，直接在 `wrc_urv_wrapper` 的 CPU data-port 觀測第一次 internal data load：

```text
DATA_ADDR, READ_ENABLE, BYTE_ENABLE, RETURN_DATA
```

本輪只做 read-only sticky capture，不改 address decode、byte enable、return data、pointer、parser、CRT、RAM、DMTD、SoftPLL、FSM 或 Step4 功能。capture 的 address 與 byte enable 在 request 同一拍取樣；因 Altera RAM port B 的 address 是 clocked，return word 在下一拍從 `dm_mem_rdata` 取樣。

## 實作與 provenance

- `wrc_urv_wrapper.vhd` 新增第一次 `dm_load='1' and dm_is_wishbone='0'` 的 sticky capture。
- `wr_core.vhd`、`xwr_core.vhd` 將兩個 64-bit diagnostic payload 傳到 top-level。
- Master/Slave top-level 新增 JTAG source probes：instance 9 為 address/return，instance 10 為 metadata。
- metadata：bits `[3:0]` byte enable、bit 4 request seen、bit 5 return seen、bit 6 expected address match。
- diagnostic RTL/SOF build commit：`be2ada2`。
- reader 顯示修正 commit：`24d5520`。
- Master/Slave full Quartus compile：successful。
- Master/Slave `TIMING_CLOSED`：`NO`；worst setup slack 分別 `-0.175 ns`、`-0.189 ns`。

## Current image expected value

同一 current image 的 pointer storage map 為：

| Item | Master | Slave |
|---|---:|---:|
| `build_init_readcmd_p` storage byte address | `0x0001C304` | `0x0001C304` |
| MIF expected word | `0x00017938` | `0x00017938` |
| expected byte enable for `lw` | `0xF` | `0xF` |

## Runtime evidence

兩片都各自 fresh program 後以單板 filter 讀取 probes。Master 的第一次讀取 raw payload 已保存；其後用修正後 reader 重讀驗證十六進位解碼。結果如下：

| Board | `ADDR_PROBE` | `META_PROBE` | `DATA_ADDR` | `RETURN_DATA` | byte enable | request/return | expected match |
|---|---:|---:|---:|---:|---:|---|---:|
| Master `DE5 [1-11.1]` | `0x000179560001C304` | `0x7F` | `0x0001C304` | `0x00017956` | `F` | `1/1` | `1` |
| Slave `DE5 [1-11.2]` | `0x000179380001C304` | `0x7F` | `0x0001C304` | `0x00017938` | `F` | `1/1` | `1` |

其中 `ADDR_PROBE[31:0]` 是實際送出的 data-port address，`ADDR_PROBE[63:32]` 是下一拍觀測到的 RAM return word。兩片都確認實際 address 是 `0x0001C304`，不是 alias 或 effective-address 偏移；Master 與 Slave 的差異出現在 return data。

## 判讀

1. **address generation/mapping 已排除為主要差異。** Master 與 Slave CPU 對第一次 internal load 都送出正確的 `0x0001C304`，且 `EXPECTED_ADDR_MATCH=1`。
2. **讀取控制也正常。** 兩片都是 `BYTE_ENABLE=F`、request seen=1、return seen=1；不是 byte lane enable 缺失或未完成 read 的假象。
3. **Master data-port return path 確實回傳錯值。** Master 在正確 address 上從 `dm_mem_rdata` 觀測到 `0x00017956`，比 MIF/host direct read 的 `0x00017938` 多 `0x1E`；Slave 在同一 address 回傳 expected `0x00017938`。
4. 因此 fault boundary 從 CPU effective address 生成再收斂到 Master 的 RAM data-port read/return path，候選包含 dual-port RAM port B 的初始化或 reset-time state、RAM read timing/address register、memory implementation/placement，或 `dm_mem_rdata` 前後的資料路徑；本輪尚未區分這些候選。
5. 這個 capture 只觀測 wrapper 內的 `dm_*`/`dm_mem_rdata` 訊號，不改變 CPU 行為；相較前輪 `_entry` capture，它把「CPU request address 正確，但 return data 不同」直接固定下來。

## 限制與下一步

- 第一次 internal load 是依 wrapper 的 `dm_load`/`dm_is_wishbone` 條件 sticky；若未觀測到 request，不能推論 address。這次兩片均 `seen=1`。
- return data 是依目前 wrapper 的 clocked RAM port-B 行為在下一拍取樣；它確認的是 wrapper data-port 所見的 return word，不是獨立於 `generic_dpram` 的第二顆記憶體 snapshot。
- 目前不應修改 `p`、parser、CRT 或 Step4。下一輪應只追查 Master/Slave 的 RAM port-B/reset/初始化或 data return timing 差異。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/program_slave_fresh.log)
- [`cpu_data_port_identity_master_fresh.log`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/cpu_data_port_identity_master_fresh.log)
- [`cpu_data_port_identity_master_fixed_reread.log`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/cpu_data_port_identity_master_fixed_reread.log)
- [`cpu_data_port_identity_slave_fresh.log`](raw/EXP-WRPC-STEP4-CPU-DATA-PORT-IDENTITY-20260827/cpu_data_port_identity_slave_fresh.log)

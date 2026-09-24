# EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827

## 實驗目的

依分支 2 對 `0c5b7ce` 的單一步驟建議，檢查 Master 的 `0x00017956` 是否只是 RAM port-B clocked address pipeline 尚未切換完成、而其實來自 request 前一個 address 的合法資料。針對第一次 target request，保存並比對：

```text
B_ADDR_PREV
B_ADDR_TARGET
B_ADDR_REGISTERED
B_Q_BEFORE_TARGET
B_Q_TARGET_CYCLE1
B_Q_TARGET_CYCLE2
MIF_WORD_AT_PREV_ADDR
```

本輪仍只做 read-only sticky capture 與 reader-side MIF lookup，不修改 RAM latency、RAM mode、address、資料、`p` 或 Step4。

## Provenance

- build commit：`d45bf5d`
- branch：`exp/step4-softpll-enable`
- build tool：Quartus 17.0 Build 595
- Master/Slave full Quartus compile：successful
- Master/Slave `TIMING_CLOSED`：`NO`
- worst setup slack：Master `-0.156 ns`、Slave `-0.143 ns`
- Master fresh program：successful，SOF checksum `0x30B308F4`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`
- Slave fresh program：successful，SOF checksum `0x30B26886`，JTAG ID `0x02E660DD`，`0 errors, 0 warnings`

Current MIF 的 target storage word 仍為：

```text
70c1 : 00017938;
```

## Runtime evidence

兩片各自 fresh program 後，以單板 filter 執行 previous-address correlation reader：

| Board | `B_ADDR_PREV` | `B_ADDR_TARGET` | `B_ADDR_REGISTERED` | `MIF_WORD_AT_PREV_ADDR` | q before target | target q cycle 1 | target q cycle 2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | `0x0001C304` | `0x0001C304` | `0x0001C304` | `0x00017938` | `0x00017956` | `0x00017956` | `0x000A8B93` |
| Slave `DE5 [1-11.2]` | `0x0001C304` | `0x0001C304` | `0x0001C304` | `0x00017938` | `0x00017938` | `0x00017938` | `0x000A8B93` |

兩片 metadata 都是 `BYTE_ENABLE=F`、request/q1/q2 seen=`1/1/1`、expected-address match=`1`；目前 primitive 介面沒有獨立 `rden_b`，所以 `B_RDEN=NOT_EXPOSED`。

## 判讀

1. **previous-address stale-data 假說不成立。** Master 的 `B_ADDR_PREV` 不是另一個 address，而是同一個 `0x0001C304`；reader-side `MIF_WORD_AT_PREV_ADDR` 也是 expected `0x00017938`，不是 `0x00017956`。
2. **Master 的錯值在 request 邊界前後都維持。** Master `B_Q_BEFORE_TARGET` 與 `B_Q_TARGET_CYCLE1` 都是 `0x00017956`；Slave 在同樣的 address、MIF 與 request sequence 下兩者都是 `0x00017938`。
3. **不是 address register 尚未切換到 target。** `B_ADDR_TARGET` 與 `B_ADDR_REGISTERED` 在兩片都為 `0x0001C304`。
4. **不是後續 pipeline 全面錯位。** q cycle 2 兩片相同為 `0x000A8B93`；差異只發生在 target read 附近的第一拍 q。
5. 結合 `0c5b7ce` 與本輪結果，Master `0x00017956` 已不能用「前一個 address 的合法 MIF data」解釋；fault boundary 更集中在 Master `generic_dpram`/Altera port-B 在 target address 上的初始化、reset/configuration state、read-during-write interaction 或 physical RAM implementation。這輪尚未區分這些候選。

## 限制與下一步

- `B_ADDR_PREV` 是 wrapper 對 request edge 前一拍 `ab_i`/port-B address register input 的 mirror；不是 Quartus 內部 altsyncram register net 的獨立 tap。
- `MIF_WORD_AT_PREV_ADDR` 是當前 firmware MIF 的 file-side 對照，不是硬體在 configuration 瞬間的獨立 memory dump。
- q-before-target 仍可能是同一 target address 在 request 前已被 RAM address register 保持的結果；本輪重點是它與 q1 同值且 previous address/MIF 不支持 stale-other-address 解釋。
- 下一輪應只追 Master/Slave 的 RAM port-B initialization/reset/configuration 或 read-during-write boundary；不要套用 RAM workaround。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/build_provenance.txt)
- [`program_master_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/program_master_fresh.log)
- [`program_slave_fresh.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/program_slave_fresh.log)
- [`prev_correlation_master.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/prev_correlation_master.log)
- [`prev_correlation_slave.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-PREV-CORRELATION-20260827/prev_correlation_slave.log)

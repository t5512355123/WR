# EXP-WRPC-QUALIFICATION-ENTRY-20260824

## 1. 實驗識別

- 日期：2026-08-24（台北時間）
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`54839e6937432c24504d35c057a19a3d11ec567c`
- 實驗名稱：DMTD qualification-entry 唯讀邊界觀測
- 目的：在不改變 WR/SoftPLL 功能演算法的前提下，補足 `sampled transition -> qualification entry -> deglitch accept` 之間的第一個可觀測邊界。

## 2. 唯一變因

本次唯一的 functional-tree 變更是把 `dmtd_with_deglitcher` 已存在的
`dbg_wait_edge_entry_count_o`，透過 SoftPLL read-only diagnostic alias 接到
Wishbone `0x001002A0/0x001002A4`：

- `0x001002A0`：reference `WAIT_STABLE_0 -> WAIT_EDGE` entry count
- `0x001002A4`：feedback `WAIT_STABLE_0 -> WAIT_EDGE` entry count

本次沒有修改 `dmtd_with_deglitcher.vhd` 的計數條件；沒有修改 threshold、polarity、deglitch FSM、PTP、WR signaling、SoftPLL algorithm、PI gain、lock threshold、DCO、SI5340 或 PHY。同步更新 Tcl 與 register map，避免把目前 fresh image 的 alias 解碼成歷史 `*_SEEN` 欄位。

## 3. Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`55badc0ab69050917a4fe34693c74c6e09da7daaa13798d737c444e431a6faf1`
- Slave MIF SHA-256：`d13991326a44e3613edaddd08a308b932cbb89dd6f25dd7f10b99cc44c5f58c1`
- Master SOF SHA-256：`873e085d9ebf8ebf63ad87b27d2361057a46d9013f63dddf0e6c4369c7610f97`
- Slave SOF SHA-256：`d527a316e1e66fbb7cf046b0d64cdd990c7f93be262f024b27a4085073fb5639`
- `read_step4_startup_focused.tcl` SHA-256：`2cec1ee5d6c006870bede79646ed581fdb37eb8b43b1efbdafbea9cd3bfee8d7`
- `read_wr_handshake_focused.tcl` SHA-256：`7aabec5aa181d576d0c10e149d0cf64a157ba4d8f383716fc82560500cc581b5`

兩邊均執行 `quartus_sh --clean` 後重新編譯，結果都是 `Full Compilation was successful`、Fitter successful；timing closed 均為 `NO`，Master worst setup slack `-0.166 ns`、Slave `-0.174 ns`，這是本次 build 的 timing caveat，不能寫成 compile failure。

## 4. 燒錄證據

- Master：configuration succeeded，programmer checksum `0x30AEF521`，`0 errors, 0 warnings`。
- Slave 第一次：未完成，因殘留 `quartus_stp` 佔用 JTAG，Quartus 回報 `SLD HUB CLIENT ... is using the target device`。只關閉該殘留唯讀診斷程序，未修改 source 或 FPGA 行為。
- Slave 重試：configuration succeeded，programmer checksum `0x30B2F409`，`0 errors, 0 warnings`。

完整摘要位於：

- `raw/EXP-WRPC-QUALIFICATION-ENTRY-20260824/program_master.log`
- `raw/EXP-WRPC-QUALIFICATION-ENTRY-20260824/program_slave_first_attempt.log`
- `raw/EXP-WRPC-QUALIFICATION-ENTRY-20260824/program_slave_retry.log`

## 5. Step 2 / Step 3 regression

測試指令：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

結果：

| 板卡 | 有效 samples | invalid | counter decreased | Step 2 | Step 3 |
|---|---:|---:|---:|---|---|
| Master `DE5 [1-11.1]` | 20/20 | 0 | 0 | PASS | N/A |
| Slave `DE5 [1-11.2]` | 20/20 | 0 | 0 | PASS | PASS |

重點 evidence：

- Master：MAC `02:00:22:33:44:01`、MODE=2、PTP=6，PTP_TX delta=69。
- Slave：MAC `02:00:22:33:44:02`、MODE=3、PTP=9，PTP_TX delta=8。
- Slave：FOREIGN `1/0`、`parent=1/0/1`、RX WR message `0x1001`、TX WR message `0x1000`、LOCK_ENABLE=4、RXERR=0。
- focused Tcl evaluation successful，沒有 Tcl exception。

## 6. Step 4 qualification boundary

測試指令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500
```

結果摘要：

| 板卡 | sampled delta | qualification-entry delta | accept delta | event/tag/TRR/IRQ/helper | boundary |
|---|---:|---:|---:|---|---|
| Master | REF `653419958`、FB `652556297` | REF `0`、FB `0` | REF `0`、FB `0` | 全為 0 | sampled -> qualification entry |
| Slave | REF `652684323`、FB `650149162` | REF `29487688`、FB `0` | REF `0`、FB `0` | 全為 0 | qualification entry -> accept |

其他觀測：

- Master `SPLL_STATE=0x00020009`、Slave `SPLL_STATE=0x00030009`。
- Slave `RCER=1`、`LOCK_ENABLE=4`，但 `PSTAT.locked=0`；本階段不要求 closed-loop lock。
- Slave qualification-entry counter 有一次 sample decrease flag。依既定判定規則，這只能標示 counter wrap/reset/mailbox snapshot irregularity，不能單獨視為硬體 FAIL；本次以 modulo-32 final delta 與其它 repeated evidence 一起保留。
- Master/Slave raw log 中有部分 DMTD 64-bit/threshold snapshot decrease 或跨 domain 不一致；這些是 measurement caveat，未被拿來宣稱 WR functional failure。

## 7. 結論

- `STEP1_REGRESSION = PASS`：本次 focused runtime 顯示兩端 status/link/CPU/PTP path 健康。
- `STEP2_REGRESSION = PASS`：20 筆 accepted samples 皆有效，兩端 identity、role、PTP activity 與 RXERR evidence 符合。
- `STEP3_REGRESSION = PASS`：Slave repeated samples 看到 Foreign Master、parent flags、`SLAVE_PRESENT`、`LOCK` 與 `LOCK_ENABLE=4`。
- `STEP4_ALLOWED = YES`：Step 1～3 fresh/current hardware regression gate 通過。
- `STEP4_RESULT = NOT_PASS`：新計數器證明 Slave REF 已反覆進入 qualification entry，但兩端 `deglitch accept` delta 都是 0，後續 tag/TRR/IRQ/helper 也沒有活動。

因此目前第一個 source-backed blocker 已由原本的 sampled transition 進一步定位為：

```text
qualification entry -> deglitch accept
```

這是觀測邊界的定位，不是根因。不能據此宣稱 DDMTD polarity、threshold、PHY 或 SoftPLL algorithm 有問題。

## 8. 下一步

先保留本次 fresh SOF 與 raw logs，請 reviewer 根據這次新的
`qualification-entry` evidence 指定下一個單一 read-only observability boundary。
下一輪仍先重跑 Step 2/3 gate，再觀測 accept 前後的 source-backed counter；在沒有明確證據前，不修改 functional algorithm。

## 9. Raw log SHA-256

| 檔案 | SHA-256 |
|---|---|
| `build_info_jtag_master.txt` | `D11FAA1505A9BE336E3DB6386FF22774AAD92DA678C430A56CDE4A23DD8E9EA5` |
| `build_info_jtag_slave.txt` | `BEDE9F686E22516EA6E9A63512CC794028876D263FFA5BB9F8656122D3A99243` |
| `quartus_jtag_master_compile.log` | `AF661752BF8B6DFBB39341ACC46A118145F15383151017DA51199A16A969D606` |
| `quartus_jtag_slave_compile.log` | `BD5A50DB91DD4C34B51A796D3757767112BD9D6716B08BFA5B4CC3A141B8FC4B` |
| `step2_3_focused_20x500.log` | `C5CF58D862FDCA400CAEA3B908459AA1E7951744FF7B4307A37E32A15D12F9B6` |
| `step4_startup_focused_10x500.log` | `6A18CF2D8D11A92DB8005E07D8965A6BEDBBA4965B2D6451C58948F4B534C93B` |


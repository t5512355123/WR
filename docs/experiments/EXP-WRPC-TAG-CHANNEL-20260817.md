# EXP-WRPC-TAG-CHANNEL-20260817：SoftPLL reference/feedback tag 分通道唯讀診斷

## 實驗識別

- 實驗日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/jtag-runtime-observability`
- Git HEAD：`b094621`（`補齊 SoftPLL tag 診斷元件介面`）
- 來源：GitHub `t5512355123/WR`，pain 以明確 commit checkout
- Quartus：17.0.0 Build 595 / 04/25/2017 SJ Standard Edition
- 實驗產物：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/`

## 想驗證什麼

前一輪 reset gate 已排除「SI5340 設定完成前就釋放 WR core reset」作為唯一原因，但 Slave 仍停在 `time_valid=0`、SoftPLL lock 未成立。本輪想把 SoftPLL 的 DMTD tag 診斷拆成兩個輸入通道，確認 reference channel 與 feedback channel 是否真的產生 tag strobe；只讀觀測，不改變 WR servo、PHY、PTP、SI5340 或 PPS 控制。

## 相較 baseline 唯一修改

相較 reset-gate baseline，本輪只增加 SoftPLL 內部的唯讀計數器與 Wishbone 讀取位址：

- `0x00100290`：`tags_p(0)` reference tag count
- `0x00100294`：`tags_p(1)` feedback tag count
- 保留既有 aggregate tag、tag-valid、TRR-write 計數器
- `40a322c` 加入 RTL、register map 與 JTAG script；`b094621` 補齊同一元件在 `wr_softpll_ng.vhd` 的 component declaration，讓編譯介面一致

本輪沒有修改 QSFP lane、RX polarity、pre-emphasis、PHY、PTP filter、servo 演算法、SI5340 設定或 `WDIAGS_CTRL`。

## Master/Slave MIF、SOF、設定 hash

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | `42bdd5253ec88fbe1318d2be94585a820b614f3c8748ef6a993b967d3f87201d` | `47782da9fed86594097ddfdb08e2ac22d9ef66bca5e772a59c37c38d308fbaec` |
| SOF SHA256 | `95fb3ee64dd9a578ded328025d1dbdebaca79be23fd24efa6503f26c5427a5b6` | `8a4120f2236f904b6b22f0c30cb44ef8e2187461e0435a385692f9094b7e6d79` |
| Programmer checksum | `0x30A9E5AB` | `0x30A418A5` |
| QSF SHA256 | `e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b` | `199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |

Quartus build 顯示兩邊 Fitter successful、`Full Compilation was successful`，但 `TIMING_CLOSED=NO`：Master worst setup `-2.879 ns`、recovery `-1.929 ns`；Slave worst setup `-2.753 ns`、recovery `-2.848 ns`，並仍有 unconstrained clocks/paths。因此本 SOF 是診斷用，不是 timing closure 完成版。

## 燒錄結果

- Master 使用 cable `DE5 [1-11.1]`，device `10AX115N2F45@1`，configuration succeeded，0 errors/0 warnings。
- Slave 使用 cable `DE5 [1-11.2]`，device `10AX115N2F45@1`，configuration succeeded，0 errors/0 warnings。
- 原始 programmer output：`program_master.log`、`program_slave.log`。

## JTAG/runtime 原始結果

### Master：`DE5 [1-11.1]`

- `status_probe` low 16-bit：`0x82FF`；`tm_link_up=1`、`link_ok=1`、`time_valid=1`、`pps_valid=1`、PHY ready、RX/TX ready。
- CPU PC 持續變化，`fault=0`，marker `0xB004`，PTP `RX=0x36`、`TX=0x6E`。
- `WDIAGS_MODE=2`、`WDIAGS_PTP=6`、`WDIAGS_SSTAT=0x00000000`、`WDIAGS_PSTAT=0x00000001`。
- `PPS_ESCR=0x0000000C`。

### Slave：`DE5 [1-11.2]`

- `status_probe` low 16-bit：`0x82EF`；`tm_link_up=1`、`link_ok=1`、`time_valid=0`、`pps_valid=1`、PHY ready、RX/TX ready。
- CPU PC 持續變化，`fault=0`，marker `0xB004`，PTP `RX=0x6E`、`TX=0x30`。
- `WDIAGS_MODE=3`、`WDIAGS_PTP=8`、`WDIAGS_SSTAT=0x00000101`、`WDIAGS_PSTAT=0x00000001`。
- `WDIAGS_FOREIGN_META=0x03000001`、`WDIAGS_PARSE_META=0x05010D55`，表示 Slave 已看到 foreign master/parent metadata。
- `PPS_ESCR=0x00000000`。

### 分通道 tag 診斷

`read_spll_diag_raw.tcl 1000` 在同一 JTAG session 內讀取 BEGIN/END：

```text
Master BEGIN: RCER=00000000 OCER=00000001 TRR_CSR=00020000
        TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=0176D1FE
        REF=00D13E12 FEEDBACK=00C977DA
Master END:   RCER=00000000 OCER=00000001 TRR_CSR=00020000
        TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=00000000
        REF=00D13E12 FEEDBACK=00C977DA

Slave BEGIN:  RCER=00000001 OCER=00000001 TRR_CSR=00000001
        TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=114341A3
        REF=0912BBDC FEEDBACK=09A542C6
Slave END:    RCER=00000001 OCER=00000001 TRR_CSR=00020000
        TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=114341A3
        REF=0912BBDC FEEDBACK=09A542C6
```

## Observation

1. 本輪新增的 reference/feedback counters 可以透過 JTAG register 讀到非零值；這表示兩個 counter 曾經累積過事件，不能再簡單說「兩個 tag channel 從未有活動」。
2. 但是 BEGIN/END 間隔 1 秒時，兩個 channel count 沒有增加，`TAG_VALID`、`TRR_WRITE` 也沒有增加。現有證據較像啟動期間曾有事件，之後沒有持續形成可交給 SoftPLL 的有效 tag stream；仍需注意 mailbox/register sampling 的非原子性，不能只靠單一讀值下根因結論。
3. Master 已維持 `time_valid=1`、`pps_valid=1`；Slave 仍是 `time_valid=0`，`PSTAT.locked=0`，所以兩板同步尚未完成。
4. CPU fault=0、marker 與 PTP RX/TX 活動持續，支持 CPU、firmware 與 PTP packet path 仍在執行；本輪沒有證據支持 CPU boot failure 或 PHY/link 完全中斷。

## Conclusion

本輪只支持以下保守結論：**新增的 per-channel tag counters 已成功編譯、燒錄並可讀取；Slave 仍沒有可證明的 SoftPLL lock 或 `time_valid=1`。** 目前問題仍優先落在 Slave 的 WR servo/SoftPLL-to-time-valid path。非零 counter 不能證明 tag stream 在實驗期間持續有效，也不能單獨證明根因是 DMTD clock、calibration、SI5340 或 gating。

本輪沒有達成「兩台 DE5a 已同步」的驗收條件。

## Next Step

1. 保留本輪 SOF 與原始 logs，不覆蓋證據。
2. 先做另一個只讀觀測：讀取 `clock_activity_probe`（JTAG instance 7）與 raw tag counters 的 60 秒同一 session 時序，確認 QSFP-A 125 MHz、QSFP-B DMTD 124.992 MHz、RX recovered clock 是否持續活動，以及 counter 是否只在啟動期間變動。
3. 同時對照 WRPC source 中 `locking_poll()`、`SEQ_READY` 與 `WRH_SPLL_LOCKED` 的條件；在未取得這些證據前不修改 PHY、PTP filter、servo 或 SI5340。
4. 下一個需要改硬體的實驗只能選一個變因，並在燒錄後立即建立新的 `docs/experiments/EXP-*.md`。

## Evidence files

- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/build_all.log`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/build_info_jtag_master.txt`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/build_info_jtag_slave.txt`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/program_master.log`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/program_slave.log`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/runtime_smoke.log`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/raw_diag.log`
- `build/artifacts/EXP-WRPC-TAG-CHANNEL-20260817/evidence_sha256.txt`

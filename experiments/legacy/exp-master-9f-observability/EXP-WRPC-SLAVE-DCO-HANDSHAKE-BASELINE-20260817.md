# 實驗紀錄：Slave 使用已驗證 DCO handshake baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Source/build commit：`a334630f6b041fb076c0495b5c308dbcc199d9de`

## 實驗名稱

`固定成功 Master，將 DCO handshake restore 版本套用到 Slave`

## 這次想驗證什麼

Master 已在相同 DCO handshake restore 版本恢復 `MODE=2/status=FF`。本次只重新編譯並燒錄 Slave，確認 Slave 在成功 Master 對端下是否能進入 parent/servo acquisition，並觀察 DCO state、SoftPLL activity/lock 與 `time_valid/pps_valid`。

成功判準不是只看 link：需要看到 Slave `MODE=3`、parent/foreign 有效、SoftPLL state/lock activity 有進展，最終才以 Slave `time_valid=1、pps_valid=1、spll_locked=1` 且連續取樣穩定作為同步證據。

## 相較 baseline 唯一修改

只把已在 Master A/B 證實可恢復 role 的 DCO controller handshake restore 版本編譯到 Slave image。Slave role、startup command、PHY、clock mapping、SoftPLL firmware 與 DCO debug probe 皆不再新增修改；Master 不重新燒錄。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project/top-level：`DE5a_wr_slave_jtag`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave SOF SHA-256：`fd9db251d8c81b4ef65ffed547f52bed4ebeb5fe6946ee5aaae94dd7567f5dff`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup/hold slack：`-0.195 ns / -3.503 ns`
- Unconstrained clocks/inputs/outputs：`3 / 471 / 82`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_slave_compile.log`
- Compile log SHA-256：`eb3905e482893c8c38ff5868ce2d4ced7e16210939d61ecd3119a11142133749`

## 燒錄結果

Slave 使用 cable `DE5 [1-11.2]`，時間 18:24:19--18:24:38：

```text
Using programming cable "DE5 [1-11.2]"
Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x30A334F4
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817/program_slave.log`
- Programmer log SHA-256：`705e1a0e122b203f2c39f8d3438cc6b836d2191ecca6140ea8cf8558fc7f0970`

## JTAG/runtime 原始結果

原始 logs：

- `/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817/dco_state.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817/dco_activity.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817/clock_activity.log`
- `/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817/runtime_10s.log`

### DCO state/activity

Slave raw state：

```text
DCO_STATE A=FFFB00001000AAA2 B=FFFB00001000AAA2
DCO_ACTIVITY A=0000000019350000 B=00000002B3650000
```

依 probe map，`DCO_STATE` 代表取樣當下：`rt_state=2、bus_state=0、bus_done=0、static_ready=1、hpll_pending=1、dco_busy=1、dco_error=0、completed_step_count=0、hpll_prev_data=0xFFFB`。DCO activity 的 HPLL load counter 約由 `0x193` 增至 `0xB36`，但 completed step 仍為 0；這表示 HPLL request/activity 有變化，但不能把它當成 SI5340 step 已完成。

Master 沒有 Slave-only DCO probe index 9/8，因此讀取腳本對 `DE5 [1-11.1]` 回報 `No In-System Sources and Probes instance was found` 是預期結果。

### Clock/runtime

Master 維持：`TIME_VALID=1、PPS_VALID=1、LINK_OK=1`。

Slave clock activity 顯示：`SYS625_LOCKED=1、CORE_RESET_N=1、PHY_RST=0、SI_DONE=1、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1`；取樣開始時 `PPS_VALID=0`，結束時為 1，但 `TIME_VALID=0`。

Slave 有效 runtime frame 代表值：

```text
WDIAGS_SSTAT:00000101 WDIAGS_PSTAT:00000001 WDIAGS_PTP:00000008
WDIAGS_PTP_META:03010308 WDIAGS_FOREIGN_META:03000001
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 servo_state=1 link_up=1 spll_locked=0
PARENT: foreign_count=1 foreign_best=0 detection=0 wr_config=3 is_wr=1 mode_on=0 calibrated=1
WR_LOCK: result=1 spll_locked=0 seq_state=4 align_state=0 mode=3
WR_SPLL_ACTIVITY: TAG_COUNT=00010449 HELPER_ERROR=FFFDB610 HELPER_OUTPUT=0000FFFB
```

後續 frame 中 `TAG_COUNT`、`REF_COUNT`、`IRQ_COUNT` 與 `PTP_RX/TX` 持續增加，但 `HELPER_ERROR` 仍為 `0xFFFDB610`，`spll_locked` 仍為 0。

- DCO state log SHA-256：`90865cf6e413db6de12277c7567cb748b77e07fd4ea48a3893b10dea514c17b2`
- DCO activity log SHA-256：`f2501304a3c292275d6caaf59d04cfc236b3bd95344e2ba7d3e8adcc47cb013f`
- Clock activity log SHA-256：`5837cdfae7ed2d422f1404e865bbd282a47be1918abea777a2f7797d7def08da`
- Runtime log SHA-256：`aab5cb1c368b1d1dfe8ec186f75353757ebdb73759ab19fb4b2d58f515fd69dd`

## Observation

1. Compile/program 成功，且 Master 在本輪保持已恢復的 `MODE=2/status=FF/time_valid=1`。
2. Slave 已取得有效 parent：`foreign_count=1、foreign_best=0、parent is WR=1、parent calibrated=1`；因此不能再把「沒有 parent」作為第一順位根因。
3. Slave SoftPLL helper 確實有活動：tag/IRQ/REF counters 增加，`SSTAT=0x101、servo_state=1`；但 helper error 固定在 `-150000` clamp，`PSTAT.locked=0、spll_locked=0`。
4. DCO controller 取樣顯示 HPLL pending/busy，但 completed step 為 0；這支持「actuation transaction 尚未完成」的觀察，但尚不能單獨證明是 I2C wiring、request handshake 或 SI5340 register mapping。
5. 本輪已把問題從 PHY/link/parent 建立，收斂到 SoftPLL helper acquisition 與 DCO actuation/feedback loop；仍未完成兩板同步。

## Conclusion

本實驗成功證明 DCO handshake restore 版本能讓 Master 維持已知成功 role，也讓 Slave 進入有 parent、有 helper activity 的 acquisition 狀態；但 Slave 仍未 lock，`time_valid=0`。證據支持目前主要阻塞在 helper error/actuation loop，而不是單純的 CPU boot、PHY link 或 PTP parent discovery。尚不能把根因確定為某一個 SI5340 register 或 I2C transaction。

## Next Step

固定 Master 與 DCO handshake restore，不改 role、PI gain、threshold 或 SI5340 control。下一個只增加 Slave helper lock-acquisition 的唯讀 probe：`helper update count、error last/min/max、lock counter、locked/lock_changed、PI output、reference source`，用來區分「tag 有進但 source 不匹配」、「error 長期在 ±150000 clamp」與「error 已進 ±200 但 lock counter 被清除」三種情況。

# EXP-WRPC-STEP4-D0-SAMPLE-MISMATCH-20260824

## 實驗基本資料

- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- Source commit：`441741129f160ea0535279d1ad0269540a73073d`
- 實驗目的：直接驗證 `dmtd_sampler` 的 source invariant：在 straight、non-oversampled path 中，`clk_i_d0[n]` 是否等於前一個 `clk_dmtd_i` 週期取樣到的 `clk_in[n-1]`。
- 單一操作變因：加入 REF/FB 各一個 32-bit、飽和、唯讀的 `D0_SAMPLE_MISMATCH_COUNT` 旁路診斷；不修改 White Rabbit signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 firmware 功能行為。

## Fresh Build Provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master MIF SHA256：`cdf9c7220d226bd6cd85e6c1406f4ca4e77218823e0205f6501b7dcef10dc757`
- Slave MIF SHA256：`15b97ae85a0d5d9ef34654716791c0db1dd1e007200dde2776a4c4e4a9ad2c35`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`443aba62c1ed9d41f78fb9bfc6e8b7bbc4d81bbd987e749301aaf6315f885bd5`
- Slave SOF SHA256：`2fdca1d51a2a505332d7bff54a1ed999aa9bac3a3f434865a9f60fecca144ce5`
- Master compile：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.242 ns`
- Slave compile：成功；`TIMING_CLOSED=NO`，worst setup slack `-0.156 ns`

`TIMING_CLOSED=NO` 是 implementation caveat；本實驗不得僅由此宣稱它是 Step 4 的根因。

## 燒錄結果

### Master

- Cable：`DE5 [1-11.1]`
- Programmer checksum：`0x30AC2C0F`
- 結果：`Configuration succeeded`，`0 errors, 0 warnings`

### Slave

- Cable：`DE5 [1-11.2]`
- Programmer checksum：`0x30AC2FC7`
- 結果：`Configuration succeeded`，`0 errors, 0 warnings`

## JTAG Runtime 結果

### Step 1～3 regression

`read_wr_handshake_focused.tcl 20 500` 完整結束，沒有 Tcl exception：

| Board | Valid samples | Step 2 | Step 3 | 主要證據 |
|---|---:|---|---|---|
| Master | 20/20 | PASS | N/A | `MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`、`PTP_TX_DELTA=71` |
| Slave | 20/20 | PASS | PASS | `MAC=02:00:22:33:44:02`、`MODE=3`、`PTP=9`、foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4` |

Slave 仍有 `POST_STEP3_LOCK_STAGE=TIMEOUT`、`STATE_EVIDENCE=READ_INCONSISTENT`，focused 統計為 `signal_good=18`、`signal_bad=2`；這是 Step 3 之後的狀態一致性證據，不足以推翻 repeated Step 3 handshake PASS。

### Step 4 focused T0/T1

兩個獨立 `10 samples / 500 ms` read-only 窗口均完整結束，關鍵 register 全部 `valid=10/10`、`timeout=0`。

| Board/channel | T0 mismatch delta | T1 mismatch delta |
|---|---:|---:|
| Master REF | `+28,219,398` | `+28,217,927` |
| Master FB | `+23,900,259` | `+23,978,711` |
| Slave REF | `+74,889,343` | `+2,804,355` |
| Slave FB | `+15,699,087` | `+15,722,369` |

兩個窗口的共同結果：

- `DMTD_REF_SAMPLED`、`DMTD_FB_SAMPLED` 持續大量增加。
- `DMTD_REF_ACCEPT=0`、`DMTD_FB_ACCEPT=0`。
- `DMTD event`、tag pending/grant/valid、TRR write、IRQ、state transition、helper update 全部 `delta=0`。
- Slave `SPLL_MODE=SLAVE`、`RCER=1`，但 sequencer 仍在 `SEQ_WAIT_CLEAR_DACS`，Step 4 startup chain 沒有形成 sustained downstream activity。

Dashboard 同一 fresh image 的結果為：

```text
Step 1 PHY / Link          PASS
Step 2 Endpoint / PTP      PASS
Step 3 WR Handshake        PASS
Step 4 SoftPLL Startup     ERROR
Step 5 Closed-loop Lock    NA
Step 6 Global Time         NA
```

### 原始證據

原始檔均保存於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-D0-SAMPLE-MISMATCH-20260824/`

- `firmware_master_build.log`
- `firmware_slave_build.log`
- `quartus_jtag_master_compile.log`
- `quartus_jtag_slave_compile.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `program_4417411_master_20260824.log`
- `program_4417411_slave_20260824.log`
- `runtime_4417411_step23_20260824.log`
- `runtime_4417411_step4_focused_t0_20260824.log`
- `runtime_4417411_step4_focused_t1_20260824.log`
- `runtime_4417411_dashboard_20260824.log`

## Observation

1. REF/FB 四組 mismatch counter 在兩個獨立窗口均為正向 delta，證明兩個實體取樣暫存器的輸出會持續不同。
2. 但 `clk_in` 對 `clk_dmtd_i` 是非同步訊號。功能用 `clk_i_d0` 與新增的 `dbg_clk_in_d` 是兩顆各自取樣同一非同步訊號的暫存器；在輸入轉換附近可能因 setup/hold 與 metastability 解析不同。因此 counter 增加不能直接等同「VHDL 的 `clk_i_d0 <= clk_in` 邏輯錯誤」，也不能單獨證明這就是 Step 4 根因。
3. 本輪可以確定的是：用第二顆平行 shadow flop 驗證 cycle-exact equality 的方法本身受非同步取樣物理行為限制；同時原本的 Step 4 blocker 仍存在於 sampled transition 之後、deglitch accepted edge 之前。
4. `TIMING_CLOSED=NO` 仍是 caveat，但本輪沒有 A/B evidence 可把它提升成根因。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
ROOT_CAUSE = NOT_PROVEN
```

本輪 fresh build/program/runtime 證明 D0 shadow mismatch 持續增加，但這個結果同時包含「兩個獨立暫存器取樣非同步訊號」的 metastability/clock-domain crossing 效應，因此不能直接宣稱 functional `clk_in -> clk_i_d0` sampler 故障。accepted DMTD 與 downstream chain 仍沒有 sustained activity，Step 4 尚未達成。

## Next Step

先將本輪完整證據交由 White Rabbit 技術討論複核，再選擇下一個單一、source-backed 變因。下一輪不能把這個平行 shadow mismatch counter 當成 cycle-exact sampler correctness 的直接判準，也不得在沒有新證據前修改 polarity、threshold、PI、DCO 或 SI5340。

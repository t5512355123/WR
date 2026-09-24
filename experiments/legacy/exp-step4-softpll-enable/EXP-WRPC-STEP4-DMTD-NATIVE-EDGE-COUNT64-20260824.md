# EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824

## 實驗資訊

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Source commit：`ecf5bbad40306a345c611ec9f27388e876fc0911`
- 實驗狀態：已完成 fresh build、雙板燒錄、Step 1～3 barrier 與 Step 4 T0/T1

## 驗證目標

在不改變 White Rabbit（WR）、Precision Time Protocol（PTP）、SoftPLL、
Digital Dual Mixer Time Difference（DDMTD）、Digital Controlled Oscillator
（DCO）及 SI5340 功能行為的前提下，直接量測 `clk_dmtd_i` 的 edge count，
並與 REF/FB 原生輸入時鐘及 sampled transition counter 比較。此實驗只回答
時鐘是否存在及 rate relationship，不用來宣稱特定 functional root cause。

## 唯一修改變因

在 `wr_softpll_ng.vhd` 增加一組 64-bit 唯讀 DMTD clock edge counter：

- binary counter 與已註冊 Gray code 位於 `clk_dmtd_i` domain；
- Gray bus 經兩級 `gc_sync_register` 同步到 `clk_sys_i`；
- 只在 `clk_sys_i` domain 將 Gray code解回 binary；
- 不驅動 DMTD FSM、deglitch threshold、SoftPLL、servo 或 DCO。

Wishbone read aliases 為 `0x001002F8`（LO）與 `0x001002FC`（HI）。Tcl 以
`HI1 -> LO -> HI2` 讀取，只有 `HI1 == HI2` 才接受 64-bit 數值。

## 建置來源與雜湊

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`7c5093f1462552c6577cf09be0eef2e3d2b93841982138b6fa280097d1b38f6a`
- Slave MIF SHA256：`a5cb1e592bd3a45f9c2aa42cb37d382168f6a8fa51b26e3ba071e9236b2a0b12`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`810935191a8784a393d3c35e0370c64ce36489f73be03c43437e2a8625401f66`
- Slave SOF SHA256：`1049e3bae8d80ce7732b3d580d659afa86471501a120eea1345f281b46bf76b2`

兩個 project 均回報 `Full Compilation was successful`，但整體 timing 未
closed：Master setup/hold WNS 為 `-0.281/+0.037 ns`，Slave 為
`-0.179/+0.036 ns`。新增 DMTD counter 的 dedicated setup report 顯示：

| Project | binary-to-binary worst slack | binary-to-Gray worst slack | 違例 |
|---|---:|---:|---:|
| Master | `+5.646 ns` | `+5.318 ns` | 0/20 |
| Slave | `+5.815 ns` | `+5.450 ns` | 0/20 |

因此目前沒有證據顯示新增 counter 本身位於失敗路徑；這不代表整體設計已
達成 timing closure。

## 燒錄結果

- Master 第一次嘗試：未開始 configuration；非互動 SSH 下 `sudo` 無法讀取
  密碼並立即結束。此為 host 執行介面失敗，不是 FPGA 燒錄失敗。原始輸出
  保存於 `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/program_master_attempt1.log`。
- Master：2026-08-24 04:56（Asia/Taipei）燒錄成功；programmer checksum
  `0x30B050AB`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`。成功輸出保存於
  `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/program_master.log`。
- Slave：2026-08-24 04:57（Asia/Taipei）燒錄成功；programmer checksum
  `0x30B02EDD`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`。輸出保存於
  `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/program_slave.log`。

## Runtime 原始結果

### Step 1～3 regression barrier

dashboard 完整執行且沒有 Tcl exception。接著以
`read_wr_handshake_focused.tcl 30 1000` 取得下列 focused gate：

| 板卡 | Valid samples | Invalid | Counter decrease | Step 2 | Step 3 | PTP TX delta |
|---|---:|---:|---:|---|---|---:|
| Master | 30/30 | 0 | 0 | PASS | N/A | 165 |
| Slave | 30/30 | 0 | 0 | PASS | PASS | 23 |

Slave 30 筆均維持 MAC `02:00:22:33:44:02`、MODE=3、PTP=9、
foreign=`1/0`、parent=`1/0/1`、RX=`0x1001` LOCK、TX=`0x1000`
SLAVE_PRESENT 及 `LOCK_ENABLE=4`。current state 30 筆皆為 `WRS_IDLE`，與其餘
握手證據衝突，因此依既有 gate 保留 `STATE_EVIDENCE=READ_INCONSISTENT`，不把
此 shadow state 當成 Step 3 failure。

### Step 4 T0/T1 DMTD native clock observation

兩個視窗相隔 10 秒；每個視窗為 10 samples、500 ms gap。Slave 結果：

| 視窗 | DMTD frequency | REF native frequency | FB native frequency | REF native/DMTD | FB native/DMTD | REF sampled/DMTD | FB sampled/DMTD |
|---|---:|---:|---:|---:|---:|---:|---:|
| T0 | 124,986,579.655 Hz | 124,990,699.674 Hz | 124,995,883.324 Hz | 1.000224909 | 1.000266390 | 0.995820325 | 0.991940517 |
| T1 | 124,997,968.330 Hz | 124,994,018.614 Hz | 125,016,318.618 Hz | 1.000160334 | 1.000146805 | 0.995711806 | 0.991788128 |

兩個視窗的三組 64-bit counter 均為 10/10 valid，讀取方式回報
`counter_cdc=GRAY2_HI_LO_HI`。時間窗只以毫秒記錄 elapsed time，因此表中頻率
適合判斷「clock 存在且約為 125 MHz」與相對 rate，不足以把數 kHz 差值當成
精密頻率量測。

Slave T0/T1 的 REF/FB accepted edge、DMTD event、tag pending/grant/valid、TRR
write、IRQ、state transition 與 helper update delta 全部為 0。REF
`LOW_QUAL_ABORT` delta 分別為 80 與 158，FB 為 0；這是觀測到的狀態活動，
但本輪不據此宣稱 polarity、threshold、timing 或其他特定 root cause。

原始證據位於：

- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/step123_focused.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/step4_t0.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/step4_t1.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/program_master.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/program_slave.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/timing_dmtd_master.log`
- `raw/EXP-WRPC-STEP4-DMTD-NATIVE-EDGE-COUNT64-20260824/timing_dmtd_slave.log`

JTAG diagnostics SHA256：

- `read_wb_runtime.tcl`：`95cf3d27fd2d99951c801eabaa0cb2d4068c90f49eb6c9ead569a85aefa2c8cf`
- `read_wr_handshake_focused.tcl`：`e9a531ff776d991992b5875cb8a94182d8daed35fb68b020631dc538a1b5605b`
- `read_step4_startup_focused.tcl`：`b0e114c51795c356696d25edbf49090a214c0a36d2260f2b68eb82dd1009d95a`

## Observation

1. fresh/current hardware 的 Step 1、Step 2 與 Step 3 regression barrier 全部通過，
   因此本輪 Step 4 read-only 量測獲准執行。
2. Slave `clk_dmtd_i` 在 T0/T1 均持續增加，量測約 124.987～124.998 MHz；REF
   與 FB 原生 clock 也都持續增加且約為 125 MHz。
3. REF/FB sampled transition 持續增加，但 accepted edge 與其後所有事件鏈在
   兩個視窗均未增加。
4. 新證據排除「`clk_dmtd_i` 完全停止」；它不排除 DMTD domain 內其他 gating、
   qualification、CDC 或整體 timing 問題。
5. 整體設計仍有負 setup slack；新增 counter 的 dedicated report 通過，只能說
   counter 本身沒有出現在該 focused report 的違例路徑。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_DMTD_NATIVE_CLOCK = ACTIVE_APPROX_125MHZ
SLAVE_REF_FB_NATIVE_CLOCK = ACTIVE_APPROX_125MHZ
SLAVE_SAMPLED_ACTIVITY = ACTIVE
SLAVE_ACCEPT_AND_DOWNSTREAM_ACTIVITY = NONE_OBSERVED
FIRST_INACTIVE_BOUNDARY = DMTD_DEGLITCH_ACCEPTANCE
ROOT_CAUSE = NOT_PROVEN
```

本輪證明 DMTD 取樣時鐘與 REF/FB 原生時鐘皆存在，且 Step 1～3 沒有 regression；
但 accepted DMTD edge 與 downstream chain 仍沒有 sustained activity，因此 Step 4
尚未通過。

## Next Step

保存本輪 evidence commit 並交由 White Rabbit 技術討論審查。下一輪仍只允許一個
diagnostic variable；在 reviewer 指定前，不修改 DDMTD polarity、deglitch threshold、
SoftPLL、PI gain、DCO 或 SI5340 functional behavior。

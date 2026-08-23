# EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824

## 實驗資訊

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Source commit：`3c8e2027903274dcdb5d21ec8ebca6d3eea24cb5`
- 實驗狀態：已完成雙板 fresh build、燒錄與 read-only runtime 量測

## 驗證目標

在不改變 White Rabbit（WR）、Precision Time Protocol（PTP）、SoftPLL、
Digital Dual Mixer Time Difference（DDMTD）、Digital Controlled Oscillator
（DCO）及 SI5340 控制行為的前提下，分別量測 REF 與 FB 原生
`clk_in_i` 的 edge count，回答原生輸入 clock 是否存在、頻率是否合理，
並計算 `sampled_transition_delta / native_edge_delta`。

## 唯一修改變因

在 `dmtd_with_deglitcher.vhd` 增加 64-bit 唯讀原生 edge counter：

- binary counter 與已註冊 Gray code 都位於各自 `clk_in_i` domain；
- Gray bus 經既有 `gc_sync_register` 兩級同步到 `clk_sys_i`；
- 只在 system domain 將 Gray code 解回 binary；
- 不驅動 DMTD FSM、deglitch threshold、SoftPLL、servo 或 DCO。

Wishbone 僅重用 write-only 功能寄存器原本未定義的 read side；所有 write
行為保持不變。Tcl 以 `HI1 -> LO -> HI2` 讀取 64-bit counter，只有
`HI1 == HI2` 才接受。

## 建置來源與雜湊

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`243154b470967082b82a9c309c17be3555fd20323f1d1cd6fa23c07bed787034`
- Slave MIF SHA256：`a9e260607ebabda7932b029a39b1c7ba05463aafe2cb0867450391514908b23e`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`ea6a0ede2f8b11aa912aa7df6f4eff3d4e08c28a595748e5f76ff3f8c6d4b9b1`
- Slave SOF SHA256：`99bd8c7e29c676d834918531e45c22c2659fb85ce6dedca736f73cdaa72eda2f`

兩個 project 都回報 `Full Compilation was successful`，但整體 timing 均未
closed：Master setup/hold WNS 為 `-0.450/+0.038 ns`，Slave 為
`-0.389/+0.037 ns`。針對新增 `dbg_native_edge_count_bin` 的 128 個 registers
另做 setup report，10 條最差路徑均通過，worst slack 為 `+5.570 ns`；因此
沒有證據顯示新增 native counter 本身造成整體 worst setup violation。

## 燒錄結果

- Master：2026-08-24 04:23（Asia/Taipei）燒錄成功；programmer checksum
  `0x30AD7A4C`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`
- Slave：2026-08-24 04:24（Asia/Taipei）燒錄成功；programmer checksum
  `0x30B171B0`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`

## Runtime 原始結果

### Step 1～3 regression barrier

使用 `read_wr_handshake_focused.tcl` 連續讀取 30 samples、每次間隔
1000 ms。兩張板均取得 30/30 valid samples，沒有 invalid sample 或 counter
decrease：

| 板卡 | Step 2 | Step 3 | PTP TX delta | 關鍵證據 |
|---|---|---|---:|---|
| Master | PASS | N/A | 165 | MAC `...:01`、MODE=2、PTP=6、packet counters 持續增加 |
| Slave | PASS | PASS | 21 | MAC `...:02`、MODE=3、PTP=9、foreign=`1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、LOCK_ENABLE=4 |

Slave 的 current WR state 在 30 筆皆為 `WRS_IDLE`，但 LOCK、SLAVE_PRESENT、
LOCK_ENABLE 與 parent evidence 在 30/30 筆均成立，因此依既有 gate 保留
`STATE_EVIDENCE=READ_INCONSISTENT`，不把單一 shadow state 當成 Step 3 failure。

### Step 4 T0/T1 native edge observation

兩個量測視窗相隔 10 秒；每個視窗使用 10 samples、500 ms gap。Slave 結果：

| 視窗 | REF native frequency | FB native frequency | REF sampled/native | FB sampled/native | REF/FB accept delta |
|---|---:|---:|---:|---:|---:|
| T0 | 124,985,682.825 Hz | 125,015,621.611 Hz | 0.994807766 | 0.994041478 | 0 / 0 |
| T1 | 124,973,790.941 Hz | 125,001,015.427 Hz | 0.995029675 | 0.994091470 | 0 / 0 |

T0/T1 的 native counter、sampled counter 都持續增加，且 64-bit read 均回報
`result=VALID counter_cdc=GRAY2_HI_LO_HI`。但兩個視窗的 DMTD event、tag
pending/grant/valid、TRR write、IRQ、state transition 與 helper update delta
全部為 0。

原始證據位於：

- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/step123_focused.log`
- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/step4_t0.log`
- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/step4_t1.log`
- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/program_master.log`
- `raw/EXP-WRPC-STEP4-NATIVE-EDGE-COUNT64-20260824/program_slave.log`

JTAG diagnostics SHA256：

- `read_wb_runtime.tcl`：`95cf3d27fd2d99951c801eabaa0cb2d4068c90f49eb6c9ead569a85aefa2c8cf`
- `read_wr_handshake_focused.tcl`：`e9a531ff776d991992b5875cb8a94182d8daed35fb68b020631dc538a1b5605b`
- `read_step4_startup_focused.tcl`：`0cf0a6459fbe87262231ec5d182c190c41a6a5ed5ededd03b53a6864dbffeeca`

## Observation

1. Step 1、Step 2 與 Step 3 regression barrier 均通過，因此本輪 Step 4
   read-only 實驗獲准執行。
2. Slave REF 與 FB 原生輸入 clock 均存在，兩個 5 秒視窗的量測頻率都接近
   125 MHz。
3. 兩路 sampled counter 持續增加，約為 native edge count 的 99.4%～99.5%。
4. 兩個視窗內 REF/FB accept 與其後所有事件鏈 counter 都沒有增加。
5. T0/T1 的 current deglitch state 分類並不完全一致，因此不能用單一 current
   state 宣稱根因；可確定的第一個 inactive boundary 是 sampled transition
   之後、accepted DMTD edge 形成之前。
6. 整體設計仍有負 setup slack；新增 native counter 的 dedicated report 通過，
   但這不足以排除其他 timing path 對功能的影響。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_REF_NATIVE_CLOCK = ACTIVE_APPROX_125MHZ
SLAVE_FB_NATIVE_CLOCK = ACTIVE_APPROX_125MHZ
SLAVE_SAMPLED_ACTIVITY = ACTIVE
SLAVE_ACCEPT_AND_DOWNSTREAM_ACTIVITY = NONE_OBSERVED
FIRST_INACTIVE_BOUNDARY = DMTD_DEGLITCH_ACCEPTANCE
ROOT_CAUSE = NOT_PROVEN
```

本輪證明 REF/FB 原生輸入 clock 並未停止，也證明 sampled transition 持續
存在；但仍未形成 accepted DMTD edge，Step 4 尚未通過。這些證據不能單獨
證明 polarity、threshold、時序違例或任何特定演算法是根因。

## Next Step

先保存本輪 evidence commit 並交由 White Rabbit 技術討論審查。下一輪仍只允許
一個 diagnostic variable；在 reviewer 指定前，不修改 DDMTD polarity、deglitch
threshold、SoftPLL、PI gain、DCO 或 SI5340 functional behavior。

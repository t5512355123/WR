# EXP-WRPC-STEP4-REVERSE-DMTD-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Git commit：`d19b26d6f0d8f91fb82d49de23c90b1caf4b12d7`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- 實驗類型：Step 4 單一 functional A/B
- A control：`g_softpll_reverse_dmtds=false`，使用原本 default 行為
- B 本輪：`g_softpll_reverse_dmtds=true`

## 驗證目標

驗證 `g_softpll_reverse_dmtds` 是否是目前 DMTD deglitch acceptance 停止的
causal blocker。這個 generic 在目前 `g_pcs_16bit=false` 的設定下，會同時：

- 關閉 `g_divide_input_by_2`
- 開啟 reverse DMTD sampling

因此本實驗只回答這個 top-level configuration 組合是否能讓 Step 4 的
accepted DMTD event 與後續 SoftPLL startup activity 恢復。不能把結果拆解成
只有 divide-by-2 或只有 reverse mode 的獨立因果證明。

## 唯一修改變因

只修改兩個 top wrapper 的同一個 generic：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`

新增：

```vhdl
g_softpll_reverse_dmtds => true,
```

沒有修改 `wr_core.vhd`、firmware、PTP、WR signaling、PHY、DDMTD algorithm、
PI gain、lock threshold、DCO 或 SI5340 行為。

## Build provenance

- pain checkout：exact detached HEAD `d19b26d6f0d8f91fb82d49de23c90b1caf4b12d7`
- Master MIF SHA256：`cf0bf4cfea3b751eb1a6bb9ac6a4e8edae53a12852a2206a7432e05027abe905`
- Slave MIF SHA256：`0896bf06fc985b29a351631f8655d958bbee220620dc47e9b053f9b0a4df4d7f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`1639e6fb41c03659a76e676c4142d2cfe20b9568f904b0a957c3a4fb60e67a08`
- Slave SOF SHA256：`e11f04b89fe5ab113e30844e28da8da10ed54fb5e83b0c558675f30b6370eac7`
- Master build：成功，`timing_closed=NO`
- Slave build：成功，`timing_closed=NO`

完整 provenance 保存於：

`raw/EXP-WRPC-STEP4-REVERSE-DMTD-20260824/build_provenance.txt`

## 燒錄結果

Master 使用 cable `DE5 [1-11.1]`：

- Programmer checksum：`0x30B0E522`
- `Configuration succeeded -- 1 device(s) configured`
- Quartus programmer：0 errors、0 warnings
- 原始輸出：`raw/EXP-WRPC-STEP4-REVERSE-DMTD-20260824/program_master.log`

Slave 使用 cable `DE5 [1-11.2]`：

- Programmer checksum：`0x30B52E94`
- `Configuration succeeded -- 1 device(s) configured`
- Quartus programmer：0 errors、0 warnings
- 原始輸出：`raw/EXP-WRPC-STEP4-REVERSE-DMTD-20260824/program_slave.log`

## Runtime 結果

燒錄後執行：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
```

原始輸出：

`raw/EXP-WRPC-STEP4-REVERSE-DMTD-20260824/step123_focused.log`

Quartus SignalTap 執行成功，0 errors、0 warnings；但 regression gate 沒有
通過，因此依 barrier 規則沒有執行 Step 4 T0/T1。

### Master

- valid samples：13/30
- invalid samples：17/30
- valid sample 的 MAC：`02:00:22:33:44:01`
- valid sample 的 `WDIAGS_MODE=3`、`WDIAGS_PTP=4`
- PTP TX delta：18
- MiniNIC counters 有增加，但沒有進入預期 Master role
- `STEP2_REGRESSION=FAIL`
- `STEP3_REGRESSION=FAIL`

### Slave

- valid samples：15/30
- invalid samples：15/30
- valid sample 的 MAC：`02:00:22:33:44:02`
- valid sample 的 `WDIAGS_MODE=3`、`WDIAGS_PTP=4`
- PTP TX delta：18
- Foreign Master、LOCK、SLAVE_PRESENT、LOCK_ENABLE 都沒有恢復到 gate
- `STEP2_REGRESSION=FAIL`
- `STEP3_REGRESSION=FAIL`

兩板 valid sample 都顯示 `status=0xEF`，但這不能抵銷 role/PTP regression；
invalid mailbox 值也沒有被混入有效 sample 的判定。

## 初步結論

本輪 B 版本已由 exact commit clean build 並成功燒錄，但 Step 2/3 regression
失敗，因此不能進入 Step 4 gate，也不能宣稱 `g_softpll_reverse_dmtds=true`
已修正 Step 4。

```text
STEP1_REGRESSION = NOT_ACCEPTED
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED = NO
STEP4_RESULT = NOT_MEASURED
HARDWARE_FIRMWARE_FAILURE = NOT_PROVEN_AS_ROOT_CAUSE
JTAG_MEASUREMENT_FAILURE = PRESENT
AB_CONFIGURATION_ACCEPTED = NO
```

本輪已證明的是：目前這個同時改變 reverse sampling 與 input divide 行為的
configuration，不能在保留 Step 2/3 regression 的條件下直接作為 B 版本；它
尚未提供 Step 4 PASS 證據。這個結果不等同於已證明 DMTD hypothesis 錯誤，
也不等同於已證明它是唯一根因。

## Next Step

使用既有 focused read-only scripts 先驗證 Step 1～3；若 regression gate
通過，再量測 D0/DMTD transition、stable run、accept、event/tag/TRR/IRQ、
sequencer 與 helper activity。本輪結果先交由 White Rabbit 技術對話審查，
在未釐清 role/PTP regression 前，不再修改第二個 functional variable。

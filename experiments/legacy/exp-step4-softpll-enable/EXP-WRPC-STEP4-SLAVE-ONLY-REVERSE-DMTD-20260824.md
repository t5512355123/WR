# EXP-WRPC-STEP4-SLAVE-ONLY-REVERSE-DMTD-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Git commit：`e0a926fb31a0ca08cba9e2e80275b7c6c7fdab77`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- 實驗類型：Step 4 Slave-only functional A/B
- A control：Master/Slave 都使用 `g_softpll_reverse_dmtds=false`
- B 本輪：Master 維持 control；只在 Slave wrapper 使用
  `g_softpll_reverse_dmtds=true`

## 驗證目標

上一輪兩片同時啟用 reverse DMTD 後，Master 也失去已知 role/PTP regression。
本輪保留 Master 的 known-good baseline，只在需要 SoftPLL/servo 的 Slave 啟用
reverse DMTD，確認能否避免 Master role regression，同時讓 Slave 的 DMTD
deglitch acceptance 恢復。

## 唯一修改變因

相對 A control，只有：

`quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`

新增：

```vhdl
g_softpll_reverse_dmtds => true,
```

Master wrapper 沒有 override，維持原本 default `false`。沒有修改 role switching、
PTP、WR signaling、SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold、
DCO、SI5340、PHY 或 firmware functional behavior。

## Build provenance

- pain checkout：exact detached HEAD `e0a926fb31a0ca08cba9e2e80275b7c6c7fdab77`
- Master MIF SHA256：`cf0bf4cfea3b751eb1a6bb9ac6a4e8edae53a12852a2206a7432e05027abe905`
- Slave MIF SHA256：`0896bf06fc985b29a351631f8655d958bbee220620dc47e9b053f9b0a4df4d7f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`485807aba648dcb0c7364547bb1c861d1ca21fb3e6c03d46623fd43fd350ab4e`
- Slave SOF SHA256：`bf643b86d2ec55300e74463ae1be924ccac4cd3502258c23e395f45f7a11c604`
- Master build：成功，`timing_closed=NO`
- Slave build：成功，`timing_closed=NO`

完整 provenance：

`raw/EXP-WRPC-STEP4-SLAVE-ONLY-REVERSE-DMTD-20260824/build_provenance.txt`

## 燒錄結果

Master 使用 `DE5 [1-11.1]`：

- Programmer checksum：`0x30B32E2A`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors、0 warnings
- 原始輸出：`raw/EXP-WRPC-STEP4-SLAVE-ONLY-REVERSE-DMTD-20260824/program_master.log`

Slave 使用 `DE5 [1-11.2]`：

- Programmer checksum：`0x30B52E94`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors、0 warnings
- 原始輸出：`raw/EXP-WRPC-STEP4-SLAVE-ONLY-REVERSE-DMTD-20260824/program_slave.log`

本紀錄先在燒錄完成後建立；runtime regression 結果於下一節補入。

## Runtime 結果

使用 exact fresh SOF 燒錄後等待板卡穩定，執行：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
```

完整原始輸出：

`raw/EXP-WRPC-STEP4-SLAVE-ONLY-REVERSE-DMTD-20260824/step123_focused.log`

### Master（control 保留）

- 30/30 samples valid，0 invalid
- status probe：`0xFF`
- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- PTP/MiniNIC counters 有活動，`RXERR=0`
- `STEP2_REGRESSION=PASS`
- `STEP3_REGRESSION=NA`（Master 不適用 Slave parent/handshake gate）

### Slave（reverse DMTD B）

- 18/30 samples valid，12 invalid
- MAC valid sample：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- valid samples 的 `WDIAGS_PTP=4`，未達穩態 Slave `9`
- PTP RX/TX activity 不足以建立 Step 2 gate
- `RXERR` 由 sample 3 的 `111` 增加至 sample 28 的 `132`
- `FOREIGN_META=0/255`，parent flags：`0/0/0`
- 未觀測到 `LOCK=0x1001`、`SLAVE_PRESENT=0x1000`
- `LOCK_ENABLE=0`、`RCER=0`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- `STEP2_REGRESSION=FAIL`
- `STEP3_REGRESSION=FAIL`

### Regression barrier

```text
STEP1_REGRESSION = NOT_ACCEPTED
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED    = NO
STEP4_RESULT     = NOT_MEASURED
```

本輪沒有執行 Step 4 T0/T1，因為 Step 2/3 regression 未通過。

## 初步結論

Master control baseline 被保留：同一輪 30-sample regression 仍通過。
但是 Slave-only `g_softpll_reverse_dmtds=true` 的 fresh image 沒有重現
Step 2/3；Slave 在 packet/PCS/role path 階段即失敗，不能進入 Step 4。

這表示本設定目前不可接受，但尚不能只由這一輪讀值確定 reverse generic 是
根本原因。可確定的是：本輪的 Slave regression failure 發生在 SoftPLL startup
gate 之前，並非 Step 4 lock 結果。

證據分類：

- `HARDWARE/FIRMWARE FAILURE`：尚未證明為根因；目前只有 fresh image 的
  Slave runtime regression failure。
- `JTAG/DASHBOARD MEASUREMENT FAILURE`：存在 12/30 invalid samples 與
  `READ_INCONSISTENT`，因此必須保留 measurement caveat；但 valid samples
  同時顯示 PTP=4、RXERR 增加、Foreign/parent/WR messages 缺失，不能把
  全部失敗解釋成單純 dashboard 誤判。
- `MASTER_CONTROL_PRESERVED=YES`
- `SLAVE_REVERSE_CONFIGURATION_ACCEPTED=NO`

## Next Step

保留本輪 commit 與原始紀錄，先與 White Rabbit 討論確認。後續若繼續，應
優先回到 Slave control 設定並針對 `g_softpll_reverse_dmtds` 的實際 clock/
PCS semantics 做 source audit；在新的單一變因取得 reviewer 共識前，不再
燒錄或執行 Step 4 functional experiment。

```text
目前允許的下一步：read-only source audit
目前不允許的下一步：Step 4 T0/T1、SoftPLL 演算法修改、merge main
```

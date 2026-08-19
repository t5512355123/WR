# EXP-WRPC-STEP4-FRESH-HEAD-RETEST-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-FRESH-HEAD-RETEST-20260820`
- 日期：2026-08-20（Asia/Taipei）
- 實驗名稱：Step 4 fresh HEAD 重建、雙板燒錄與固定等待時間回歸
- Git branch：`exp/step4-softpll-enable`
- 燒錄來源 commit：`ab65815e1092d9ae37830881f83b223d16d4d6cd`
- 實驗類型：fresh provenance / runtime regression retest
- 實驗狀態：**NOT PASS**

## 這次想驗證什麼

確認目前 GitHub 最新 branch HEAD 由 clean checkout 重新產生 firmware、MIF、Quartus SOF 後，雙板燒錄並等待固定 60 秒，是否可以重現已知 Step 2 role baseline，並確認 Step 4 的 SoftPLL/DCO observability 是否開始活動。

本輪特別要排除兩個可能性：

1. 前一次 JTAG snapshot 是否只是讀得太早。
2. 前一次 SOF/MIF 是否不是目前 branch HEAD 的 fresh output。

本輪沒有把 `spll_locked=1` 或 `time_valid=1` 當作 Step 4 gate；但若 Step 2 role 尚未成立，不能把 DCO 無活動單獨歸因於 DCO handshake。

## 相較上一個硬體實驗唯一改變

本輪沒有修改 functional RTL、firmware role code、PTP algorithm、WR signaling、SoftPLL algorithm、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 register sequence。

唯一的實驗變因是以 GitHub 最新 `ab65815` 做完整 clean firmware build、`quartus_sh --clean`、fresh Quartus compile 與 fresh SOF programming；上一輪燒錄使用的是相同 functional source 的較早 provenance commit `4d96eb4`。

## Build provenance

- Quartus：`Version 17.0 Build 595 04/25/2017 SJ Standard Edition`
- Build host：`pain`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- 共用 SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`2923ee8b903abecc6208c0262f3983db829c97bd86e6081903700f94f05cc1a8`
- Slave MIF SHA256：`1f53c89ac3aed988b100ce1353d049201a058a0c14bc42d8a7f805c084301efb`
- Master SOF SHA256：`f53a7620c376a229f7e6c646add333bf505b9b57439845be55d4f1907c5ce72e`
- Slave SOF SHA256：`9d3e5c7aa3b2ed2e2c0603004a91350017a0e66ecd1f6667a8423bf7c3120873`
- Master compile：`Full Compilation was successful`、Fitter successful、timing closed=`NO`
- Slave compile：`Full Compilation was successful`、Fitter successful、timing closed=`NO`

完整 build、compile、program 與 JTAG 原始輸出保存在：

`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-FRESH-HEAD-RETEST-20260820/`

## 燒錄結果

| 節點 | Cable | Programmer checksum | 結果 |
|---|---|---:|---|
| Master | `DE5 [1-11.1]` | `0x30A36FF4` | `Configuration succeeded`、0 errors、0 warnings |
| Slave | `DE5 [1-11.2]` | `0x309E949B` | `Configuration succeeded`、0 errors、0 warnings |

第一次執行時曾因 Quartus 17 `-o` 選項誤用冒號而得到 `Programming option string ... is illegal`；該次沒有開始 configuration，不列為硬體結果。修正為 `p;/absolute/path/to.sof` 後，上表兩次燒錄均成功。

## JTAG runtime 原始結果

燒錄後等待 60 秒，再執行 `scripts/jtag/read_wb_runtime.tcl`；另以 `read_dco_state.tcl` 及 `read_hpll_helper_correlation.tcl` 做唯讀觀察。完整 raw output 位於實驗附件目錄。

### Acceptance 摘要

| 項目 | Master `DE5 [1-11.1]` | Slave `DE5 [1-11.2]` | 判定 |
|---|---:|---:|---|
| CPU reset/fault/im_valid | `0/0/1` | `0/0/1` | PASS，CPU runtime 存活 |
| boot marker | `B004`, seen=1 | `B004`, seen=1 | PASS，marker 可讀 |
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS，唯一身份正確 |
| `WDIAGS_MODE` | `3` | `3` | FAIL，Master 未為 `2` |
| `WDIAGS_PTP` | `4` | `9` | PARTIAL，Slave=`PPS_SLAVE`；Master 非 `PPS_MASTER` |
| PPSI PTP RX/TX | `0x57/0x2C` | `0x2C/0x59` | PASS，snapshot 有活動 |
| MiniNIC TX/RX | `0x9D/0xA7` | `0xB6/0x79` | PASS，frame counter 有活動 |
| Slave `FOREIGN_META` | 不適用 | `0x00000001` | FAIL，未重現 `0x03000001` parent metadata |
| Slave `LOCK_ENABLE` | 不適用 | `0` | NOT OBSERVED |
| Slave `SPLL_STATE` / `UCNT` | 不適用 | `0` / `0` | NOT OBSERVED |
| Slave DCO `STEP` | 不適用 | `0` | NOT OBSERVED |

Slave DCO debug 連續讀值保持：

```text
rt_state=0 bus_state=0 bus_done=0 ready=1 start=0 enable=0
dpll_load=0 hpll_load=0 error=0 busy=0 steps=0 hold=0
```

HPLL/helper correlation 10 次 sample 顯示：

```text
PSTAT=0 SSTAT=1 UCNT=0 LOCK_ENABLE=0 SPLL_STATE=0
RCER=0 TRR_CSR=0x00020000 REF=0 TAG=0 IRQ=0
TAG_VALID=0 TRR_WRITE=0 STEP=0 HPLL_LOAD=0 BUSY=0 ERROR=0
```

### Raw output 路徑

- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- `build_jtag_master.log`
- `build_jtag_slave.log`
- `quartus_jtag_master_compile.log`
- `quartus_jtag_slave_compile.log`
- `program_jtag_master.log`
- `program_jtag_slave.log`
- `jtag_runtime.log`
- `jtag_dco_state.log`
- `jtag_hpll_helper_correlation.log`

## Observation

1. `ab65815` 可以完成 clean firmware build、Quartus clean compile 與雙板 programming；因此 HEAD→MIF→SOF→program provenance 成立。
2. 兩端 MAC 均已正確，表示本輪 fresh image 確實包含 role-specific identity；前一次讀到的 Slave fallback MAC 是早期 snapshot 時機或舊 runtime 狀態，不是本輪 fresh image 的持續結果。
3. Slave 在固定等待後可以到 `PPS=9`，但 `FOREIGN_META=0x00000001`，仍沒有重現 Step 2 所需的 WR parent metadata `0x03000001`。
4. Master 長時間仍為 `MODE=3/PTP=4`，因此不是單純「read 太早」；目前 source-level 的 built-in `mode master` 是否真正完成，仍需要單一變因 observability 來確認。
5. Slave 沒有 `LOCK_ENABLE`、SoftPLL state、UCNT 或 DCO step 活動。因為 Step 2 role/parent baseline 尚未成立，這一輪不能把 DCO handshake failure 單獨歸因於 `si5340a_controller_dco.v`。

## Conclusion

本次實驗為 **NOT PASS**。

證據支持：

- exact `ab65815` fresh source/build/program 流程可重現。
- CPU、MAC、MiniNIC 與 PPSI runtime path 有活動。
- Slave 可進入 `PPS_SLAVE=9`。

證據不支持：

- Master=`MODE=2/PPS_MASTER=6`。
- Slave=`FOREIGN_META=0x03000001`。
- Step 4 SoftPLL channel enabled 或 DCO transaction 完成。

因此目前第一個 blocker 應優先放在 **Master startup role execution / role observability 與 Step 2 parent discovery**，不是直接修改 SoftPLL 演算法，也不能宣稱 DCO handshake 修正已成功或已被證偽。

## Next Step

1. 在本機先 audit `shell_boot_script()`、built-in `CONFIG_INIT_COMMAND` 與 `wrc_ptp_set_mode()` 的實際執行路徑，維持 9f848ec/c88cc05 的 Master role 方法，不另創 role switching。
2. 優先加入或利用既有唯讀 boot-stage evidence，區分「Master command 未執行」與「command 執行後被 runtime 狀態覆寫」；這是下一個單一 functional variable。
3. 在 Master=`MODE=2/PTP=6`、Slave=`MODE=3/PTP=9`、`FOREIGN_META=03000001` 的 fresh HEAD 重現前，不進行 Step 4 DCO/SoftPLL functional tuning，也不宣稱 Step 4 PASS。
4. 保留本次 `ab65815` 及所有 raw logs，下一次燒錄前先 commit/push，再由 pain pull exact commit。

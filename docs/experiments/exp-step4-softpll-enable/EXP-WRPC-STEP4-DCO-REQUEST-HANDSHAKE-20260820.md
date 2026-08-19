# EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820`
- 日期：2026-08-20（Asia/Taipei）
- 實驗名稱：修正 DCO request 跨分頻 I2C 時脈的握手
- Git branch：`exp/step4-softpll-enable`
- 功能變更 commit：`2cf8276769301c195e63aff76caf18082be8688d`
- 實驗狀態：exact commit 已 clean build、program；等待燒錄後 runtime 驗證

## 這次想驗證什麼

確認 Step 4 的 SoftPLL correction request 是否能從 `xwr_core` 的 HPLL DAC request，經過 top-level DCO wrapper，真正啟動 SI5340 的 I2C runtime transaction 並完成一個 DCO step。

這不是要驗證 `spll_locked=1` 或 `time_valid=1`；本輪只先驗證：

```text
helper correction request
    -> DCO runtime request accepted
    -> I2C bus transaction starts and returns idle
    -> completed DCO step count increases
```

## 相較 baseline 唯一修改

只修改：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`。

現象基線為 `edd1259` fresh SOF：DCO debug 長期顯示：

```text
rt_state=2  bus_state=0  BUSY=1  STEP=0  ERROR=0
```

source audit 發現 outer state machine 使用 50 MHz `iCLK`，但 `i2c_bus_controller_dco` 使用 `clock_divider` 產生的較慢 clock。原本 state 1、3、5 看到 `runtime_start` 後立即前進，`bus_start` 可能只存在一個 50 MHz cycle，分頻後的 I2C domain 可能漏採樣。

本輪唯一修改是：

- state 1 改為等待 `bus_state=1` 後才進 state 2。
- state 3 改為等待 `bus_state=1` 後才進 state 4。
- state 5 改為等待 `bus_state=1` 後才進 state 6。

這讓 `runtime_start/bus_start` 在 request state 保持有效，直到 I2C controller 的 busy indication 回來。沒有修改 Master/Slave role、startup command、PHY、PTP、WR signaling、SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 register sequence。

## 預期結果

若跨時脈 request pulse 確實是第一個 blocker，預期 Slave 的 JTAG correlation 會從：

```text
rt_state=2  bus_state=0  STEP=0
```

變成可以觀察到：

- `bus_state` 先變為 1，再回到 0。
- `rt_state` 能完成 1 到 6 的三段 transaction。
- `STEP` 增加。
- `DCO_ERROR=0`。
- `DAC_HPLL` 與 SI5340 runtime activity 有可追溯變化。

若仍停在 state 1 且 `bus_state=0`，則表示問題不是單純的 request 保持，下一步要檢查 I2C controller enable、clock divider、SDA/SCL 或 static controller ready；不能直接宣稱 SI5340 或光路故障。

## 建置與燒錄 provenance

pain 是從 GitHub 的 exact commit `4d96eb4c5e9e73276dca45853a4995a7657e459` 建置；沒有使用 historical SOF。兩張板都先執行 clean build，Quartus fit 成功，但 timing 尚未 closure，這個限制必須與功能觀察分開記錄。

- Git branch：`exp/step4-softpll-enable`
- Git HEAD：`4d96eb4c5e9e73276dca45853a4995a7657e459`
- Quartus version：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- 共用 SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`5ab5d5f797c056ceac7a371786dd2647ce75be5cd3b8658a3d29479c64c9b857`
- Slave MIF SHA256：`3d3c351b616d80bb49ad11869a1c09cde7cf9209ff154f4102b2da24afdf3982`
- Master SOF SHA256：`e0ef350b260034c7d4c2abe24bde330ee368f7f50f3b3973953966d2c6ae0ffa`
- Slave SOF SHA256：`88940c4788c7a09ade00c81736155d1404d9fe2a5c152085f6cae60441e8b770`
- Master compile：`Full Compilation was successful`；worst setup slack `-0.180 ns`；worst hold slack `-3.468 ns`
- Slave compile：`Full Compilation was successful`；worst setup slack `-0.176 ns`；worst hold slack `-3.488 ns`
- Master programmer checksum：`0x30A36FF4`；`Configuration succeeded`；`0 errors, 0 warnings`
- Slave programmer checksum：`0x309E949B`；`Configuration succeeded`；`0 errors, 0 warnings`
- 原始附件目錄：`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-DCO-REQUEST-HANDSHAKE-20260820/`
- build log：`build_jtag_master.log`、`build_jtag_slave.log`
- hash/build info：`sof_mif_hashes_20260820.txt`、`build_info_jtag_master.txt`、`build_info_jtag_slave.txt`
- programmer log：`program_jtag_master_20260820.log`、`program_jtag_slave_20260820.log`

本次沒有執行 reboot，也沒有觀察到 stall 或連線中斷。

## JTAG runtime 原始結果

燒錄後以 exact commit 產生的 fresh SOF 進行 read-only 觀測。原始輸出已保存於同一實驗附件目錄：

- `read_wb_runtime.tcl` 原始輸出：`jtag_runtime_after_program.log`
- DCO state 原始輸出：`jtag_dco_state_after_program.log`
- HPLL/helper correlation 原始輸出：`jtag_hpll_helper_correlation_after_program.log`

燒錄後 snapshot 的關鍵結果如下：

| 項目 | DE5 [1-11.1] | DE5 [1-11.2] | 判讀 |
|---|---:|---:|---|
| CPU reset/fault/im_valid | `0/0/1` | `0/0/1` | 兩邊 CPU runtime 存活 |
| boot marker | `B004`, seen=1 | `B004`, seen=1 | firmware 已執行 |
| status PHY/link | `...82EF` | `...82EF` | snapshot 顯示共同 link/PHY 基本狀態，但仍需沿用 decode script 解碼 |
| MAC | `02:00:22:33:44:01` | `02:00:02:00:00:02` | Slave 不是預期的 `02:00:22:33:44:02` |
| WDIAGS_MODE | `3` | `3` | Master 未進入預期的 `2` |
| WDIAGS_PTP | `4` | `2` | 未得到預期 `PPS_MASTER=6` / `PPS_SLAVE=9` |
| PTP RX/TX | `0x141/0xA8` | `0xA8/0x131` | PTP counter 有活動，但 role 不符合 baseline |
| WDIAGS_FOREIGN_META | `0x0000FF01` | `0x00000001` | 本列不能當作已建立 Step 2 Foreign Master 的 baseline 證據 |
| MiniNIC TX/RX | `0x1D8/0x230` | `0x25F/0x194` | frame-level counter 有活動 |

DCO state 唯讀結果：

```text
DE5 [1-11.1]: No In-System Sources and Probes instance was found.
DE5 [1-11.2]: A=0x0000000000000020, B=0x0000000000000020
rt_state=0 bus_state=0 bus_done=0 ready=1 start=0 enable=0
dpll_load=0 hpll_load=0 error=0 busy=0 steps=0 hold=0
```

HPLL/helper correlation 在 Slave 連續 10 個 sample 中保持：

```text
UCNT=0 LOCK_ENABLE=0 SPLL_STATE=0 REF=0 TAG=0 IRQ=0
TAG_VALID=0 TRR_WRITE=0 STEP=0 STEP_DELTA=0
HPLL_LOAD=0 BUSY=0 ERROR=0
```

其中 raw `TAG_SOURCE` 會變動，但 `TAG`、`REF`、`UCNT` 與 DCO completed step 沒有形成可接受的活動證據；不能把它誤判成 SoftPLL 已 enable。

至少記錄 Master/Slave 的 CPU marker、PHY/link、MAC、MODE、PTP、Foreign Master、`LOCK_ENABLE`、`SPLL_STATE`、`REF/TAG/IRQ/TAG_VALID/TRR_WRITE/UCNT`、`DCO_DEBUG`、`STEP`、`BUSY`、`ERROR` 與 DAC shadow。

## Observation

1. exact commit 的 fresh clean build 與雙板 program 均成功，沒有 reboot、stall 或連線中斷。
2. 兩張板 CPU 都持續執行，marker=`B004`，`reset=0`、`fault=0`、`im_valid=1`。
3. MiniNIC frame counter 與 PTP RX/TX counter 有數值，表示此 snapshot 仍能看到 runtime/封包路徑活動。
4. 但是這次 fresh image 沒有重現已知 Step 2 role：Master 讀到 `MODE=3/PTP=4`，Slave 讀到 `MODE=3/PTP=2`，Slave MAC 也不符合預期唯一身份。
5. Slave DCO probe 在 1 秒前後相同，10 秒 correlation 中 `LOCK_ENABLE=0`、`SPLL_STATE=0`、`UCNT=0`、`STEP=0`；沒有證據顯示本輪握手修正已讓 SoftPLL/DCO transaction 開始。
6. 因為 role/MAC/MIF provenance 已先不符合 baseline，本次不能把 DCO 沒活動單獨歸因於握手修正，也不能宣稱 Step 4 blocker 已被定位。

## Conclusion

本次結論為 **NOT PASS / 需要先處理 role/MIF provenance 回歸**。證據支持「exact HEAD 可以 clean compile、program，且 CPU/runtime 有活動」，但不支持 Step 2 role baseline，也不支持 Step 4 SoftPLL channel 已 enable 或 DCO request 已完成。這次不能宣稱 `DCO request 握手` 修正有效，也不能從這份結果推論 SoftPLL 演算法或光路是根因。

## Next Step

1. 已完成 exact commit 的 clean firmware build、`quartus_sh --clean`、Master/Slave clean compile。
2. 已完成兩張板的 program，接著只做 read-only JTAG snapshot 與 time-series。
3. 暫停新的燒錄與 functional 修改，先在本機 audit Master/Slave firmware startup role、MIF 產生來源、MAC 設定與 programming script 的 exact input，並和 `c88cc05`/`9f848ec` known-good provenance 逐項比對。
4. 只有重新建立正確的 Master=`MODE=2/PTP=6`、Slave=`MODE=3/PTP=9`、唯一 MAC 的 fresh image 後，才重新評估本輪 DCO request 握手變因。

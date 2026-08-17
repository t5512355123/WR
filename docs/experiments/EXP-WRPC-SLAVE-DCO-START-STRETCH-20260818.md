# 實驗紀錄：Slave DCO runtime start 跨時脈保持

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only functional A/B
- Git branch：`exp/master-9f-observability`
- 實驗紀錄建立前 commit：`b847dec`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

上一輪 DCO probe 實際讀到：

```text
rt_state=2
hpll_pending=1
dco_busy=1
bus_state=0
bus_done=0
```

現有 DCO controller 的 runtime request 在 50 MHz domain 產生，而 I2C bus controller 使用分頻後的 `i2c_system_clk`。本輪只驗證：把 runtime start 從單一 50 MHz pulse 保持成「直到 bus_state 回應」的 request level，是否能讓 I2C bus 真正進入 busy/completion。

## 相較 baseline 的唯一變因

- Master：維持 exact historical `9f848ec` SOF，不重新燒錄。
- Slave：只修改 `si5340a_controller_dco.v` 的 runtime start request hold；不改 WR parser、role、PHY、DDMTD、servo、SoftPLL threshold、SI5340 register sequence 或 MIF。
- request hold 會在 runtime start 事件發生時置位，並在 `bus_state` 變成 1 後清除；其餘原本 state transition 不變。

## 預定產物與判準

- 沿用 clean-9f MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 第一層：Slave 仍需收到 `LOCK`、進入 `WRS_S_LOCK`。
- 本輪功能判準：DCO probe 的 `rt_state` 能離開 2，並觀察到 `bus_state=1`、後續 `dco_step_count` 或 transaction completion 變化。
- 最終同步判準：Slave `spll_locked=1、time_valid=1、pps_valid=1` 並與 Master 長時間穩定。

## 編譯結果

- pain 從 GitHub checkout 明確 commit：`6d38dd796c2c48a599e779646325099b96d5cb0f`
- 編譯時間：2026-08-18 04:59:04 至 04:59:46（Asia/Taipei）
- Quartus：Version 17.0.0 Build 595 Standard Edition
- 結果：`Full Compilation was successful`，0 errors、270 warnings
- Fitter：`Successful`
- 新 Slave SOF SHA-256：`1211ff4d145224a865fc05aac06e49ea61f15355593f868bac06b3ec974ca978`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_slave_compile.log`
- Compile log SHA-256：`fbf190272ab4c8d57d223ff6376f3f8487c373a14be3d3031eebef07ba809e37`
- Timing：`TIMING_CLOSED=NO`；worst setup `-0.423 ns`、worst hold `-3.558 ns`。
- 主要 critical warning 仍為 timing requirements not met 與未使用 transceiver channel；本輪只改 DCO request hold，沒有宣稱 timing closure。

本段只代表 compile/Fitter 成功，不代表已燒錄或同步成功。

## 燒錄結果

- 燒錄時間：2026-08-18 05:00:32 至 05:00:50（Asia/Taipei）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- 使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`1211ff4d145224a865fc05aac06e49ea61f15355593f868bac06b3ec974ca978`
- Programmer checksum：`0x30A22D41`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818/program_slave_start_hold.log`
- Programmer log SHA-256：`3f397dc3cdf445c50493b6ef3ad4f3a0059a623bc823e44ffe2cb627f293d00a`

這只證明 start-hold SOF 已成功載入；Slave runtime 與兩片同步仍待觀測。

## JTAG/runtime 原始結果

### 燒錄後 10 秒雙板觀測

- DCO 觀測原始檔：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818/dco_activity_1s.log`
- DCO 觀測 SHA-256：`b32d89b443abc764bcd3e837d52ab5ed72ff5eb29fa14842ee15243e33806c2c`
- runtime 觀測原始檔：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818/runtime_10x1s.log`
- runtime 觀測 SHA-256：`f29fbc3c1359cf224ef6ffec7fa92dd458bdac6349ae78215d0780d1952ce37b`
- Master：10/10 筆觀測通過讀取，維持 `status_low=FF` 為主、`wr_mode=2`、`time_valid=1`、`pps_valid=1`。
- Slave：9/10 筆觀測讀取完成，1 筆重試後仍未接受；可讀到 `marker=0x0000B004`，但沒有得到穩定的 `spll_locked=1/time_valid=1/pps_valid=1`。
- DCO probe 在 start-hold 版本已離開先前的 `rt_state=2` 卡住狀態；第一次燒錄後讀值曾為 `DCO_ACTIVITY A=00A8000000400320 B=00A8000000400320`，表示控制器回到 idle 且步進計數已增加。

### 燒錄後唯讀重測

- DCO 重測原始檔：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818/dco_activity_post.log`
- DCO 重測 SHA-256：`1e08d0bfc3cf91a01ac26aaf67a199e6f30e86e20af12802cf163698032607ca`
- DCO 重測原始輸出：`DCO_ACTIVITY A=00A8000002A00320 B=00A8000002A00320`
- DCO 重測重點：兩次讀值相同，`rt_state=0`；步進活動計數仍比前一次增加，表示 runtime request 已能被 controller 消化，但這個 probe 不等同於 SoftPLL lock。
- runtime 單次重測原始檔：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-START-STRETCH-20260818/runtime_single_post.log`
- runtime 單次重測 SHA-256：`4630e8db42d8c026c89d6ace67c2d942eb8a294ad6612e961c063e8068714ce4`

單次重測的原始關鍵值如下：

```text
Master: marker=0x0000B004
        WDIAGS_PTP_META=02010204
        WDIAGS_MODE=2
        WDIAGS_PTP_RX=00000DCA
        WDIAGS_PTP_TX=0000239E
        PPS_ESCR=0000090C

Slave : marker=0x0000B004
        WDIAGS_PTP_META=03010204
        WDIAGS_MODE=3
        WDIAGS_PTP_RX=00000003
        WDIAGS_PTP_TX=00000003
        PPS_ESCR=00000000
        WDIAGS_SSTAT=00000000
        WDIAGS_PSTAT=00000001
        WDIAGS_UCNT=00000000
```

本次 JTAG 命令本身由 Quartus Prime SignalTap II 17.0 執行成功，沒有把「讀值成功」誤當成「Slave 同步成功」。

## Observation

1. runtime start hold 已改善前一輪最明確的問題：DCO controller 不再固定停留在 `rt_state=2` 且 `bus_state=0` 的表面狀態，且步進活動計數持續變化。
2. 但是 Slave 的 `PPS_ESCR` 仍為 0，`SSTAT=0`、`PSTAT=1`、`UCNT=0`，而 PTP RX/TX 只在 3 左右；這與 Master 持續增加的 PTP RX/TX 及有效 PPS 不同。
3. 因此目前證據支持「DCO transaction 可以被啟動/執行」，但不支持「DCO 輸出、SoftPLL feedback 與 WR time-valid gating 已形成閉迴路」。
4. 10 秒觀測中的部分 Slave frame 不一致，且單次重測仍回到 `MODE=3`、`PPS_ESCR=0`；這些結果需要保守解讀為尚未達成穩定 servo，而不是直接判定某一個 register 或硬體根因。

## Conclusion

本輪唯一修改的 start-hold 變因已通過 compile、Fitter 與 JTAG programming，且 DCO probe 顯示 controller 可回到 idle、step counter 有活動；所以它改善了「runtime start 沒有跨到 I2C clock domain」這個候選問題。

但目前仍不能宣稱 Slave servo 成功或兩片 DE5a 已同步。現有證據把問題進一步收斂到：Slave 在收到 WR lock/parent 後，DCO/時鐘回授或後續 `PPS_ESCR -> SoftPLL -> time_valid` 路徑仍未建立。Master role 沒有被修改，仍以歷史成功的 `9f848ec` baseline 為準。

## Next Step

保留目前 SOF 與 runtime log 作為基線。下一輪仍只改 Slave 一個變因，優先檢查 DCO transaction 完成後是否真的寫入預期 SI5340 runtime register，以及 DCO controller 的 completion/error 回報；不修改 Master role、PHY、PTP parser 或 servo 演算法。修改前先建立新的實驗紀錄，燒錄後立即補上 programmer 與 JTAG 原始結果。

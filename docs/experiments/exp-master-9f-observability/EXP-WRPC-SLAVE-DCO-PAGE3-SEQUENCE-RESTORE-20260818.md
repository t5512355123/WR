# 實驗紀錄：Slave SI5340 page 3 DCO 序列恢復

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-DCO-PAGE3-SEQUENCE-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only functional A/B
- Git branch：`exp/master-9f-observability`
- 建立時基線 commit：`b375f3a`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

目前 Slave 的 `runtime_start_hold` 已經讓 SI5340 DCO controller 能完成 I2C transaction，但 SoftPLL 仍沒有進入有效回授：`PPS_ESCR=0`、`SSTAT=0`、`UCNT=0`，且 `TAG_VALID_COUNT/REF_COUNT/TRR_WRITE_COUNT` 為 0。

本輪只驗證一個已有歷史 source evidence 的疑點：`N_FSTEP_MSK` 位於 SI5340 page 3 的 register `0x39`，而 FINC/FDEC 位於 page 0 的 register `0x1D`。現行三步序列把 mask 寫在 page 0，可能沒有寫到預期的 divider mask。

## 相較 baseline 的唯一變因

- Master：維持歷史成功的 `9f848ec` exact SOF，不重新燒錄、不改 role。
- Slave：維持目前已驗證可完成 DCO transaction 的 `runtime_start_hold`，只把每次 DCO update 從三筆 page-0 transaction 改成四筆：

```text
page 3 select: 0x0001 = 0x03
page 3 mask  : 0x0039 = N_FSTEP_MSK
page 0 select: 0x0001 = 0x00
page 0 step  : 0x001D = FINC/FDEC
```

- 不改 WR parser、signaling acceptance、PHY、DDMTD、PTP、servo threshold、DCO direction 或 Master role。
- 來源依據：歷史 commit `3dbd164` 與 `5e816ea` 的 page-address 修正；本輪不 cherry-pick 其他歷史 FSM 或 handshake 修改。

## 預定產物與判準

- 沿用 clean-9f MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 主要判準：DCO transaction 可持續完成，且 Slave 的 `TAG_VALID/REF/TRR`、`PPS_ESCR`、`SSTAT`、`UCNT` 開始出現與時間相關的活動。
- 進一步成功判準：Slave `spll_locked=1`，再觀察 `time_valid=1`、`pps_valid=1`，並與 Master 穩定一致。
- 若只看到 DCO step count 增加而上述 SoftPLL 證據不動，仍只能判定 DCO transaction 活動，不能宣稱 servo 成功。

## 修改與編譯結果

- source commit：`9060e4516482e21f894833b71bd5eb0025a981dd`
- pain checkout：detached HEAD，明確指向 `9060e45`；既有未追蹤檔案未修改。
- 編譯時間：2026-08-18 05:17:41 至 05:20:52（pain terminal 時間）
- Quartus：Version 17.0.0 Build 595 Standard Edition
- 結果：`Full Compilation was successful`，0 errors、271 warnings
- Fitter：successful，0 errors、17 warnings
- Assembler：successful，0 errors、1 warning
- SOF SHA-256：`1e315904af9033f52551a68844a4fd274a8506f13523c10cc0b3fd570c0d494b`
- MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_slave_page3_compile.log`
- Compile log SHA-256：`0f1d5e1af4bb650513f74acd61fab37ac3635942cf6ef93882178d7b15ad022f`
- Timing：各 corner 中最差 setup `-0.825 ns`、最差 hold `-4.016 ns`；Quartus 明確報告 timing requirements not met。本輪只驗證功能變因，不宣稱 timing closure。

## 燒錄結果

- 燒錄時間：2026-08-18 05:23:48 至 05:24:06（pain terminal 時間）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- 使用 SOF：`/home/b10504072/04_WR/quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`
- SOF SHA-256：`1e315904af9033f52551a68844a4fd274a8506f13523c10cc0b3fd570c0d494b`
- Programmer checksum：`0x30A4F803`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-PAGE3-SEQUENCE-RESTORE-20260818/program_slave_page3.log`
- Programmer log SHA-256：`98332239178f3d5b2efe2319f2602174d7f846b2bafc3ab96947aa6cd672d328`

這證明 page3 sequence SOF 已成功載入 Slave；尚未證明 runtime 或時間同步成功。

## JTAG/runtime 原始結果

- 唯讀觀測時間：2026-08-18 05:24 後，10 次、每次間隔 1000 ms。
- 原始 runtime log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-PAGE3-SEQUENCE-RESTORE-20260818/runtime_page3_10s.log`
- Runtime log SHA-256：`d66281c326c93e9881fa4f0db070c915e4043205de41631022cf3bbced97906d`
- Master：10/10 筆 frame accepted；最後一筆 `status_low=FF`、`wr_mode=2`、`link_up=1`、`time_valid=1`、`pps_valid=1`、`WDIAGS_PTP=6`，`TAG_COUNT=0x01C5446A`、`TAG_VALID_COUNT=0x01C5446A`、`TRR_WRITE_COUNT=0x01C5446A`、`PPS_ESCR=0x00000E0C`。
- Slave：10/10 筆 frame accepted；最後一筆 `status_low=EF`、`wr_mode=3`、`link_up=1`、`time_valid=0`、`pps_valid=1`、`WDIAGS_PTP=6`，`WDIAGS_SSTAT=0`、`WDIAGS_PSTAT=1`、`WDIAGS_UCNT=0`、`PPS_ESCR=0`，主要 `REF_COUNT=0`、`TAG_COUNT=0`、`TRR_WRITE_COUNT=0`。
- JTAG/SignalTap 讀取命令成功完成；frame retry 仍存在，但沒有因讀取失敗而把資料誤判為同步成功。

## Observation

1. page3 sequence SOF 已成功載入，且 10/10 筆 Master 與 Slave frame 都可在重試機制下接受。
2. Master 維持歷史 baseline 的有效狀態，證明本輪沒有破壞 Master role 或其 SoftPLL 活動。
3. Slave 的主要 SoftPLL event counters、PPS_ESCR、SSTAT、UCNT 仍沒有活動；因此 page3 register addressing 修正沒有在本次 10 秒觀測中產生可見的 servo progress。
4. Slave 的 parent/WR flags 在不同 frame 間仍有變化，故目前不能把問題簡化成「只差一個 page address」；page sequence 不是已證實的修復。

## Conclusion

本輪唯一變因已完成 compile、燒錄與唯讀 runtime 實驗，但結果為未改善：**尚未證明 Slave servo 成功，也尚未證明兩台 DE5a 已同步。**

證據支持的結論是：

- Master 仍是 `mode=2/status=FF/time_valid=1/pps_valid=1`。
- Slave 仍停在 `mode=3/status=EF/time_valid=0`，主要 SoftPLL tag/ref/TRR event 沒有進入有效活動。
- `runtime_start_hold` 與 page3 sequence 兩項修正目前都只證明 DCO controller/I2C transaction 層可運作，尚未證明量測事件已進入 Slave SoftPLL feedback loop。

## Next Step

保留本輪 SOF、programmer log 與 runtime log 作為負結果基線。下一輪仍只改 Slave 一個變因，優先釐清「Slave 是否真的收到並產生可供 SoftPLL 使用的 tag/ref event」，再決定是否保留 page3 sequence；不得修改 Master role。下一次燒錄另建新的 Experiment ID，並在燒錄後立即記錄。

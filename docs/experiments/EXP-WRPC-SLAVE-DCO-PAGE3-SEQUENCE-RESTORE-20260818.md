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

本節待完成。燒錄後立即記錄 programmer 原始輸出、JTAG cable、JTAG ID、programmer checksum、SOF hash 與 log hash。

## JTAG/runtime 原始結果

本節待完成。至少保存 Master/Slave 的 `status_low`、`wr_mode`、`link_up`、`time_valid`、`pps_valid`、`WDIAGS_PTP`、`WDIAGS_SSTAT`、`WDIAGS_PSTAT`、`WDIAGS_UCNT`、`PPS_ESCR`、`TAG_VALID_COUNT`、`REF_COUNT`、`TRR_WRITE_COUNT` 與 frame validity。

## Observation

本節待補原始結果與觀察，compile 成功不能代替硬體實驗證據。

## Conclusion

本節只能依燒錄後的實際 JTAG 結果撰寫；在結果出現前，不宣稱 Slave servo 或兩台 DE5a 同步成功。

## Next Step

依照本輪結果決定是否保留此 page sequence，或回到上一個可重現 baseline。任何下一次燒錄都建立新的 Experiment ID 並立即記錄。

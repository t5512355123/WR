# EXP-WRPC-STEP4-ARBITRATION-20260820

## 實驗基本資料

- 實驗日期：2026-08-20
- 實驗分支：`exp/step4-softpll-enable`
- 燒錄來源 commit：`cbc4cb951bfaa514f4cc4330d2e71a57be2bf0f5`
- 實驗名稱：Step 4 SoftPLL event 到 request/grant 的唯讀 arbitration discriminator
- 實驗性質：唯讀觀測；沒有修改 SoftPLL 控制行為、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 演算法

## 想驗證什麼

前一輪已看到 DDMTD/deglitch event 與 `tags_p` 的歷史累積計數，但尚未知道目前 runtime 的第一個停點是在：

`DDMTD event -> tags_p -> tags_req -> tags_grant_p -> tag_valid -> TRR write`

本次新增 `SPLL_TAG_PENDING_COUNT` 與 `SPLL_TAG_GRANT_COUNT`，並以 10 次 time-series 觀測，嘗試判斷是否可以把 blocker 收斂到 request/grant arbitration。

## 相較 baseline 唯一修改

相較上一個已燒錄版本，本次燒錄的 `cbc4cb9` 只增加兩個 SoftPLL 唯讀 counter：

- `0x001002A8`：`tags_req` 非零的 `clk_sys` cycle count
- `0x001002AC`：`tags_grant_p` 非零的 arbitration grant 次數

這兩個 counter 只從內部訊號取樣，不回饋 SoftPLL 狀態機。

## Build 與 provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`18af33a5f1ec606df5fd4edba724239325c59538db84a75c4f7f4b6d93ea0b20`
- Slave MIF SHA256：`571b3981b6845ba4b92f7f4abff4c468e1724f909c62aad54569b686aa132786`
- Master SOF SHA256：`1c38b1e8145acbf4f7f3904f13ec543a9319d9924e6d0ca0122f47c526ecf3ed`
- Slave SOF SHA256：`786c0957a1812911b23d8d635764f9fb323cc8c692986acc4076696d02ccd0ea`
- Master timing：compile successful，`TIMING_CLOSED=NO`，worst setup slack `-0.181 ns`
- Slave timing：compile successful，`TIMING_CLOSED=NO`，worst setup slack `-0.200 ns`

完整 build 與 hash 證據見同一資料夾的 build info、build log 與 `sof_mif_hashes_20260820.txt`。

## 燒錄結果

### Master

- JTAG cable：`DE5 [1-11.1]`
- Programmer checksum：`0x30A384E4`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

### Slave

- JTAG cable：`DE5 [1-11.2]`
- Programmer checksum：`0x30A32411`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

原始燒錄輸出為 `program_jtag_master_arbitration_20260820.log` 與 `program_jtag_slave_arbitration_20260820.log`。

## JTAG 原始結果

完整輸出保存在 `jtag_step4_arbitration_20260820.log`、`jtag_step4_arbitration_timeseries_20260820.log` 與 `jtag_runtime_arbitration_20260820.log`。

10 次 event-chain time-series 的穩定觀察：

| 觀測項目 | Master | Slave |
|---|---:|---:|
| DMTD reference/feedback event count | 非零、`seen=1` | 非零、`seen=1` |
| `TAG_PENDING_COUNT` delta | 0 | 0 |
| `TAG_GRANT_COUNT` delta | 0 | 0 |
| `TAG_VALID` shadow | 0 | 0 |
| `TRR_WRITE` shadow | 0 | 0 |
| `SPLL_STATE` | `0x00020009` | `0x00030009` |

runtime snapshot 另顯示：

- Master：CPU `reset=0/fault=0/im_valid=1`、marker `B004`、`PTP=6`、PTP RX/TX `0x55/0xB7`、但 `MODE=0`。
- Slave：CPU `reset=0/fault=0/im_valid=1`、marker `B004`、`PTP=8`、PTP RX/TX `0xB8/0x40`、`FOREIGN_META=03000001`、`MODE=3`。
- 兩板 status probe 都顯示 PHY/link 相關低位條件通過，且 `RXERR=0`。

## Observation

1. 本次沒有看到 1 秒間隔內新的 DDMTD event counter 增量；只有啟動早期累積值與 `seen=1`。
2. 因此 `TAG_PENDING_COUNT=0` 與 `TAG_GRANT_COUNT=0` 不能證明 arbiter 壞掉，因為目前沒有證據顯示有新的 upstream `tags_p` event 送進 request path。
3. `TAG_VALID=0` 與 `TRR_WRITE=0` 與目前 upstream event quiescent 的現象一致。
4. Master `MODE=0`、Slave `PTP=8` 沒有重現歷史 Step 3 baseline 的 Master `MODE=2`、Slave `PTP=9`，因此本次 fresh HEAD runtime 也不能宣稱完整重現歷史 role baseline。

## Conclusion

- Compile：PASS。
- 雙板 programming：PASS。
- JTAG read-only script：PASS，且能讀到新增 arbitration registers。
- Step 4 SoftPLL Enable：**NOT PASS**。
- 證據支持的最保守定位是：DDMTD/deglitch 與 `tags_p` 曾在啟動期間有過活動，但本次觀測窗口沒有新的 upstream event；目前尚不能把第一個 blocker 定位為 request/grant arbitration。
- 這次結果不支持 SoftPLL 已 enable、已進入 helper/main correction，亦不支持 SoftPLL lock 或 White Rabbit time valid。

## Next Step

在不改變任何 SoftPLL functional 行為的前提下，加入下一輪唯讀 discriminator：current `clk_sys` tick、DDMTD ref/fb last-event tick、`tags_p` ref/fb last-event tick、`tags_req` ref/fb cycle count 與 last-event tick，以及 grant/tag_valid/TRR last-event tick。

用 `current_tics - last_event_tics` 區分「剛剛仍在活動」與「只在 startup 活動過」。下一輪仍需先 commit，再由 pain 以 exact commit fresh build、clean compile、program 後觀測；不得把 compile 成功或 historical SOF 成功當作 Step 4 PASS。

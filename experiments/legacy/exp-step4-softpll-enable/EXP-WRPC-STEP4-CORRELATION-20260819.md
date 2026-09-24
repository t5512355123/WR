# EXP-WRPC-STEP4-CORRELATION-20260819

## 實驗識別

- 實驗名稱：Step 4 SoftPLL helper correlation 唯讀觀測
- 日期：2026-08-19
- Branch：`exp/step4-softpll-enable`
- Git commit：`5c291cdea18849bfe9d14b231024299e1acb517f`
- 實驗目的：在不改變 SoftPLL 演算法或控制參數的前提下，同時觀察 raw tag、expected tag、未箝位 helper error、tag delta、`DAC_HPLL` 與 DCO request，找出 helper lock=0 的第一個異常節點。

## 相較前一版本的唯一修改

本次只加入唯讀 observability：

- 在 WDIAGS shadow registers 增加 helper correlation 欄位。
- JTAG 腳本增加 `RAW_TAG`、`EXPECTED_TAG`、`PRECLAMP_ERROR`、`TAG_DELTA`、`EXPECTED_DELTA`、`DAC_HPLL` 與 `DAC_MAIN` 輸出。
- WDIAGS RAM 擴充至涵蓋 `0x100..0x118`。
- 沒有修改 PI gain、lock threshold、DDMTD polarity、DCO gain、SI5340 演算法或 WR signaling 行為。

## Build provenance

- Quartus：17.0.0 Build 595 (2017/04/25 SJ Standard Edition)
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- 共用 SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`766cac0e9ddd468047a03c3075cab8a9ce0a1cfbb940166cc9d223a21590afb1`
- Slave MIF SHA256：`1a95d3ef99262ba080ffb91ba640e27455d782073508c684243fb15cfa2c8179`
- Master SOF SHA256：`de3d593aebb42b10b278b840d3f9ec392b246630827393a7025daa711dda8af8`
- Slave SOF SHA256：`d76b0fcc9085dae152a19224be4cb409db4c466bd85fb63e99b4e5d91a4e3a38`
- Master programmer checksum：`0x30A45305`
- Slave programmer checksum：`0x309FEEBA`
- Build log：pain `build/artifacts/EXP-WRPC-STEP4-CORRELATION-20260819/build_master_full.log`、`build_slave_full.log`

## 燒錄結果

- Master：成功，`DE5 [1-11.1]`，`Configuration succeeded`，0 errors。
- Slave：成功，`DE5 [1-11.2]`，`Configuration succeeded`，0 errors。
- Programmer 原始輸出：pain `build/artifacts/EXP-WRPC-STEP4-CORRELATION-20260819/program_master.log`、`program_slave.log`

## JTAG runtime 結果

### Step 1～3 regression check

fresh SOF 燒錄後的 snapshot 顯示：

- Master：`cpu reset=0`、`fault=0`、`im_valid=1`、marker=`B004`、PTP=`6`，PTP RX/TX 有活動。
- Slave：`cpu reset=0`、`fault=0`、`im_valid=1`、marker=`B004`、PTP=`9`，PTP RX/TX 有活動。
- Slave：`FOREIGN_META=03000001`。
- 兩端 status probe 的 PHY/link 相關 bit 維持 healthy，沒有看到本次 observability 修改造成 Step 1～3 regression。

### SoftPLL helper correlation

Slave correlation 30 samples、約 1.2 秒間隔的主要結果：

- `LOCK_ENABLE=4`、`RCER=1`、`SPLL_STATE=00030004`，表示 SoftPLL slave channel 已 enable，sequence 仍在 `SEQ_WAIT_HELPER`。
- `REF`、`TAG`、`IRQ`、`TAG_VALID`、`TRR_WRITE` 與 helper update activity 持續增加。
- `HELPER_STATE=00000000`，helper locked 仍為 0；`HELPER_ERROR` 約為 `-150000`，`DCO_DEBUG STEP=0`，沒有觀察到 DCO step。
- correlation 新欄位出現 `RAW_TAG=00004000`、`EXPECTED_TAG=00004000`、`EXPECTED_DELTA=00004000`，但同列 `PRECLAMP_ERROR=800040xx`、`TAG_DELTA=80004000/80000000`、`TAG_SOURCE_RAW=00004000`、`HELPER_UPDATE_COUNT=800040xx`；這些欄位彼此不符合其應有的資料型態與數值關係。

因此這些 `800040xx` 目前只能視為 correlation instrumentation/address mapping 尚未驗證，不能直接當作 helper raw tag measurement 的功能性 root cause。

### 原始資料位置

- `jtag_runtime_snapshot.log`
- `jtag_hpll_helper_correlation_30x1200ms.log`
- `jtag_timeseries_30x1000ms.log`
- `program_master.log`
- `program_slave.log`

以上檔案位於本目錄；pain 端亦保留於 `build/artifacts/EXP-WRPC-STEP4-CORRELATION-20260819/`。

## 目前結論

目前可以確認：`5c291cd` 已完成 fresh firmware build、Quartus clean compile、雙板 fresh SOF 產生與成功燒錄；Step 1～3 沒有觀察到 regression；SoftPLL channel 已 enable 且有 tag/IRQ/servo activity，但 helper 尚未 locked、sequence 尚未離開 `SEQ_WAIT_HELPER`，因此 Step 4 尚未 PASS。

目前第一個可靠 blocker 先定位在「helper lock 前的 measurement/correlation chain」，但新增欄位本身仍有不自洽的證據，尚不能在 reference/tag measurement 與 instrumentation mapping 兩者之間做最後選擇。

## 下一步

1. 在不改演算法的前提下，補讀 helper 內部 `p_adder`、`tag_d0`、`p_setpoint`、`ref_src` 與 raw TRR tag，驗證目前 correlation 欄位的位址/資料對齊。
2. 重新做 bounded read-only correlation，確認 raw tag delta、expected delta、pre-clamp error、`DAC_HPLL`、DCO step/request 的時間關係。
3. 只有在第一個異常節點可被可靠分類後，才允許做一個最小 functional A/B；不調整 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。

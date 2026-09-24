# EXP-WRPC-STEP4-CURRENT-CONTEXT-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-CURRENT-CONTEXT-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- 本機與 pain checkout HEAD：`04e744789c487f7a5b9be203954229a0ec4e48aa`
- 實驗類型：唯讀 JTAG runtime audit
- 是否燒錄 FPGA：否
- 是否修改功能 RTL、PTP、SoftPLL、PHY 或 SI5340：否

## 這次要驗證什麼

本次要確認 Step 4 的事件鏈是否在目前已燒錄影像中持續活動：

```text
WRS_S_LOCK
  -> locking_enable
  -> SoftPLL channel enable
  -> DMTD event/tag
  -> TRR/IRQ
  -> helper update
  -> main correction/DCO request
```

本次只讀取既有 JTAG Direct Probe 與 Wishbone mailbox，不寫入任何設定，也不要求 `spll_locked=1` 或 `PSTAT.locked=1`。

## 與 baseline 的唯一差異

沒有功能變更。本次只是使用兩個既有唯讀腳本觀察目前已燒錄影像：

1. `scripts/jtag/read_step4_runtime_context.tcl 10 1000`
2. `scripts/jtag/read_hpll_helper_correlation.tcl 10 1000`

兩個參數分別代表 10 筆樣本、樣本間隔 1000 ms。

## Provenance

本機最新 source HEAD 是 `04e7447`，但本次實機影像仍是先前由 hardware source commit `5400074928104205d857e196dfbb221723592670` 產生的 image。這次沒有重新編譯或燒錄，因此不能把本次 runtime 結果宣稱為 `04e7447` fresh SOF 的結果。

既有 image provenance：

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | `c6b312581d662dfd9861d7c71d7215f9d6c27b17915f2d461c1b04f425280312` | `557bfd5564777a610b62f47d3583958f199026da944e0b5a462d75587d48f39f` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF SHA256 | `d7da711bf5d302bc55df92941281450842ce39858a1150041856da9ba90b379c` | `4bdb11f19815cf4d99b4f7f04242ca3f977b57dc6325ed1e10c07b21e0e0f7ec` |
| Programmer checksum | `0x30A0C7B1` | `0x30A27099` |

- Quartus：17.0.0 Build 595 (04/25/2017 SJ Standard Edition)
- 本次 programmer output：未執行；上表 checksum 來自既有燒錄紀錄。

## 原始資料

- [runtime-context raw log](./jtag_step4_runtime_context_20260820.log)
  - SHA256：`47A5E61A8821AD38A26B95522EB84D85B9BA96EED57ECDC53E04C7D0F031BD4A`
- [HPLL/helper correlation raw log](./jtag_step4_hpll_helper_20260820.log)
  - SHA256：`5DE39D74D19DB956F819A883D559B87010879D11E5EC2C7F9FF5AF73C459071A`

兩次腳本均由 pain 執行，完整 Quartus 結束訊息也保留在 raw log 中。

## JTAG 原始結果摘要

### Master：DE5 [1-11.1]

`read_step4_runtime_context.tcl` 的 10 筆樣本中：

- `PTP=00000006`
- `FOREIGN_META=0000FF00`
- `LOCK_ENABLE=00000000`
- `SPLL_STATE=00020009`（大多數樣本）
- `OCER=00000001`、`RCER=00000000`
- `TAG_VALID=00000000`
- `TRR_WRITE=00000000`
- `REF=00000000`、`TAG=00000000`
- `IRQ=00000000`（少數樣本的 mailbox 讀值需保守看待）
- `HELPER_UPDATE=00000000`
- `CURRENT_TICS` 持續增加
- `INIT_COUNT=00000001`、`CLEAR_DACS_COUNT=00000001`

`read_hpll_helper_correlation.tcl` 無法在此板找到 In-System Sources and Probes instance，因此該腳本的 Master HPLL 欄位不採信；這是觀測工具/影像 probe mapping 不一致的限制，不是 Master SoftPLL 根因證據。

### Slave：DE5 [1-11.2]

`read_step4_runtime_context.tcl` 的 10 筆樣本中：

- `PTP=00000009`
- `FOREIGN_META=03000001`
- `LOCK_ENABLE=00000004`
- `SPLL_STATE=00030009`（少數 mailbox 讀值異常列不作根因判斷）
- `OCER=00000001`、`RCER=00000001`
- `TAG_VALID=00000000`
- `TRR_WRITE=00000000`
- `REF=00000000`、`TAG=00000000`
- `IRQ=00000000`
- `HELPER_UPDATE=00000000`
- `CURRENT_TICS` 持續增加
- `INIT_COUNT=00000004`、`CLEAR_DACS_COUNT=00000001`

`read_hpll_helper_correlation.tcl` 的 Slave 觀測顯示：

- `UCNT` 約從 `0x255` 增加到 `0x259`，但中間有一筆不可信的跳變為 `0`
- `TAG_VALID=0`、`TRR_WRITE=0`
- `DCO_DEBUG=0x0000000000000220`、`STEP=0`
- `DAC_HPLL=0x01000000`、`DAC_MAIN=0x01000000`
- helper correlation shadow 多數為 0

由於 mailbox 逐欄位讀取可能跨越 firmware refresh 邊界，`UCNT` 的小幅活動只能作為「有部分 firmware polling/update 活動」的輔助證據；不能取代 tag/TRR 的連續活動證據。

## Observation

目前最早可直接觀察到的停滯點是在：

```text
SoftPLL DMTD event
  -> tag_valid
  -> TRR write / IRQ
```

理由是 10 秒時間序列中 `CURRENT_TICS` 持續前進，但 `TAG_VALID`、`TRR_WRITE`、`REF`、`TAG` 與 `IRQ` 沒有形成持續增加的趨勢；Slave 雖然有 `LOCK_ENABLE=4` 與 `RCER=1`，但這只證明 enable call/位元設定曾發生，不能證明事件資料已進入 helper/main loop。

## Conclusion

本次不能標示 Step 4 PASS。證據支持以下較保守的結論：

1. Slave 已具備 Step 3 的 PTP/parent context：`PTP=9`、`FOREIGN_META=03000001`。
2. Slave 有 `LOCK_ENABLE=4`、`RCER=1`，表示 SoftPLL enable 路徑至少已被呼叫並寫入過 ref channel enable。
3. 尚未證明 DMTD/tag/TRR/IRQ、helper correction、main correction 或 DCO request 持續工作。
4. 目前最早可觀察的 inactive boundary 是 DMTD event 到 tag/TRR 的上游邊界；但因為本次硬體仍是 historical `5400074` image，不能把它直接定為 RTL/PHY/clock 的根因。
5. Master 的 HPLL 腳本 probe error 也表示目前影像與診斷腳本的 probe mapping 需要先做 provenance 對齊。

## Next Step

先不修改 PI、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。下一步應是：

1. 以目前 branch 的 exact HEAD `04e7447` 從 clean checkout 建立 firmware 與 fresh MIF。
2. 執行 `quartus_sh --clean` 後，以 Quartus 17.0 fresh compile 產生新的 Master/Slave SOF。
3. 保存 MIF/QSF/SDC/SOF SHA256、compile log 與 programmer log。
4. 兩板燒錄 fresh HEAD image 後，重新執行本次兩個唯讀腳本。
5. 只有在 fresh HEAD image 仍重現「`LOCK_ENABLE/RCER` 有效但 tag/TRR 不活動」時，才進入下一個單一功能變因的 A/B 設計。


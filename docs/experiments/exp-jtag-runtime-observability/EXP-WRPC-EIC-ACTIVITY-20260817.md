# 實驗：EXP-WRPC-EIC-ACTIVITY-20260817

## 實驗名稱

`a5d19ae 加入 SoftPLL EIC 狀態唯讀診斷`：讀取 EIC（Event/Interrupt Controller，事件/中斷控制器）的 mask 與 status，判斷 SoftPLL tag interrupt 是否在 EIC 端出現。本次只增加唯讀 mailbox 欄位，不改變 WR 控制流程。

## 日期與版本

- 日期：2026-08-17
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`a5d19aec68b031c018b4e50407cb9d932cf6af7e`
- GitHub：`git@github.com:t5512355123/WR.git`
- pain checkout：detached HEAD，明確指向上述 commit
- Quartus：`17.0.0 Build 595`
- 本次沒有 reboot 或實體斷電；先燒 Slave，再燒 Master

## 這次想驗證什麼

前一輪已確認 clock domain 有活動，但 Slave 的 SoftPLL activity shadow 仍為 0、sequence 停在 `SEQ_CLEAR_DACS`，且 `IRQ_COUNT=0`。本次讀取：

- `SPLL->EIC_IMR`：目前 interrupt mask 狀態
- `SPLL->EIC_ISR`：目前 interrupt status 狀態

source 中 `irq_inputs_vector_int(0) <= irq_tag_i`，因此 bit 0 是 tag interrupt 對應的 EIC input。這次要判斷 tag interrupt 是否已到 EIC 層，不把 EIC status 單獨當成 SoftPLL lock 證據。

## 相較 baseline 唯一修改了什麼

1. 將 `EIC_IMR` 寫入 mailbox `0x001009F0`。
2. 將 `EIC_ISR` 寫入 mailbox `0x001009F4`。
3. `IRQ_COUNT`、`IRQ_MASK`、`IRQ_STATUS` 一起納入 `WR_SPLL_ACTIVITY` 輸出與 frame validity。
4. 更新 JTAG register map 文件。

沒有修改 PHY、lane、polarity、line rate、PTP filter、servo、SoftPLL sequence、SI5340、PPS 或任何控制參數。

## 建置與 artifact

pain 從 GitHub fetch 後 checkout 明確 commit `a5d19ae`，Master 與 Slave 均完成 Quartus full compilation；兩端 build script 都回報 `Quartus build passed`，但 timing closure 仍為 `NO`。

Master artifact：

- QSF SHA256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`c130e53444058ceabf49f0c0f250a5b97b7e01e2bbe297eff1dc44cd77cac5ad`
- SOF SHA256：`a9ec51a1fdd6d0745633c4560ee0ce959e8fea0c5428927339c403729c177c00`
- worst setup slack：`-2.974 ns`
- worst recovery slack：`-1.833 ns`

Slave artifact：

- QSF SHA256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`0e040519516bc519dd12e6c09496990015fb7c2332f490941e2090fca92bd88f`
- SOF SHA256：`63f41c1b6ea0e3ba77fad4ae71867952d3424e19a5e6abdbc0053435feb8520f`
- worst setup slack：`-3.081 ns`
- worst recovery slack：`-1.862 ns`

## 燒錄結果

Slave 使用 cable `DE5 [1-11.2]`，programmer checksum `0x30A5A13F`，回報 `Configuration succeeded -- 1 device(s) configured` 及 `0 errors, 0 warnings`。

Master 使用 cable `DE5 [1-11.1]`，programmer checksum `0x30ABDD91`，回報 `Configuration succeeded -- 1 device(s) configured` 及 `0 errors, 0 warnings`。

燒錄原始 log：

- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-EIC-ACTIVITY-20260817/program_slave.log`
  - SHA256：`EEF8DE8920ECB99F87F53D55AE8A544C68EE1535FA8548EFB3177505F864B72B`
- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-EIC-ACTIVITY-20260817/program_master.log`
  - SHA256：`D3BFB06AED494A8E7119078B2FAE5C677F994FC844FF5834F863C90E22E943F1`

## JTAG/runtime 原始結果

使用兩張板同一 JTAG session，每秒取樣一次，共 60 個 sample。pain terminal 回報：`SESSION_TIME_SERIES_DONE`、Tcl evaluation successful、SignalTap successful、`0 errors, 0 warnings`。

完整 runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-EIC-ACTIVITY-20260817/runtime_60samples.log`

- SHA256：`AF22BF0EB164D5A37FD450DDAA1F94D8909986D90FBAF691415FDCDEFF8FD25D`
- Master：`53/60` accepted；其餘由 frame consistency/retry 規則排除
- Slave：`60/60` accepted

所有 frame-valid 的 `WR_SPLL_ACTIVITY` rows 都一致：

- Master 53 筆、Slave 60 筆
- `REF_COUNT=00000000`
- `TAG_COUNT=00000000`
- `VISIT_MASK=00000200`
- `TRANSITIONS=00000000`
- `LAST_STATE=00000009`
- `IRQ_COUNT=00000000`
- `IRQ_MASK=000003E9`
- `IRQ_STATUS=000003E8`

Slave 的有效狀態為：

- `wr_mode=3`
- `link_up=1`
- `spll_locked=0`
- `time_valid=0`
- `pps_valid` 在取樣期間可為 0 或 1
- `WR_LOCK result=1`、`unlocked=847562`、`calibration_fail=0`
- `seq_state=9`、`align_state=0`
- `WDIAGS_PTP_RX/TX`、parent/foreign 欄位與 clock activity counters 有活動

Master 有效列維持 Master mode，並可觀察到 `time_valid=1`、`pps_valid=1`；這不代表 Slave 已同步。

## Observation

1. EIC mask/status 的讀值在有效列中穩定；Slave 的 mask bit 0 為 1，而 status bit 0 為 0，因為 `0x000003E8 & 0x1 = 0`。依 source mapping，這表示取樣當下沒有觀測到 tag input 對應的 pending EIC status。
2. `IRQ_COUNT=0`、`TAG_COUNT=0`、`REF_COUNT=0`、`TRANSITIONS=0` 與 `LAST_STATE=9` 同時成立；沒有證據顯示 SoftPLL firmware handler 曾處理 tag FIFO。
3. `IRQ_STATUS=0x3E8` 仍包含其他 EIC status bits，因此不能把整個 ISR register 說成全零，也不能只因 status 非零就宣稱 tag IRQ 已經到達；必須依 bit 0 mapping 解讀。
4. `TRR_CSR=0x00020100` 的 empty 狀態與本次沒有 tag FIFO 被消費的觀測一致，但它仍只是讀取當下狀態，不是 raw FIFO write trace。
5. PTP、parent/foreign 與三個 clock activity counter 仍有活動，因此沒有證據支持 CPU、PTP path 或所有 clock domain 完全停止。

## Conclusion

目前證據支持的保守結論是：

> 本次 EIC 唯讀觀測確認 interrupt controller 的 mask/status 可以讀回，且 Slave tag interrupt 對應的 EIC bit 0 在取樣列中沒有 pending status；同時 firmware `IRQ_COUNT`、tag/ref shadow 與 SoftPLL state 都沒有前進。問題優先收斂到 tagger 沒有產生有效 tag、tag FIFO write 沒有發生，或 tag input 到 EIC bit 0 之前的硬體路徑；尚不能宣稱唯一根因已確定。

這次 compile 與燒錄成功，但 Slave 仍為 `spll_locked=0`、`time_valid=0`，所以不能宣稱兩端已完成 White Rabbit 時間同步。

## Next Step

1. 維持 PHY、PTP、servo、SoftPLL 控制與 SI5340 設定不變。
2. 下一個單一變因只加入 raw `irq_tag_i` 或 tag FIFO write event 的硬體唯讀計數器，並透過既有 valid-frame 方式讀回。
3. 若 raw tag/FIFO write 也為 0，往 recovered RX 到 DMTD tagger 的輸入與 tag 產生條件查；若 raw event 增加但 EIC bit 0 不增加，再查 tag FIFO 到 EIC route。
4. 在取得 raw event 證據前，不修改 pre-emphasis、QSFP port、polarity、PTP 演算法、servo threshold 或 SI5340 控制。

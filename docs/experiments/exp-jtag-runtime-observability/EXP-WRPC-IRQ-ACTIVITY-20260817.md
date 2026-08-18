# 實驗：EXP-WRPC-IRQ-ACTIVITY-20260817

## 實驗名稱

`18614cf 加入 SoftPLL 中斷次數唯讀診斷`：觀察 SoftPLL ISR（Interrupt Service Routine，中斷服務程式）是否曾被呼叫，區分 tag 沒有產生、中斷未送到 CPU，以及 handler 有進入但 FIFO 沒資料。這次只增加唯讀 mailbox 欄位。

## 日期與版本

- 日期：2026-08-17
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`18614cf6b7fb0e07801737ae98a023c049035b0f`
- GitHub：`git@github.com:t5512355123/WR.git`
- pain checkout：detached HEAD，明確指向上述 commit
- Quartus：`17.0.0 Build 595`
- 本次沒有 reboot 或實體斷電；先燒 Slave，再燒 Master

## 這次想驗證什麼

前一輪已確認 QSFPA reference、QSFPB DMTD 與 recovered RX 三個 clock domain 有活動，但 Slave 仍為 `SEQ_CLEAR_DACS`、`REF_COUNT=0`、`TAG_COUNT=0`。本次將既有 `softpll.irq_count` 放到 mailbox `0x001009EC`，確認 `spll_irq_entry()` 是否被執行。

`softpll.irq_count` 在 ISR 處理完 SoftPLL tag FIFO 後累加；它不是 tag 數，也不是 lock counter，只代表 firmware handler 的進入次數。

## 相較 baseline 唯一修改了什麼

1. `wdiags_write_wr_spll_activity_debug()` 新增 `irq_count` 參數。
2. 將 `softpll.irq_count` 寫到 `0x001009EC`。
3. JTAG Tcl 將 `IRQ_COUNT` 納入 frame validity 與輸出。
4. 更新 JTAG register map 文件。

沒有修改 PHY、lane、polarity、line rate、PTP filter、servo、SoftPLL sequence、SI5340、PPS 或任何控制參數。

## 建置與 artifact

pain 從 GitHub fetch 後 checkout 明確 commit `18614cf`，Master 與 Slave 均完成 Quartus full compilation，build script 都回報 `Quartus build passed`；兩端 `TIMING_CLOSED=NO`。

Master artifact：

- QSF SHA256：`e9a5484048fdec5399ba9034f990565e1e52f6ea7e503fb46174d596e5e6b34b`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`9546db5a2d4bd099e75cde512fbf6a2bde8df540e4ae35202dbd9689c4623d2e`
- SOF SHA256：`b9f40430e7f60cee51e45ad81d4bf4b1a261ad3980dd21489a2c5fa9891ded6f`
- worst setup slack：`-2.974 ns`

Slave artifact：

- QSF SHA256：`199a695e29c9e4fbf5a18bb88cfaa4079ce6858ae83e21628c9c6d2731c03f58`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`01445ef5d5b62e8cd0b0ae9a65439100119693b09066809222301a84518b8ce5`
- SOF SHA256：`740b4cc8dd5065445b10f08a957741064c8e06e576396bc3669ea89afc0fb2b4`
- worst setup slack：`-3.081 ns`

## 燒錄結果

Slave 使用 cable `DE5 [1-11.2]`，programmer checksum `0x30A5A13F`，回報 `Configuration succeeded -- 1 device(s) configured` 及 `0 errors, 0 warnings`。

Master 使用 cable `DE5 [1-11.1]`，programmer checksum `0x30ABDD91`，回報 `Configuration succeeded -- 1 device(s) configured` 及 `0 errors, 0 warnings`。

燒錄 log：

- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-IRQ-ACTIVITY-20260817/program_slave.log`
  - SHA256：`b2a10d573baf95c4667a01e8e962698e60ef5a88aba608466c4696fd7c1e2f27`
- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-IRQ-ACTIVITY-20260817/program_master.log`
  - SHA256：`cd63f59196c09f0cc05869ae347075738be7ba5a790646f7f55a3b39ac420338`

## JTAG/runtime 原始結果

使用兩張板同一 JTAG session，每秒取樣一次，共 60 個 sample。pain terminal 回報：`SESSION_TIME_SERIES_DONE`、Tcl evaluation successful、SignalTap successful、`0 errors, 0 warnings`、`JTAG_RC=0`。

完整 runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-IRQ-ACTIVITY-20260817/runtime_60samples.log`

- SHA256：`8604a79842f90567f128e6e8a3be2b68f6d8a8b0e0627f5f065773b0b0aa83fc`
- Master：57/60 accepted；其餘由 frame consistency/retry 規則排除
- Slave：60/60 accepted

所有 frame-valid 的 `WR_SPLL_ACTIVITY` rows（Master 57 筆、Slave 60 筆）都顯示：

- `REF_COUNT=00000000`
- `TAG_COUNT=00000000`
- `VISIT_MASK=00000200`
- `TRANSITIONS=00000000`
- `LAST_STATE=00000009`
- `IRQ_COUNT=00000000`

Slave 有效狀態為 `status_low=CF` 或 `EF`、`time_valid=0`、`pps_valid=0` 或 `1`、`wr_mode=3`、`link_up=1`、`spll_locked=0`；PTP RX/TX、parent flags 與三個 clock activity counters 仍有活動。

## Observation

1. `softpll.irq_count` 在完整 60 秒有效取樣中維持 0，沒有觀測到 `spll_irq_entry()` 被呼叫。
2. 同一批有效列的 `REF_COUNT/TAG_COUNT` 也維持 0，Slave sequence 仍停在 `SEQ_CLEAR_DACS`。
3. `TRR_CSR` 顯示 FIFO 在讀取當下為 empty；這與沒有 ISR 進入一致，但不是 raw tagger trace。
4. clock domain、PTP 與 parent/foreign master 活動存在，因此沒有證據支持所有 clock 都停止或 CPU/network runtime 完全失效。

## Conclusion

目前證據支持的保守結論是：

> Slave 的 SoftPLL interrupt handler 在本次 60 秒有效樣本中沒有被觀測到進入，問題進一步收斂到 tag event 沒有產生、EIC（Event/Interrupt Controller，事件/中斷控制器）mask/status/route 沒有讓 IRQ 到達 CPU，或更早的 tag FIFO 寫入路徑；證據尚不能在三者間選定唯一根因。

這次 compile 與燒錄成功，但 Slave 仍為 `time_valid=0`，所以不能宣稱 WR 時間同步成功。

## Next Step

1. 保持 PHY、PTP、servo、SoftPLL 控制與 SI5340 不變。
2. 下一個唯讀版本加入 `SPLL->EIC_IMR` 與 `SPLL->EIC_ISR` 的 mailbox shadow，判斷 tag IRQ 是否 pending、是否被 mask。
3. `ISR=0` 且 FIFO empty 時優先查 tagger/FIFO write；`ISR=1` 但 `irq_count=0` 時查 CPU IRQ route/handler；`IMR` 顯示 mask 時查中斷使能狀態。
4. 只有取得 EIC status 後仍無法區分，才加入 raw `irq_tag_i` 或 tag FIFO write event 的硬體 probe；不先修改 WR 控制參數。

# EXP-WRPC-SLAVE-REINIT-20260817：Master 角色修正後重新初始化 Slave

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-REINIT-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗目的：驗證啟動順序/WR handshake 狀態殘留是否造成 Slave 沒有重新進入 SoftPLL lock。
- pain checkout：`e22bb754097a49dfc7ab141091f9c5b0802c9735`
- 先前 Master 硬體 image commit：`9f848ec84b73328daca63b64d2725817e8802e60`
- Slave 硬體 image 的既有 baseline source：`b927e8795a4f45ab80a2e7b1c5d9c3ad475c5415`

## 這次想驗證什麼

前一輪已把 Master 修正為 `WDIAGS_MODE=2/PPS_MASTER`，但 Slave 可能在 Master 角色錯誤期間已經進入 WR handshake fallback。即使新的 Master 已正確，Slave 可能不會因為相同的 parent identity/announce 自動重新啟動 handshake。

本次只重新燒錄既有 Slave SOF，讓 Slave 重新初始化；不修改 RTL、firmware、PHY、PTP、servo 或 SoftPLL 參數。若重新初始化後能完成 `PSTAT.locked=1`、`time_valid=1`，就支持「狀態殘留/啟動順序」假設；若仍在 `WRS_S_LOCK` 失敗，則問題可收斂到 SoftPLL lock feedback 或其前段。

## 相較 baseline 唯一操作變因

只做一個操作變因：

```text
Master 已維持 9f848ec 的正確角色 image
    -> 重新燒錄原本的 Slave SOF
```

沒有重新 compile，也沒有改動任何 source。這不是新的硬體設計版本，而是針對目前已燒錄 image 的初始化順序實驗。

## MIF / SOF / Quartus 識別資料

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master 仍使用前一輪 9f848ec image：
  - MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
  - SOF SHA-256：`c548bab576a61e3102391464e8790aa5dd71ead869cc85199005f5ac2bd7af0d`
- 本次 Slave 使用既有 SOF：
  - SOF SHA-256：`e020cb02a21693a656d4c3d93ce7a1e2d8b1593adca4b079474f4ff4d09ade99`
  - Programmer checksum：`0x309FCFD1`
- 本次沒有重新 compile，因此沒有新的 MIF 產物或新的 timing report；這點不把它誤寫成 compile 實驗。

## 燒錄結果

2026-08-17 04:36:48 至 04:37:06，只燒錄 Slave cable `DE5 [1-11.2]`：

```text
Info (213011): Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x309FCFD1
Info (209007): Configuration succeeded -- 1 device(s) configured
Info (209011): Successfully performed operation(s)
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

Programmer 輸出保存於：

```text
build/artifacts/EXP-WRPC-SLAVE-REINIT-20260817/program_slave.log
```

Programmer log SHA-256：`EACA6E9476B8F84F3101565D00F4A64411152615D828659FB82D9811AE00A17B`

## JTAG/runtime 原始結果

使用既有 `read_wb_runtime.tcl` 唯讀讀取；沒有寫入 `WDIAGS_CTRL.DATA_SNAPSHOT`，也沒有修改任何 WR 控制暫存器。

### 重新初始化後約 8 秒

```text
Master status_probe: A11E9243275082FF
Master WDIAGS_MODE:  2
Master WDIAGS_PTP:   00000006
Master WDIAGS_PSTAT: 00000001
Master WDIAGS_TEMP:  A0219864

Slave status_probe: D11E026127D082EF
Slave WDIAGS_MODE:  3
Slave WDIAGS_PTP:   00000008
Slave WDIAGS_SSTAT: 00000002
Slave WDIAGS_PSTAT: 00000001
Slave WDIAGS_FOREIGN_META:03000001
Slave WDIAGS_DMS_L: 000555AB
Slave WDIAGS_CKO:   93758181
Slave WDIAGS_UCNT:  00000005
Slave WDIAGS_TEMP:  A041135C
```

`WDIAGS_SSTAT=0x00000002` 表示 servo 進入 `WRH_SYNC_NSEC`；`WDIAGS_TEMP=0xA041135C` 的 WR extension state field 為 `2`，對應 `WRS_S_LOCK`。

### 重新初始化後約 23 秒

```text
Master status_probe: D11E926137BC82FF
Master WDIAGS_MODE:  2
Master WDIAGS_PTP:   00000006
Master WDIAGS_PSTAT: 00000001

Slave status_probe: 031E026137BC82EF
Slave WDIAGS_MODE:  3
Slave WDIAGS_PTP:   00000008
Slave WDIAGS_SSTAT: 00000101
Slave WDIAGS_PSTAT: 00000001
Slave WDIAGS_FOREIGN_META:03000001
Slave WDIAGS_DMS_L: 0005942B
Slave WDIAGS_CKO:   95AA7281
Slave WDIAGS_UCNT:  00000018
Slave WDIAGS_TEMP:  A041135C
```

### 約一分鐘觀測後

六次取樣期間，Master 維持 `mode=2/PPS=6/status=0xFF`；Slave 的代表性結果如下：

```text
Sample 1: Slave status=0xEF SSTAT=0x00000101 PTP=8 TEMP=0xA041135C RESTART=0x00000000
Sample 2: Slave status=0xCF SSTAT=0x00000001 PTP=9 TEMP=0xA000035C RESTART=0x02020001
Sample 3: Slave status=0xCF SSTAT=0x00000001 PTP=9 TEMP=0xA000035C RESTART=0x02020001
Sample 4: Slave status=0xCF SSTAT=0x00000001 PTP=9 TEMP=0xA000035C RESTART=0x02020001
Sample 5: Slave status=0xEF SSTAT=0x00000001 PTP=9 TEMP=0xA000035C RESTART=0x02020001
Sample 6: Slave status=0xCF SSTAT=0x00000001 PTP=9 TEMP=0xA000035C RESTART=0x00000000
```

完整 JTAG 輸出保存於：

```text
build/artifacts/EXP-WRPC-SLAVE-REINIT-20260817/runtime_after_reinit.log
```

JTAG log SHA-256：`EB81F20D2839A187D5E5D4F6CC8D62A924774944E8442D772C34F968F4A1E7A1`

## Observation

1. 重新初始化後，Slave 確實重新進入 WR handshake 的 `WRS_S_LOCK`，而不是一直停在初始化前的 idle/fallback；這支持「重新初始化能重新開始 handshake」的局部判斷。
2. Slave 在 `WRS_S_LOCK` 期間有 `DMS/MU/CKO` 與 `UCNT` 活動，但 `WDIAGS_PSTAT=1`，沒有 SoftPLL lock bit。
3. 約一分鐘內 Slave 從 `SSTAT=2/TP=8` 回到 `SSTAT=1/PTP=9`，且 `WDIAGS_TEMP` 回到 `A000035C`，表示 WR extension state 回到 `WRS_IDLE`。
4. `WDIAGS_RESTART=0x02020001` 的欄位解碼為：失敗 role=`WR_SLAVE`、失敗前 WR state=`WRS_S_LOCK`、failure count=`1`。
5. Slave 的 PTP RX/TX 與 foreign/parent metadata 仍有活動；CPU `fault=0`、`marker=0xB004`，因此沒有證據支持 CPU boot 或基本 PTP RX 失效。

## Conclusion

本實驗支持以下結論：

> 重新燒錄 Slave 在 Master 角色修正後，能讓 WR handshake 重新啟動；但 handshake 最後在 `WRS_S_LOCK` 失敗，並回到非同步 fallback。問題已從「Master 啟動順序/Slave 狀態殘留」進一步收斂到 Slave SoftPLL lock feedback 或其前段 tag/DMTD 路徑。

本實驗不支持以下結論：

> 不能宣稱兩片 DE5a 已完成 White Rabbit 時間同步，因為 Slave 沒有 `PSTAT.locked=1`，且 `time_valid` 仍未穩定為 1。

這個結果也不支持 Root Complex、CPU boot 或 PTP packet path 是目前的主要瓶頸。

## Next Step

下一個硬體變因不應再改 Master role 或重複同一個 Slave reset。應回到既有 SoftPLL raw-event 證據，新增或確認只讀觀測：

1. `tags_p(0)` / `tags_p(1)` 是否在 `WRS_S_LOCK` 期間持續增加。
2. `tags_grant_p`、`tag_valid`、TRR FIFO write 與 `trr_wr_full` 的先後關係。
3. `WR_LOCK_RESULT_DEBUG`、`WR_SPLL_STATE_DEBUG` 與 `WR_SPLL_IRQ_*` 是否在 timeout 前明確指出哪一個 lock feedback 沒有成立。

只有取得上述分段證據後，才選擇 DMTD sampled-clock wiring、tag arbitration 或 lock detector 的單一修改。下一次若燒錄，必須建立新的 Git commit，並在燒錄後立即新增實驗紀錄。

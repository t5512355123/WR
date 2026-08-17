# 實驗紀錄：恢復 Slave 已知可進入 lock path 的映像

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-RESTORE-LOCK-PATH-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only 硬體 A/B restore
- Git branch：`exp/master-9f-observability`
- 燒錄前紀錄 commit：`bb4cb3e`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

目前 Master 已固定使用歷史成功的 `9f848ec` SOF。現場 Slave 使用較新的 parser-observability image 時，JTAG 顯示 `WR_SIGNAL rx=0`、`lock_enable=0`，尚未證明進入 `WRS_S_LOCK`。

先前的 clean-9f 配對實驗曾經證明另一份 Slave image 可以收到 Master `LOCK` 並進入 `WRS_S_LOCK`，之後才在 SoftPLL `SEQ_CLEAR_DACS=9` 階段失敗。本輪只恢復那份已知能走到 lock path 的 Slave SOF，藉此區分：

```text
目前 parser-observability image 的 signaling/功能差異
        vs.
已知能進入 WRS_S_LOCK 的 Slave image之後的 SoftPLL問題
```

## 相較 baseline 的唯一變因

- Master：不重新燒錄、不修改，維持 exact `9f848ec`。
- Slave：只由目前的 `3862ff...` parser-observability image 改回保存的 clean-9f Slave image。
- 不修改 source、startup command、Master role、PHY、QSFP、DCO、SoftPLL、SI5340 或 JTAG 控制暫存器。

## 預定使用產物

- 來源 provenance：`18f471070f86eb1ff65534442f8e29cab5520cf8`，base `9f848ec`，observability `584827c`、`302ffc1`
- Slave SOF：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof`
- Slave SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- Slave MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 歷史 programmer checksum：`0x30A3C175`
- JTAG cable：`DE5 [1-11.2]`

## 成功判準

本輪不是同步成功判定。第一層判準是重新看到：

- Slave `WR_SIGNAL rx_msg=0x1001` 或等價的 `LOCK` 接收證據
- `fail_state=2` 或明確的 `WRS_S_LOCK` locking path 證據
- `WR_LOCK enable/polls` 開始增加
- `SEQ_CLEAR_DACS`、tag/TRR activity 可被觀察

只有後續還要看到 `spll_locked=1`、`time_valid=1`、`pps_valid=1` 並長時間穩定，才能宣稱兩張 DE5a 完成同步。

## 燒錄結果

- 燒錄時間：2026-08-18 04:31:40 至 04:31:59（Asia/Taipei）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A3C175`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-RESTORE-LOCK-PATH-20260818/program_slave_restore.log`
- Programmer log SHA-256：`0434ccdb67d410d72a98e886cb1fde300445b47ab1afd2035d76c0daf387b710`

原始 terminal 關鍵結果：

```text
Info (213011): Using programming file .../slave.sof with checksum 0x30A3C175
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

這只證明指定的 Slave SOF 已成功載入，不等於 Slave servo 或兩片同步成功。

## JTAG/runtime 原始結果

待燒錄後以同一份唯讀 `read_wb_timeseries_session.tcl` 取樣，保存 Master/Slave raw log 與 SHA-256。不可把舊 runtime log 當成本輪結果。

## Observation

待補入實際燒錄與 JTAG 證據。

## Conclusion

在實際證據完成前，不宣稱 Slave 進入 lock path，也不宣稱 White Rabbit 同步成功。

## Next Step

若本輪重新看到 `WRS_S_LOCK`，後續只針對 SoftPLL sequence、clock feedback 與 lock detector 做 source audit；若仍停在 `WRS_PRESENT`，則比較兩份 Slave image 的 signaling/state 差異，但 Master 仍保持 freeze。

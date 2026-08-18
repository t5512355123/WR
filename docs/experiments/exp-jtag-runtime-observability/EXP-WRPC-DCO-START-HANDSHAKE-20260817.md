# EXP-WRPC-DCO-START-HANDSHAKE-20260817：DCO I2C 啟動握手修正

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-START-HANDSHAKE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：單一功能變因；只重新編譯、燒錄 Slave，Master 維持 baseline。

## 這次想驗證什麼

驗證上一輪觀測到的 `DCO accepted` 增加但 `done=0` 是否是因為 runtime start pulse 太短，沒有被慢速 I2C state machine 取樣到。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- commit：`af4a96061bcd68cb9c0f5d7a51025bc2a05286c4`
- pain checkout：detached HEAD，固定於 `af4a960`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

只修改 `si5340a_controller_dco.v` 的 runtime state transition：

- state 1、3、5、7 不再看到一個 50 MHz domain 的 `runtime_start` 就立刻離開。
- 改為保持 `runtime_start`，直到 I2C controller 的 `bus_state` 拉高，再進入等待 transaction 完成的 state。
- 沒有修改 SI5340 page/register data、FINC/FDEC direction、SoftPLL、PTP、PHY 或 firmware。

## Build provenance

- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave SOF SHA-256：`861fef83d5bd81afaae4c45401143986932f04199b1ba49a1f95a68d44cca20a`
- Full Compilation：successful，0 errors、273 warnings
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.377 ns`
- Worst hold slack：`-3.502 ns`
- Worst recovery slack：`0.824 ns`
- Worst removal slack：`0.337 ns`

## 燒錄結果

只燒錄 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A34B86
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 06:07:09–06:07:28（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-START-HANDSHAKE-20260817/program_slave.log`
- Programmer log SHA-256：`69e6b22c1837733b2a45d6e4efc12af70d0d97903a2956b8f8a74ba27fb58f11`

## JTAG/runtime 原始結果

### DCO pipeline

燒錄後短讀曾觀察到：

```text
BEGIN_HPLL source=0000 destination=0006 accepted=0003 done=0002
END_HPLL   source=0000 destination=0006 accepted=0003 done=0002
BEGIN_DPLL source=0000 destination=0002 accepted=0001 done=0001
END_DPLL   source=0000 destination=0002 accepted=0001 done=0001
```

這與 baseline 的 `done=0` 不同，表示 start handshake 確實讓至少部分 runtime I2C transaction 完成。

### 20 秒 time-series

- log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-START-HANDSHAKE-20260817/runtime_20s.log`
- SHA-256：`b351f8e6dde5aa138243afddc2bd3272a7e818871738155c7fee423256cd1430`
- 前段/中段開始出現 Slave `PTP_RX=0`、`PTP_TX=0`、`TAG_VALID_COUNT=0`、`TRR_WRITE_COUNT=0`、`UCNT=0`。
- `PSTAT.locked=0`、`time_valid=0`。
- 後段 accepted sample 顯示 `link_up=0`、`foreign_count=0`、`wr_config=0`、`parent_is_wr=0`。
- JTAG Tcl 最終仍成功完成 `SESSION_TIME_SERIES_DONE`，但結果是 runtime/WR link 已不再維持 baseline 活動。

其他原始檔：

- DCO log SHA-256：`58892abcb3c37e667d7a7366fa165f92973730ca56e80adba70281399c468c7a`
- SoftPLL raw log SHA-256：`c0126d872aaa0db79dee20836c667431179373119edd43c3b7b152ec37f3779e`

## Observation

1. 把 start pulse 保持到 `bus_state` acknowledge 後，DCO `done` 確實從 0 變成非零；因此上一輪對「start pulse 太短」的推論有部分支持。
2. 同一個 bitstream 後續 20 秒內，Slave 的 PTP、tag、IRQ、servo update 與 parent activity 掉到 0，且後段 `link_up=0`。
3. 因此「transaction 完成」不等於「transaction 內容正確」；目前不能把這輪當成成功修正。
4. 這輪結果把風險提高到 SI5340 runtime transaction 的實際副作用：可能是 page/register sequence、divider mask、FINC/FDEC direction 或其他 clock control 寫入使 WR feedback clock/PHY runtime 失效。

## Conclusion

本實驗支持：

> runtime start handshake 原本確實可能太短；修正後，DCO controller 能觀察到 transaction done。

本實驗也證明：

> 目前的 runtime transaction 不能直接保留，因為燒錄後 Slave 的 WR runtime/parent/PTP activity 消失，最後 link_up 變成 0，且沒有 `time_valid=1` 或 SoftPLL lock。

本實驗不支持：

> 不能宣稱 Slave 已同步，也不能宣稱只要讓 I2C transaction 完成就能修好同步。

## Next Step

先保留這份失敗證據，不再直接燒錄同一方向的修改。下一步回到 `c5092dd` 的可運作 baseline，並以唯讀或最小風險方式確認 SI5340 runtime write 的 page/register/readback 與 clock effect；若必須再燒錄，需先建立明確的 rollback image，並在燒錄後立即建立新的實驗紀錄。


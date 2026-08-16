# EXP-WRPC-DCO-DPLL-ONLY-20260817：DPLL-only 單次 transaction 隔離

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-DPLL-ONLY-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave-only 硬體燒錄與 runtime 隔離實驗

## 這次想驗證什麼

只允許 DPLL request 最多完成一次，禁止 HPLL request，用來隔離
DPLL→N0→125 MHz reference 路徑，觀察它是否會破壞 Slave 的 WR link/runtime。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- commit：`24f4983583cb97a5ab06e25b232c2b1560ede838`
- pain checkout：detached HEAD，固定於 `24f4983`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Programmer cable：`DE5 [1-11.2]`

## 相較前一個 HPLL-only 版本唯一修改了什麼

只修改 `si5340a_controller_dco.v` 的 runtime transaction gate：

- reset 後將 `hpll_done_once` 設為 1，禁止 HPLL transaction。
- 新增 `dpll_done_once`，只允許第一個 DPLL request 進入四段 I2C sequence。
- 保留既有 I2C start handshake、page/register/data、PHY、PTP、SoftPLL firmware
  與其他 RTL 不變。

## Build provenance

- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave SOF SHA-256：`754ad7c9b9f3c6cb446a609d9ad51be427ae4815ebca9606c05ee1d682666453`
- Full Compilation：successful，0 errors、276 warnings
- Timing closure：`NO`
- Worst setup slack：`-0.629 ns`
- Worst hold slack：`-4.083 ns`
- Worst recovery slack：`0.196 ns`
- Worst removal slack：`0.181 ns`
- Compile log SHA-256：`3465f7ad831a53ed79b72b9654ce17ca538920826a555868a319e7ffb4d5b721`

## 燒錄結果

```text
Info (213045): Using programming cable "DE5 [1-11.2]"
Info (213011): ... checksum 0x30A1D708 ...
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/program_slave.log`
- Programmer log SHA-256：`7799844becf48f2d766c3479ee14f97b084d69311b57aa5347b2636d58ed9c06`
- 燒錄時間：2026-08-17 06:53:36–06:53:54（pain）

## JTAG/runtime 原始結果

### DCO counter

- DCO log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/dco_diag.log`
- DCO log SHA-256：`ad0a3e598f8b9ecf7998e429c73c6f783c643792cafae7ea9e74ee51eeeb8d12`
- Slave `BEGIN_DPLL`：`source=0002 destination=0002 accepted=0000 done=0000`
- Slave `END_DPLL`：`source=0002 destination=0002 accepted=0000 done=0000`
- 因此本輪觀測視窗內沒有真正送出 DPLL I2C transaction。
- Master 沒有此診斷版 probe，回報 `No In-System Sources and Probes instance was found`；這不影響 Slave 燒錄結果，但 Master DCO counter 無法由本腳本取得。

### SoftPLL raw

- raw log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/spll_raw.log`
- raw log SHA-256：`0987ee586d4511ab5abbf81c861fd5f006773282742c003c852830037a9eba56`
- Slave `PSTAT=00000001`，表示 `link_up=1`、`PSTAT.locked=0`。
- Slave `RAW_COUNTER` 的 TAG/ TRR/ REF counter 都有增加。
- `RAW_LOCK RESULT=00000001`、SoftPLL lock detector 仍未報告 lock。

### 20 秒 runtime

- log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/runtime_20s.log`
- log SHA-256：`4022816a677cb0ff33ceebf7d3bfa7eb9cdfefab730cf090afe83322f55b826a`
- `SESSION_TIME_SERIES_DONE`
- Slave 在有效讀值中維持 `link_up=1、wr_mode=3、spll_locked=0、time_valid=0`。
- `foreign_count=1、parent_wr_config=3、parent_is_wr=1、parent_calibrated=1` 曾出現；個別 invalid frame 的 metadata 不納入結論。
- `pps_valid` 在 sample 間有變化，但沒有穩定為 1。

### 60 秒延長唯讀觀測

為確認 DPLL request 是否只是晚到，本輪在同一顆已燒錄的 FPGA 上延長觀測，
沒有重新燒錄：

- begin DCO log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/dco_diag_60s_begin.log`
- begin DCO log SHA-256：`2b8398056d56ee49bb907f0f0391dd735d6c684b166096c9efc06217111213f0`
- runtime log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/runtime_60s.log`
- runtime log SHA-256：`5fb2d8dc3ed78bca893c2f7cf41107cf51a9a8c206f7c3eea8d7689655c99c60`
- end DCO log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-DPLL-ONLY-20260817/dco_diag_60s_end.log`
- end DCO log SHA-256：`ac4331d0feda62c3753ee9a65cf6cb52da2174fac931bb454c260a39700c9614`
- `SESSION_TIME_SERIES_DONE`
- frame accepted：Master `60/60`、Slave `19/60`
- Slave accepted frame：`link_up=1`、`spll_locked=0`、`time_valid=0`；其中
  `pps_valid=1` 的列只有 `3/19`，不能視為穩定 PPS。
- Slave parent accepted frame 全部為 `foreign_count=1、wr_config=3、is_wr=1、calibrated=1`。
- DCO begin/end 都是 `DPLL source=0004、accepted=0000、done=0000`。
- Slave raw `REF_COUNT` 由 `0x002B7641` 增加到 `0x0047617F`，
  `TAG_COUNT` 由 `0x002A660F` 增加到 `0x00459ED9`，表示 runtime activity 持續。

## Observation

1. DPLL-only bitstream 燒錄後，Slave 沒有立即掉線，link 與 runtime activity 仍在。
2. 但目標 DPLL transaction 在本次約 20 秒觀測內沒有被 accepted 或完成，
   所以本輪沒有真正測到「DPLL transaction 對 link 的影響」。
3. Slave 仍沒有 `PSTAT.locked=1` 或 `time_valid=1`。
4. 這個結果也顯示目前 servo 可能尚未產生足以觸發 DPLL transaction 的資料變化，
   或 DPLL load/request 在此隔離 gate 前就沒有形成。

## Conclusion

本實驗可以證明：

> 將硬體改成 DPLL-only、但在沒有 DPLL request 的觀測視窗內，Slave 可以維持
> `link_up=1` 與部分 WR runtime activity。

本實驗不能證明：

> DPLL transaction 已安全完成、DPLL 路徑會讓 link 掉線，或 Slave 已完成同步。

因為 DPLL counter 明確為 `accepted=0、done=0`，而 `PSTAT.locked=0、time_valid=0`。

## Next Step

延長到 60 秒後 DPLL 仍為 `accepted=0、done=0`，因此下一個硬體變因應回到
「保留 DPLL transaction，但反轉 FINC/FDEC direction」的版本，並先設計能讓
DPLL request 確實被觸發的單一 A/B 實驗；不同時改 FSTEPW、PHY 或 SoftPLL
演算法。若 DPLL request 仍無法形成，應先把問題定位在 servo→DCO request path，
而不是宣稱 SI5340 register direction 已被驗證。

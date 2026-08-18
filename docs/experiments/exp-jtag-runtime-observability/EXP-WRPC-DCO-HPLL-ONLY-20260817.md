# EXP-WRPC-DCO-HPLL-ONLY-20260817：只允許一次 HPLL transaction

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-HPLL-ONLY-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave-only 單一隔離實驗；Master 維持 baseline。

## 這次想驗證什麼

上一輪讓 HPLL 與 DPLL transaction 都完成後，Slave 的 WR runtime/link 掉線。本輪只允許 HPLL 完成一次 transaction，完全禁止 DPLL transaction，用來判斷是否是 DPLL→N0→125 MHz reference 路徑造成破壞。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- commit：`b8e1f855a5f75ad6fd748b1e36e464cbefac3163`
- pain checkout：detached HEAD，固定於 `b8e1f85`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

保留上一輪已驗證可讓 I2C transaction 完成的 start handshake，並在同一個 Slave controller 做隔離：

- 不再從 `dpll_pending` 啟動 DPLL transaction。
- HPLL 只允許第一次 transaction；完成後以 `hpll_done_once` freeze 後續 HPLL writes。
- HPLL/DPLL source、destination、accepted、done counter 保留作唯讀觀測。
- Master、PHY、PTP、SoftPLL firmware 與 SI5340 register data 未修改。

## Build provenance

- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave SOF SHA-256：`b25af7514b54907e21ec891d7cb106a1b20cafe52d4b5736f1a830cc4fdf3204`
- Full Compilation：successful，0 errors、274 warnings
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.372 ns`
- Worst hold slack：`-3.493 ns`
- Worst recovery slack：`1.274 ns`
- Worst removal slack：`0.311 ns`
- Compile log SHA-256：`3465f7ad831a53ed79b72b9654ce17ca538920826a555868a319e7ffb4d5b721`

## 燒錄結果

只燒錄 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A2A4DF
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 06:23:55–06:24:14（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-HPLL-ONLY-20260817/program_slave.log`
- Programmer log SHA-256：`bca9bc13c87ac4b016a94f1583a61b7642a932afae633d771dcb995cde275b80`

## JTAG/runtime 原始結果

### DCO pipeline

```text
END_HPLL source=0000 destination=0006 accepted=0003 done=0001
END_DPLL source=0000 destination=0002 accepted=0001 done=0000
```

這表示 DPLL request 可能被 source/accepted counter 看見，但沒有被送成 I2C transaction；HPLL 只完成一次。

### 20 秒 time-series

- log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-HPLL-ONLY-20260817/runtime_20s.log`
- SHA-256：`841c165a1e2dce080a5cd9fe5ba2604f397cf06b064293cb279526ecbf94c878`
- Slave `PTP_RX/PTP_TX`、tag/TRR、IRQ、UCNT 持續增加。
- Slave `foreign_count=1`、`wr_config=3`、`parent_is_wr=1`、`calibrated=1`。
- 全程代表性 `link_up=1`。
- `PSTAT.locked=0`、`time_valid=0`；`pps_valid` 在 sample 間有變化，不能視為同步完成。
- JTAG session 最終 `SESSION_TIME_SERIES_DONE`，但部分 frame 因 mailbox consistency 被 retry/reject，未把 invalid frame 當成結論。

其他原始檔：

- DCO log SHA-256：`afebc7248877bc13b52bdc1e3c7ed48bfd31fdc75a9057752fee6c386bf2aa60`
- SoftPLL raw log SHA-256：`67900a21dc0d82dd735a18d2b5cb1bf0c5cfde657402ffd1c6ee2e3fa642f911`

## Observation

1. 相較「HPLL+DPLL 都完成」的 `af4a960`，本輪只完成 HPLL 一次時，Slave 沒有出現後續 `PTP_RX/TX=0`、parent 消失或 `link_up=0` 的現象。
2. 這提高 DPLL→N0→125 MHz reference 路徑是破壞來源的可能性。
3. 這仍不能證明 DPLL 一定是唯一根因，因為 HPLL-only 同時保留了 handshake，且只執行一次 transaction；一般 page/register semantics、FINC/FDEC direction、FSTEPW、mask 或長時間累積效應仍未單獨排除。
4. HPLL-only 沒有讓 Slave 進入 SoftPLL lock；`PSTAT.locked=0`、`time_valid=0` 持續存在。

## Conclusion

本實驗支持：

> HPLL 單獨完成一次 transaction 不會立即破壞 Slave 的 WR runtime/link；相較之下，DPLL transaction 完成後曾伴隨 runtime/link 掉線。

因此目前優先嫌疑可收斂到 **DPLL/N0/125 MHz reference actuator path**，但這仍是「較高優先級假說」，不是已證明的唯一根因。

本實驗不支持：

> 不能宣稱 White Rabbit 已同步，因為 Slave `PSTAT.locked=0`、`time_valid=0`。

## Next Step

維持目前 HPLL-only 證據，下一個單一變因應在離線 source audit 中確認 SI5340 的 N0/N1、`N_FSTEP_MSK`、FSTEPW 與 FINC/FDEC 的正式 register semantics；確認前不直接改成 `0x1E/0x1D` 或反轉方向。之後可在已知安全條件下，設計一個只執行一次、可 rollback 的 DPLL transaction A/B。


# EXP-WRPC-ROLLBACK-DCO-20260817：恢復 DCO 觀測 baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-ROLLBACK-DCO-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：失敗版本後的安全 rollback；只燒回已知可運作的 Slave baseline。

## 這次想驗證什麼

確認 `EXP-WRPC-DCO-START-HANDSHAKE-20260817` 造成的 runtime/WR activity 中斷，是否可以藉由恢復 `c5092dd` baseline 消除；本輪不是同步成功驗證。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 研究分支：`exp/jtag-runtime-observability`
- pain checkout：detached HEAD，固定於 `c5092dd`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## Image provenance

- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- Slave SOF SHA-256：`709274c16a0efba07ccb50f0afa85a606e678dfa3d72cce7681696a1d1469123`
- Full Compilation：successful，0 errors、273 warnings
- Timing：`timing_closed=NO`

## 燒錄結果

只燒回 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A53A47
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 06:16:47–06:17:06（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-ROLLBACK-DCO-20260817/program_slave.log`
- Programmer log SHA-256：`ab53b8c29afe2812ffd84c40cc60351f5360867af433ae3d9d9e6bc4f8e647f8`

## JTAG/runtime 原始結果

使用 baseline 的 DCO 與 SoftPLL raw read-only script：

- DCO log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-ROLLBACK-DCO-20260817/dco_diag.log`
- DCO log SHA-256：`6a328fc0903bb0a5f507517b76982ee931b39eee9f0e0c2af56dd9564304892f`
- SoftPLL raw log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-ROLLBACK-DCO-20260817/spll_raw.log`
- SoftPLL raw log SHA-256：`bcca94284d4368c53aef0d4e21f6b49ad7758850520cb9b86227af4c5a17fe91`

代表性 Slave 結果：

```text
PSTAT=00000001
SSTAT=00000101
HELPER_ERROR=FFFDB610
HELPER_OUTPUT=0000FFFB
TAG_VALID / TRR_WRITE 持續增加
```

Master 仍為原 baseline；本輪沒有重新燒錄 Master。

## Observation

1. rollback 後 Slave 恢復到 baseline 的 PTP/tag/IRQ activity pattern；DCO source/destination input count 重新持續增加，accepted 約為 `0x037A`，done 回到 `0`。
2. rollback 後仍然是 `PSTAT.locked=0`、`time_valid=0`；因此 rollback 只證明移除了前一輪的 runtime 中斷，不是同步成功。
3. `EXP-WRPC-DCO-START-HANDSHAKE` 的 `done>0` 與後續 runtime 掉線之間具有時間上的關聯，但仍需用更安全的 SI5340 transaction 驗證確認實際寫入內容。

## Conclusion

本實驗支持：

> `c5092dd` 是目前較安全、可維持 PTP/tag/IRQ activity 的 Slave baseline；失敗版本已被移除。

本實驗不支持：

> 不能宣稱兩台 DE5a 已同步，因為 Slave `PSTAT.locked=0`、`time_valid=0`。

## Next Step

維持 `c5092dd` 在板上。下一輪先針對 SI5340 runtime transaction 的 page/register/data/ACK/readback 做唯讀或離線 RTL/模擬核對，不直接再燒錄會寫入 SI5340 的版本；確認安全的 register sequence 後，再以單一最小變因重新實驗。


# EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2

## 實驗基本資料

- Experiment ID：`EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2`
- 日期：2026-08-18
- 研究分支：`exp/master-9f-observability`
- 燒錄前同步的 Git commit：`9ae06a5`（包含上一輪 windowed observer 實驗紀錄）
- 燒錄使用的既有 Slave SOF provenance：`aa0825a`
- Quartus：Quartus Prime 17.0 Build 595
- 目的：將 Slave 從 windowed clock observer 診斷版恢復到已知可維持鏈路的 readback SOF，確認後續研究回到穩定基準。

## 本輪唯一變因

```text
Slave：使用既有 aa0825a readback SOF
Master：不燒錄、不修改
```

本輪不重新 compile，也不把上一輪 windowed observer 的 parser 套用到舊版 SOF；只做 restore programming 與唯讀 runtime 驗證。

## Bitstream 與燒錄證據

| 項目 | 值 |
|---|---|
| Slave SOF | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| Slave SOF SHA-256 | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| Programmer checksum | `0x309FA629` |
| Cable | `DE5 [1-11.2]` |
| Device JTAG ID | `0x02E660DD` |
| Compile provenance | `EXP-WRPC-SLAVE-SI5340-READBACK-20260817`, source `aa0825a` |
| Slave MIF SHA-256 | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Slave QSF SHA-256 | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| Slave SDC SHA-256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |

原始 programmer 輸出：

```text
Info (213011): ... with checksum 0x309FA629 for device 10AX115N2F45@1
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## JTAG / runtime 結果

原始檔案：

```text
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/program.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/runtime_snapshot.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/dco_state.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/dco_readback.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/runtime_timeseries.log
artifacts/EXP-WRPC-SLAVE-READBACK-RESTORE-20260818-R2/log_sha256.log
```

### 燒錄後 snapshot

Master：

```text
status_probe: 51603C6130BC82FF
cpu_marker: 0x0000B004 seen=1
WDIAGS_MODE: 2
WDIAGS_PTP: 00000006
WDIAGS_PTP_RX: 00007064
WDIAGS_PTP_TX: 00010E84
```

Slave：

```text
status_probe: 413A8EC1235082EF
cpu_marker: 0x0000B004 seen=1
WDIAGS_MODE: 3
WDIAGS_PTP: 00000004
WDIAGS_PTP_RX: 00000006
WDIAGS_PTP_TX: 00000003
WDIAGS_SSTAT: 00000000
WDIAGS_PSTAT: 00000001
```

### DCO readback

```text
DCO_STATE A=0005000200000320 B=0005000400000320
DCO_READBACK value=000500040004050D
```

readback valid、ACK/NACK error 為 0、readback value 為 `0x0D`；本輪沒有看到 I2C NACK。

### 10 秒 runtime session

Master 的有效 frame 維持 `wr_mode=2`、`time_valid=1`、`pps_valid=1`，PTP RX/TX 持續增加；少數讀取瞬間出現 link transient，但後續有效 sample 恢復 `status_low=FF`、`link_up=1`。

Slave 的結果：

- 多數後段有效 sample 為 `status_low=EF`、`wr_mode=3`、`pps_valid=1`、`link_up=1`。
- `time_valid=0`、`spll_locked=0`、`SSTAT=0`，沒有完成同步。
- 中間曾出現 `status_low=01/CF`、`link_up=0` 與 `accepted=0 retries=3`，但後段 sample 006、008、009、010 已恢復 accepted。
- PTP RX/TX 活動仍偏少，最後沒有進入 `SSTAT=1` 或 `UCNT>0` 的穩定狀態。

## Observation

1. `aa0825a` restore 後，Slave 能回到 `mode=3/link_up=1/pps_valid=1` 的可觀測狀態，且後段 session 可以 accepted；因此 windowed observer 版本已被移除，板子沒有留在該診斷版。
2. Slave 仍未達到 `time_valid=1`、`spll_locked=1`，所以 restore 只是恢復 baseline，不是同步成功。
3. 本輪沒有發生主機 stall、斷線或需要實體重啟。

## Conclusion

本輪證據支持：

> Slave 已成功恢復到 `aa0825a` readback baseline；Master role baseline 沒有被改動。後續應在這個穩定版本上繼續研究 Slave servo/SoftPLL-to-time_valid 路徑。

本輪證據不支持：

- 不能宣稱 Slave 已完成 WR synchronization。
- 不能宣稱 FINC/FDEC direction 已驗證。
- 不能宣稱 SI5340 output clock 已被正確調整。

## Next Step

1. 保留目前 `aa0825a` Slave 與歷史成功 Master baseline，不再加入會改變 clock/resource 的 RTL counter。
2. 若要繼續 physical clock-effect，改用外部量測或更低侵入、單一 clock domain 的觀測，不再把三個 domain 的 window latch 直接放入 WR top-level。
3. 在沒有「DCO completed step 與 physical clock 可重現變化」證據前，不反轉 FINC/FDEC。

## 原始檔案雜湊

```text
program.log            c58e2232ff0228945c9a6c1bc3edf9bc04045d9da51bc606231f5fb44c0627f4
runtime_snapshot.log   bca091c89cffbee2ae31f1de59dc2c718d0e1720f270bd2d2791dce6feeb001a
dco_state.log          57efd0a2e7a12ae0a394f158103428eec208ff35e0bed3e49d1620d980151819
dco_readback.log       0675287a7c8bb4c3f055450f4a93daad06cd4193d0343cd6a3d648b3fd58c0f0
runtime_timeseries.log 0aae97c74a58357d5df33b8732c9fa92cd7649dbecea35538d69d7c6575d2fd3
```

# EXP-WRPC-BASELINE-RESTORE-20260818-R3

## 實驗基本資料

- Experiment ID：`EXP-WRPC-BASELINE-RESTORE-20260818-R3`
- 日期：2026-08-18
- 實驗分支：`exp/master-9f-observability`
- 燒錄前 source commit：`31622a6`（恢復穩定 Slave readback 觀測版本）
- 長時間唯讀 script commit：`fdc6a8e`（加入 HPLL/helper 關聯觀測腳本）
- Quartus：Quartus Prime 17.0 Build 595（Programmer 與 SignalTap II）
- 研究目的：重新載入已知成功的 Master role 與穩定 Slave readback SOF，排除先前 runtime 狀態漂移，再以不修改硬體的方式觀察 Slave 是否只是需要較長 acquisition 時間。

## 本輪唯一變因

燒錄階段只恢復既有基線映像；長測階段只把唯讀觀測時間延長到 10 分鐘。

```text
Master role、Master firmware、Slave RTL、Slave firmware、PHY、PTP、PI/threshold、
FINC/FDEC 方向與 SI5340 transaction sequence 均不修改。
沒有重新 compile，也沒有加入新的 RTL observer。
```

## Bitstream 與 provenance

| 項目 | Master | Slave |
|---|---|---|
| role/source provenance | 歷史成功 `9f848ec`；diagnostic baseline `f19bea8` | `aa0825a` readback baseline |
| SOF | `quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof` | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Slave QSF SHA-256 | - | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| Slave SDC SHA-256 | - | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |

本輪沒有使用新的 compile output；上述 SOF 均為先前已保存並核對過的 bitstream。

## 燒錄結果

### Master

第一次命令因 shell 將 `-o p;/path` 的分號誤當成命令分隔，收到：

```text
Error (213008): Programming option string "p" is illegal.
bash: ...DE5a_wr_master_jtag.sof: Permission denied
```

這次嘗試沒有完成 FPGA 燒錄，原始檔案仍保留於 `program_master.log`。

修正 quoting 後重新執行：

```text
Info (213045): Using programming cable "DE5 [1-11.1]"
Info (213011): ... checksum 0x30A46449 ...
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

### Slave

```text
Info (213045): Using programming cable "DE5 [1-11.2]"
Info (213011): ... checksum 0x309FA629 ...
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

燒錄結果支持兩份基線 SOF 都已成功載入；它不等於 WR 時間同步成功。

## 燒錄後 JTAG/runtime 原始證據

原始檔案位於：

```text
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/program_master.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/program_master_retry.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/program_slave.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/runtime_snapshot.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/runtime_timeseries.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/hpll_helper_correlation.log
artifacts/EXP-WRPC-BASELINE-RESTORE-20260818-R3/hpll_helper_correlation_60s.log
artifacts/EXP-WRPC-SLAVE-LONG-READONLY-BASELINE-20260818/hpll_helper_correlation_10min.log
```

### Master snapshot與短時間序列

```text
status_probe: 011EE66129B082FF
cpu_marker: 0x0000B004 seen=1
WDIAGS_MODE: 2
WDIAGS_PTP: 00000004  （後續有效時間序列進入 00000006）
status_low: FF
time_valid: 1
pps_valid: 1
```

後續有效 sample 中 `WDIAGS_PTP=6`，PTP RX/TX 從 `0x05/0x12` 增加到至少 `0x08/0x1A`，且 `status_low=FF`、`link_up=1` 可觀測。這重現了歷史 Master role 的核心證據：`marker=B004、MODE=2、PTP=6、status=0xFF`。

### Slave snapshot與短時間序列

```text
status_probe: 403A8E6131BC82EF
cpu_marker: 0x0000B004 seen=1
WDIAGS_MODE: 3
WDIAGS_PTP: 00000004
WDIAGS_PTP_RX: 00000000
WDIAGS_PTP_TX: 00000000
status_low: EF
time_valid: 0
pps_valid: 1
WDIAGS_PSTAT: 00000001
WDIAGS_SSTAT: 00000000
```

短時間序列中 Slave 偶爾有 `PTP_RX/PTP_TX` 小量增加與 `link_up=1` 的有效 sample，但沒有 `time_valid=1` 或 SoftPLL lock。

## 60 秒 HPLL/helper correlation

這是同一個 aa0825a SOF 上的唯讀觀測，不寫入 WR 設定：

```text
DCO completed step：11 -> 13 -> 15 -> 17 -> 19 -> 21
每次 step readback count 同步增加
HELPER_STATE：全程 00000000
HELPER_ERROR_SIGNED：全程 0
HELPER_ERROR_DELTA：全程 0
HELPER_OUTPUT：全程 00000000
SPLL_STATE：全程 00000000
```

## 10 分鐘長時間唯讀 baseline

長測命令為：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \\
  -t scripts/jtag/read_hpll_helper_correlation.tcl 300 2000
```

結果：

```text
TOOL_EXIT=0
samples=300
觀測時間：約 10 分 10 秒
HPLL_HELPER_CORRELATION_DONE：存在
DCO STEP：35 -> 75
STEP_EVENT：20
HELPER_ERROR_SIGNED 唯一值：0
HELPER_ERROR_DELTA：最大值 0，最小值 0
HELPER_STATE/OUTPUT：全程 0
SSTAT：全程 00000000
PSTAT：主要為 00000000 或 00000001，沒有 lock bit
```

Slave `status` 低 8 位的樣本分布為：

```text
EF=200、E3=65、CF=21、01=13、C3=1
```

這表示多數樣本仍保留 `EF` 類的 link/PPS 狀態，但期間存在少量 runtime/link transient；沒有任何樣本達成 `time_valid=1` 與 SoftPLL lock 的完整判準。

## Observation

1. 重新燒錄後，Master 的歷史成功 role 可以重現；本輪沒有發明或測試新的 Master role 切換方法。
2. Slave CPU marker 為 `B004`，DCO controller 的 completed step 在長時間內持續增加，readback 也隨 step 更新，且沒有觀測到 I2C error。
3. 同一時間，Slave 的 helper/SoftPLL 觀測欄位全程為 0，`SSTAT=0`，沒有 `PSTAT.locked=1` 或 `time_valid=1`。
4. 長時間觀測沒有把 Slave 從未完成同步推進到完成同步，因此「只是等待更久」目前不成立。
5. 這份資料沒有直接量到 SI5340 輸出腳位的頻率或相位；不能由 DCO readback/step 增加推論 physical clock 已按預期改變。

## Conclusion

本輪證據支持：

> Master 的 `9f848ec` role 與 diagnostic baseline 已重新建立；Slave 的 DCO controller 會持續完成 transaction，但 SoftPLL helper feedback/lock 路徑在 10 分鐘內沒有有效活動，Slave 尚未完成 White Rabbit time synchronization。

本輪證據不支持：

- 不能宣稱兩張 DE5a 已完成 WR synchronization。
- 不能宣稱 FINC/FDEC 方向錯誤或正確。
- 不能宣稱 SI5340 output clock 已實際改變。
- 不能只依 status 或 `pps_valid=1` 宣稱 Slave time_valid。
- 由於 Slave PTP counter/parent shadow 在部分樣本偏低或不一致，不能把 PHY/PTP 基本連通完全排除；目前只能說 Master role 已固定，Slave 問題仍集中在「PTP/parent 到 SoftPLL helper feedback」這段鏈路。

## Next Step

1. 保留目前 Master SOF 與 aa0825a Slave SOF，不再加入 RTL clock observer。
2. 先以既有 JTAG register map 做唯讀 source/firmware audit，釐清為何 Slave 的 PTP RX/TX、parent shadow 與 helper block 在重新燒錄後未穩定進入有效狀態。
3. 在取得穩定的 `PTP RX/TX、parent_is_wr、parent_calibrated、HELPER_ERROR` 連續證據前，不反轉 FINC/FDEC，也不修改 Master role。
4. 若要證明 SI5340 physical effect，優先使用板外頻率/相位量測，不再新增跨 clock-domain RTL counter。

## 原始檔案 SHA-256

```text
program_master.log              1bb78867b552414dd3aca14299d1ebc017a0c4c72d1d0db096536b769d6aca5e
program_master_retry.log        a92de5c72fa4746bbedebd4dac1a10ff95ade21300af7e3100c0594c00d23ca2
program_slave.log               912541d40be8e9823dfba611926f56a37b929381fcf4056e38cdfdfa669fa644
runtime_snapshot.log            c794f9955110071dae91f8a965058e00036c7cc67d51d74926a078c1486079b2
runtime_timeseries.log          ebaa5d7137dfa3f8019b9e5d127cf84864829661b20b6a18a4630d32cbcd124f
hpll_helper_correlation.log     926bfcf6a7b77cd0b680efaea553e4a22e0d691fef5d8d02108772cf11619e00
hpll_helper_correlation_60s.log 1a09312df1a718a78edf1aa5265e3c40a6f3691d0cbc4e7e45edf48d73ef5fba
hpll_helper_correlation_10min.log e0fd9ef7354f57ce5bd20da1bad622bce41ceaef76981cd3e1ac9b34bef896f5
```

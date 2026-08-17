# 實驗紀錄：Slave DCO runtime_start 保持握手 A/B

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-DCO-START-HOLD-CLEAN9F-AB-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only 單一功能變因；不修改 Master role
- Git branch：`exp/master-9f-observability`
- 實驗狀態：先建立紀錄，待 compile/program/runtime 結果補入
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

確認高速 `iCLK` domain 產生的 `runtime_start` 是否因為只存在一個週期，沒有被慢速 I²C controller 的 `i2c_system_clk` domain 看見。成功判準先限定為 DCO transaction 可以完成：

- `DCO_DEBUG.BUSY` 能由 1 回到 0。
- `rt_state` 能回到 idle。
- `dco_step_count` 能從 0 增加。

這一輪不把 DCO transaction 完成誤稱為 White Rabbit 同步成功；後續仍須驗證 Slave `spll_locked=1`、`time_valid=1`、`pps_valid=1`。

## 相較 baseline 的唯一修改

- Master：維持歷史成功 `9f848ec` exact SOF，不重新編譯、不重新燒錄、不改 role。
- Slave：以 corrected-SOF 使用的 `1b52223` 三筆 runtime sequence 為基線，只新增 `runtime_start_hold`：當 `runtime_start` 出現時保持 `bus_start`，直到 I²C `bus_state` 回報 busy 才清除。
- 不修改 page sequence、FINC/FDEC 方向、DMTD、PI、threshold、lock detector、PHY、PTP 或 firmware。

## 目前 compile 前 provenance

- 預計 source：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`
- 基準 source：`1b52223b4bcab4f440189ce95c8219edb811675c`
- 本輪唯一 RTL 變因：`runtime_start_hold`
- 預計 compile command：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile DE5a_wr_slave_jtag`
- 預計 Slave cable：`DE5 [1-11.2]`

## Compile provenance

待 compile 完成後補入：

- source commit：
- SOF 路徑、SHA-256：
- Slave MIF 路徑、SHA-256：
- QSF/SDC SHA-256：
- compile log 路徑、SHA-256：
- Errors/warnings：
- Timing caveat：

## 燒錄結果

待 compile 成功並核對 hash 後補入。燒錄後立即記錄：

- Programmer command/version/cable：
- JTAG ID：
- SOF SHA-256/checksum：
- configuration result：
- 原始 programmer log 路徑與 SHA-256：

## JTAG/runtime 原始結果

待燒錄後補入。至少保存：

- `read_dco_state.tcl` 或等價唯讀讀值：`rt_state`、`bus_state`、`bus_done`、`runtime_start_hold`、`BUSY`、`STEP_COUNT`。
- 60 秒 correlation：`HELPER_ERROR`、`HELPER_OUTPUT`、`DCO_STEP_COUNT`、`PSTAT`、`SSTAT`、`UCNT`、`time_valid`、`pps_valid`。
- Master baseline sanity：`status=FF`、`MODE=2`、`PTP=6`、`time_valid=1`、`pps_valid=1`。

## Observation

待實測後補入，只描述原始結果，不把 frame retry 或單次取樣當成完整同步證據。

## Conclusion

待實測後補入。若 `BUSY` 回 0 且 `STEP_COUNT` 增加，只能結論為 DCO/I²C start-accept handshake 得到支持；若仍 `BUSY=1`、`STEP_COUNT=0`，則轉向更細的 `bus_start/bus_state/bus_done/I²C state` 唯讀觀測。兩種結果都不能直接宣稱 Slave 已同步。

## Next Step

只有在本輪 transaction completion 證據成立後，才繼續追 `HELPER_ERROR` 是否收斂、lock detector 是否累積，以及最後 `time_valid/pps_valid`。Master role 維持歷史 9f848ec，不新增 role 切換方法。

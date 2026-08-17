# EXP-WRPC-SLAVE-CLOCK-EFFECT-20260818

## 實驗名稱

Slave clock-effect counter 診斷版

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-CLOCK-EFFECT-20260818`
- 日期：2026-08-18（Asia/Taipei）
- 實驗類型：Slave 單一診斷變因燒錄實驗

## 想驗證什麼

上一輪已取得 SI5340 page 3/`0x0339` 的有效 readback，但仍沒有證據顯示 DCO command 造成外部 clock 改變。本輪想用固定 5 秒窗口估算 `QSFPA_REFCLK_p` 與 `QSFPB_REFCLK_p` 的來源頻率，並與 DCO step、Slave `time_valid` 同時觀察。

## 相較 baseline 唯一修改

Master 與 Slave DCO/FINC/FDEC/SoftPLL/PTP 完全不變；只在 Slave top：

- 將既有 activity counter 擴成 32-bit。
- 新增 `WR_CLOCK_EFFECT_SLAVE` JTAG probe（instance index 11）。
- 新增 `scripts/jtag/read_clock_effect.tcl`，以 5 秒窗口計算兩個 counter delta。

這個診斷版本沒有修改 DCO command，也沒有修改 Master role。

## Git / branch / provenance

- Branch：`exp/master-9f-observability`
- Source commit：`4a601f0fb5cf84de06ade6e40ce4a768247d25ac`
- Commit message：`加入Slave clock effect計數觀測`
- Master baseline tag：`master-diagnostic-baseline-20260817`
- Quartus：Quartus Prime 17.0 Build 595（2017-04-25）

### Source / build hash

- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SOF SHA-256：`3a1a3fdf5c4a608f09f8a31435db1225298395397cbe90f6f56db364f76ddaa9`

## Compile 結果

```text
Full Compilation was successful
Fitter Status: Successful
TIMING_CLOSED=NO
WORST_SETUP_SLACK_NS=-0.228
WORST_HOLD_SLACK_NS=-3.469
WORST_RECOVERY_SLACK_NS=1.235
WORST_REMOVAL_SLACK_NS=0.301
UNCONSTRAINED_CLOCKS=4
UNCONSTRAINED_INPUT_PATHS=569
UNCONSTRAINED_OUTPUT_PATHS=86
```

SOF 產生成功，但 timing closure 仍未達成；因此不能把 compile success 視為硬體功能成功。

## 燒錄結果

只燒錄 Slave：

```text
Programming cable: DE5 [1-11.2]
Programmer checksum: 0x309DCF69
Device: 10AX115N2F45@1
JTAG ID code: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Programmer: successful, 0 errors, 0 warnings
```

## JTAG / runtime 原始結果

完整 artifacts：

`artifacts/EXP-WRPC-SLAVE-CLOCK-EFFECT-20260818/`

### Clock-effect counter

```text
CLOCK_EFFECT A=00A7834700A78606 B=00CCC8B200CCCC0D
REF_DELTA=2442759
DMTD_DELTA=2442603
REF_EST_HZ=125069260.800
DMTD_EST_HZ=125061273.600
```

這表示 counter probe 本身能被讀取，也能在 5 秒窗口產生 delta；但由於本輪 Link 同時失效，不能把這兩個數字直接當成已校正的 SI5340 output frequency。

### DCO / readback

```text
DCO_STATE A=0005000100000220 B=0005000100000220
DCO_READBACK value=000500010001050D
```

讀回值仍為 `0x0D`，valid/match/ACK 欄位仍顯示 readback path 有效；DCO step count 為 1。這表示本輪 clock counter 版本沒有讓 register readback 本身失效。

### Link / synchronization

燒錄後立即讀取與等待後再次讀取，兩端都維持：

```text
Master: TIME_VALID=1、PPS_VALID=1，但 LINK_UP=0、LINK_OK=0
Slave : TIME_VALID=0、PPS_VALID=1，但 LINK_UP=0、LINK_OK=0
```

等待後再次取得：

```text
Master status_probe: ...82F3
Master WDIAGS_MODE=2
Master PTP_RX=0x00006F6A
Master PTP_TX=0x000105DF

Slave status_probe: ...82E3
Slave  WDIAGS_MODE=3
Slave  PTP_RX=0x00000000
Slave  PTP_TX=0x00000013
```

30 筆 time-series 的 Slave 最後有效 frame 也為：

```text
status_low=E3
time_valid=0
pps_valid=1
wr_mode=3
link_up=0
spll_locked=0
WDIAGS_SSTAT=0x00000000
WDIAGS_PSTAT=0x00000000
WDIAGS_UCNT=0x00000000
```

## Observation

1. clock-effect counter 可讀取，且兩個 source counter 在 5 秒內有穩定 delta。
2. `0x0339` readback 仍有效，沒有新 NACK 證據。
3. 但本版燒錄後，Master 與 Slave 的 `LINK_UP/LINK_OK` 都降為 0，等待後仍未恢復。
4. 因 Link 已失效，這輪的 frequency estimate 不可作為有效 WR clock-effect 結論。
5. 這個結果與上一版 readback-only SOF（曾觀察到 Slave `LINK_UP=1`）不同，表示新增 32-bit counter/observer 版本至少存在 timing/resource 或影響 link bring-up 的風險。

## Conclusion

本實驗**證明**：

- Quartus compile、SOF 產生與 JTAG programming 都成功。
- 新增 counter probe 能讀回資料。
- SI5340 `0x0339` readback path 仍可取得有效值。

本實驗**不支持**：

- clock-effect estimate 已代表正確的 SI5340 output frequency。
- Slave servo 已進入 lock。
- WR link 或 Slave synchronization 成功。

本輪應判定為：

> **診斷版硬體 compile/program 成功，但燒錄後兩端 WR link 失效，因此不能用它判斷 clock effect；這個變因先退回，不繼續在此 SOF 上做功能推論。**

## Next Step

1. 立即恢復上一輪 `aa0825a` readback-only SOF，確認 Master/Slave link 回到可觀測狀態。
2. 將 clock-effect 觀測改成更低風險的方式：不增加 32-bit counter/大量 observer logic，優先使用既有 16-bit activity path 做短窗口、或在 readback-only baseline 上加入更小的單一 counter。
3. 恢復後再判斷 DCO output frequency effect；若仍無法證明 clock effect，才考慮外部量測或檢查 SI5340 output-to-refclk mapping。

## Artifact hashes

完整 hash 清單：

`artifacts/EXP-WRPC-SLAVE-CLOCK-EFFECT-20260818/log_sha256.log`

重要 raw log SHA-256：

- `program.log`：`79340b6baeefa7694902ff2022aa09c6b15e921331743882678ea9249ad8be7a`
- `runtime_snapshot.log`：`69714d614ec91eb08e9c3d1df3d3a7efc27c083f7968e78c6f3ace5ebddcf8ef`
- `dco_state.log`：`8d8a5daa8319dc1e7201b59354114518d9e097cff4639a81dd6d1e90e5d22502`
- `dco_readback.log`：`03b64929268913aed48cf977548028016597978169d1d0348f07668db4361a05`
- `clock_effect.log`：`9cc6aac61796ea167650c7d34d9b6d3b12e0fd28f1524edb95ede558e1f6ef65`
- `clock_activity.log`：`ab4074cf08321e741aad31483edd40959aba315691b45f2d2d68e2a3f8537760`
- `runtime_timeseries.log`：`1c16fc308289ddd0b4cc79d7f4c86f54e68c3c788d20c52efd4e904af232a510`

# 實驗紀錄：WR 系統時鐘 50 MHz 改為 62.5 MHz

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SYSCLK-625-20260817`
- 日期：2026-08-17
- 類型：Master/Slave 實際建置、燒錄與 JTAG runtime 觀測
- 結果：建置與燒錄成功；兩片 DE5a 的 WR 時間同步仍未完成

## Git 與建置追溯

- Git branch：`exp/jtag-runtime-observability`
- Git commit：`4ea8c8acf7d36f60f9ec02d951d08c41894484f8`
- Git commit message：`統一 WR 系統時鐘為 62.5 MHz`
- GitHub：`origin/exp/jtag-runtime-observability`
- pain checkout：detached at `4ea8c8acf7d36f60f9ec02d951d08c41894484f8`
- Quartus Prime：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

### 原始碼與專案設定

- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Master/Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- 新增 RTL：`quartus/jtag_runtime_diag/wr_sys_clk_625.vhd`

### MIF 與 SOF

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA-256 | `38ecd737b1b228d3c618ad7f9fada44b1814eec1d4d9a61a257bcf25ac57b0f4` | `2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0` |
| SOF SHA-256 | `31e5a63a78ad35150a370cc76895241b2fe406b924104066f858a97f3263efcb` | `a09f8b3862fd21457122495d2f917ea31796db0b6ac99f5f6e70c53348210f5a` |
| Quartus Programmer checksum | `0x30A1AE9C` | `0x30A414C0` |

建置 identity 檔案：

```text
/home/b10504072/04_WR/build/build_info_jtag_master.txt
/home/b10504072/04_WR/build/build_info_jtag_slave.txt
```

兩邊皆記錄 `COMPILE_RESULT=Full Compilation was successful`，但 `TIMING_CLOSED=NO`：

- Master worst setup slack：`-0.218 ns`
- Slave worst setup slack：`-0.182 ns`
- 兩邊皆有 `3` 個 unconstrained clocks、`403` 個 unconstrained input paths、`84` 個 unconstrained output paths

## 想驗證什麼

驗證目前 WR core 使用 50 MHz `CLK_50_B2J`，而 firmware 與 WR core system-clock model 使用 62.5 MHz，是否造成 Slave servo/SoftPLL 無法進入有效時間同步。

## 相較 baseline 唯一修改

本次只修改 WR system timebase：

1. 新增 `wr_sys_clk_625.vhd`，由 DE5a 50 MHz oscillator 經 `altpll` 產生 62.5 MHz。
2. `xwr_core.clk_sys_i` 改接 62.5 MHz PLL 輸出。
3. JTAG Wishbone mailbox 與 WR core reset release 改在 62.5 MHz domain 運作。
4. WR core reset 另外等待 PLL locked 與原有 SI5340 設定完成。
5. `urv_cpu` 明確指定 `g_clock_frequency => 62500000`。

以下內容沒有修改：

- QSFP-A lane 0
- PHY lane/polarity/8b10b 設定
- QSFP-A/QSFP-B reference 與 DMTD 接線
- SI5340 設定表與 DCO 控制
- PTP filter、servo 演算法與 calibration 參數

## 建置結果

Master 與 Slave 都完成 Quartus full compilation，產生可燒錄 SOF。建置腳本雖在 `quartus_sh --clean` 階段留下 Tcl clean error 訊息，但最後 Quartus 報告為 `Full Compilation was successful. 0 errors`，SOF、fit summary 與 STA report 均存在。

## 燒錄結果

Master 使用 cable `DE5 [1-11.1]`，Slave 使用 cable `DE5 [1-11.2]`。

兩片的 Programmer 原始輸出皆包含：

```text
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

原始檔案與 SHA-256：

- Master programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SYSCLK-625-20260817/master_program.log`
  - SHA-256：`d3241b9ade4dcc3f150981862190eeea043ed88fe628fac414c7b7c1925e4028`
- Slave programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SYSCLK-625-20260817/slave_program.log`
  - SHA-256：`33271b256ec610e70526d8c2158eb4e0652f2ce296166222f02993e8df17e718`

## 燒錄後 JTAG 原始結果

### 燒錄後初次讀取

初次讀取的 status：

```text
Master status_probe: 101ECAE339BC82FF
Slave  status_probe: 201E44C1205082EF
```

依既有 status mapping，Master 為 `0x82FF`；Slave 當時為 `0x82EF`，只看到短暫的 `pps_valid` 活動，`time_valid` 仍未成立。

### 等待約 60 秒後讀取

完整 runtime log：

- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SYSCLK-625-20260817/runtime_60s.log`
- SHA-256：`621dae5ef439ac529d29434c0e2f8ec5f879a793984e718f1a082718900ad3aa`

關鍵結果：

```text
Master status_probe: 101ECAC1295082FF
Master WDIAGS_MODE: 2
Master WDIAGS_PTP:  00000006
Master WDIAGS_SSTAT: 00000000
Master WDIAGS_PSTAT: 00000001

Slave status_probe: 301E44C120BC82CF
Slave WDIAGS_MODE: 3
Slave WDIAGS_PTP:  00000009
Slave WDIAGS_SSTAT: 00000001
Slave WDIAGS_PSTAT: 00000001
Slave WDIAGS_PTP_META: 03020409
Slave WDIAGS_FOREIGN_META: 03000001
Slave WDIAGS_UCNT: 00000020
Slave WDIAGS_CKO:  02B17401
```

因此 60 秒後：

- Master `time_valid=1`、`pps_valid=1`
- Slave `time_valid=0`、`pps_valid=0`
- Slave CPU 仍在執行：`cpu_reset=0`、`fault=0`、marker `0xB004`、PTP/servo 計數仍有活動

SoftPLL 原始觀測：

- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SYSCLK-625-20260817/raw_60s.log`
- SHA-256：`f91f831d4a6312b979f78ca4d5cd1f9ff8e05a15416ac55f039bf13d95b68ded`

Slave 關鍵原始輸出：

```text
RAW_CORE: CTRL=00000001 SSTAT=00000001 PSTAT=00000001 PPS_ESCR=00000000
RAW_LOCK: RESULT=00000001 UNLOCKED=000E8B6F HELPER=00000000 MAIN=00000000
RAW_HW: RCER=00000001 OCER=00000001 TRR_CSR=00020000
RAW_COUNTER: TAG_VALID=00000000 TRR_WRITE=00000000 TAG_SOURCE=0B5EFC34 REF=05D45A46 FEEDBACK=0659136C
```

### 60 秒 clock activity

原始檔案：

- `/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SYSCLK-625-20260817/clock_activity_60s.log`
- SHA-256：`ae76ecc4c44034ed34ef0ee909f95c14908804038a41bf7726cb67c543062c32`

```text
DE5 [1-11.1] BEGIN REF=44180 DMTD=42273 RX=17025 PHY_READY=1 RX_LOCK_REF=1 RX_LOCK_DATA=1
DE5 [1-11.1] END   REF=47945 DMTD=44162 RX=20744 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1
DE5 [1-11.2] BEGIN REF=61023 DMTD=57823 RX=60325 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1
DE5 [1-11.2] END   REF=64752 DMTD=59677 RX=64100 PHY_READY=1 RX_LOCK_REF=0 RX_LOCK_DATA=1
```

## Observation

1. 62.5 MHz system-clock 版本可以成功 compile、燒錄，且沒有破壞兩片的 PHY data lock。
2. Master 維持完整 WR valid 狀態。
3. Slave 在燒錄後曾短暫出現 `0x82EF`，但等待 60 秒後回到 `0x82CF`，因此不能把短暫狀態當成成功同步。
4. Slave `SSTAT=1`、`PSTAT=1`、`RAW_LOCK RESULT=1`，目前仍沒有可宣稱 SoftPLL locked 的證據。
5. Slave 的 CPU、PTP、foreign master 與 servo update 仍有活動；所以本次結果不支持「CPU 沒啟動」或「PTP 完全沒有封包」的解釋。
6. 60 秒內兩片的 reference、DMTD、recovered RX clock counter 都有增加，且 `RX_LOCK_DATA=1`；reference lock 在觀測窗內變動，仍是後續線索。

## Conclusion

本次實驗只支持以下結論：

> 將 WR system clock 與 62.5 MHz firmware/core model 對齊，是必要且合理的修正，但單獨做這項修正仍不足以讓 Slave 完成 WR 時間同步。兩片 DE5a 尚未達到 `link_ok=1、time_valid=1、pps_valid=1` 的共同成功條件；目前不能宣稱 Slave servo 已成功。

## Next Step

保留本次 bitstream 證據，不再把 clock frequency 當作唯一根因。下一輪維持 62.5 MHz 版本，只選一個與 Slave reference/SoftPLL 輸入相關的變因，優先檢查並以唯讀證據確認：

1. `PPS_ESCR`、`SSTAT/PSTAT` 與 raw lock 欄位是否由 reference-lock transition 推動。
2. Slave 的 DMTD tag input 是否真的產生有效 `TAG_VALID/TRR_WRITE`，而不只是 clock counter 有活動。
3. 若 tag input 仍無有效事件，再針對 DMTD/reference clock polarity 或 generated PHY input wiring 做單一 A/B 實驗。

下一次仍須先 commit/push，pain fetch/checkout 明確 commit，建置、燒錄後立即新增實驗紀錄。

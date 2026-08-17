# EXP-WRPC-SLAVE-SI5340-READBACK-20260817

## 實驗名稱

Slave SI5340 `0x0339` 寫入後讀回觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-SI5340-READBACK-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave 單一診斷變因燒錄實驗

## 想驗證什麼

上一輪已觀察到 Slave 的 DCO runtime FSM 能完成交易，且 ACK sticky bit 沒有觀察到 NACK，但這仍不能證明 SI5340 真的接受 page/register 寫入。本輪要進一步確認：

1. page 3 的 `0x0339` 寫入後是否能讀回。
2. 讀回值是否符合最後一次 DPLL/HPLL mask command。
3. 即使 register path 可讀回，Slave 是否因此進入 SoftPLL lock 與 `time_valid=1`。

SI5340 Rev. D reference manual 將 `0x0339` 定義為 `N_FSTEP_MSK`，其 bit 0/1 分別對應 N0/N1 的 FINC/FDEC mask：
`https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf`

## 相較 baseline 唯一修改

Master 完全不變，維持歷史成功 baseline `9f848ec` / `master-diagnostic-baseline-20260817`。

Slave 只增加 SI5340 readback observability：

- 將 DCO runtime state 擴充為：原本四筆 write transaction 後，再執行 page 3 select 與 `0x39` read transaction。
- 將讀回值、valid、sticky ACK/NACK、mask match 與 readback count 放到新的 `WR_DCO_READBACK_SLAVE` JTAG probe（instance index 10）。
- 不修改 FINC/FDEC direction、`0x0339` mask data、FSTEPW、SoftPLL、PTP、PHY、Master role。
- 原有 `WR_DCO_STATE_SLAVE` probe 與既有欄位保留。

## Git / branch / provenance

- Branch：`exp/master-9f-observability`
- Source commit：`aa0825ad451beb788148e339aa593fa40f656b1a`
- Commit message：`加入Slave SI5340暫存器讀回觀測`
- Master baseline tag：`master-diagnostic-baseline-20260817`
- Quartus：Quartus Prime 17.0 Build 595（2017-04-25）
- Quartus binary：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

### Source / build hash

- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SOF SHA-256：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`

## Compile 結果

pain 從 GitHub checkout `aa0825a` 後使用 Quartus 17 編譯：

```text
Full Compilation was successful
Fitter Status: Successful
TIMING_CLOSED=NO
WORST_SETUP_SLACK_NS=-0.179
WORST_HOLD_SLACK_NS=-3.497
WORST_RECOVERY_SLACK_NS=0.663
WORST_REMOVAL_SLACK_NS=0.332
UNCONSTRAINED_CLOCKS=4
UNCONSTRAINED_INPUT_PATHS=522
UNCONSTRAINED_OUTPUT_PATHS=85
```

這代表 SOF 可以產生，但本版本仍未完成 timing closure；不能將 compile 成功解讀成 WR 同步成功。

## 燒錄結果

只燒錄 Slave，Master 不重新燒錄：

```text
Programming cable: DE5 [1-11.2]
Programming file: DE5a_wr_slave_jtag.sof
Programmer checksum: 0x309FA629
Device: 10AX115N2F45@1
JTAG ID code: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Programmer: successful, 0 errors, 0 warnings
```

## JTAG / runtime 原始結果

完整原始檔案保存在：

`artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/`

### Master control

30 筆時間序列最後一筆有效資料：

```text
status_low=FF
wr_mode=2
time_valid=1
pps_valid=1
link_up=1
PTP_RX=0x00006F60
PTP_TX=0x000105C4
```

`read_clock_activity.tcl` 也觀察到 Master 的 `TIME_VALID=1`、`PPS_VALID=1`、`LINK_UP=1`、`LINK_OK=1`。因此本輪 Master 仍符合已知成功控制基準。

### Slave DCO state

```text
DCO_STATE A=0005000200000320 B=0005000200000320
```

依既有欄位定義，表示：

- completed DCO steps：`2`
- runtime state low bits：`0`
- bus busy：`0`
- static configuration ready：`1`
- sticky NACK bit：`0`

### Slave readback probe

```text
DCO_READBACK value=000500020002050D
```

欄位解碼：

- 最近一次 `0x0339` readback value：`0x0D`
- readback valid：`1`
- sticky ACK/NACK error：`0`
- readback matches expected HPLL/N1 mask：`1`
- completed readback count：`2`
- completed DCO step count：`2`

這是本輪最重要的新證據：在觀測期間，page 3/`0x0339` 讀回值與最後一次 HPLL/N1 mask command 一致。

### Slave runtime / synchronization

30 筆唯讀時間序列中，Slave 有 28 筆 accepted frame、2 筆因 snapshot validity 不足而 rejected/retried。最後一筆有效 frame 為：

```text
status_low=EF
wr_mode=3
time_valid=0
pps_valid=1
link_up=1
spll_locked=0
WDIAGS_SSTAT=0x00000000
WDIAGS_PSTAT=0x00000001
WDIAGS_PTP_RX=0x00000000
WDIAGS_PTP_TX=0x00000000
WDIAGS_CKO=0x00000000
WDIAGS_SETP=0x00000000
WDIAGS_UCNT=0x00000000
```

`read_clock_activity.tcl` 的 Slave 讀值顯示 `TIME_VALID=0`、`PPS_VALID=1`、`LINK_UP=1`、`LINK_OK=1`；因此光路/link 與 PPS 輸出仍在，但尚無完成 WR time validity 的證據。

## Observation

1. FPGA-side DCO FSM 完成 count 由上一輪的 7 重新開始後增加到 2，且 bus 最後回到 idle。
2. 本輪 readback valid，值為 `0x0D`，符合 HPLL/N1 mask command。
3. ACK/NACK sticky error 仍為 0；目前沒有 NACK 證據。
4. Slave 仍沒有 `spll_locked=1`、`time_valid=1` 或 `WDIAGS_UCNT` 活動。
5. Master 在同一輪仍符合 `status=0xFF / MODE=2 / time_valid=1 / pps_valid=1` 的控制基準。
6. 讀回 `0x0339` 只能證明 register path 的一部分可被驗證，不能直接證明 FINC/FDEC 已讓實體輸出 clock 改變。

## Conclusion

本實驗**證明**：

- Slave 的 FPGA runtime DCO transaction sequence 可以完成。
- 在本輪觀測中沒有抓到 I2C NACK。
- page 3/`0x0339` 的讀回值有效，且與最後一次 HPLL/N1 mask command 一致。
- Master known-good role 沒有被本輪 Slave 變更破壞。

本實驗**尚未證明**：

- `0x001D` FINC/FDEC command 是否造成 SI5340 輸出頻率實際改變。
- DCO correction 是否已形成有效的 physical clock feedback。
- Slave SoftPLL 是否 lock。
- Slave 是否已完成 White Rabbit synchronization。

因此問題可更保守地收斂為：

> SI5340 page/register transaction path 已有 ACK 與 `0x0339` readback 證據；目前仍缺少「DCO command 造成目標 clock 實際改變」的證據，Slave servo/feedback 尚未 lock。

## Next Step

建立新的單一變因實驗，不修改 Master、PHY、PTP、PI、FINC/FDEC direction 或 register data，只增加可重複的 output-clock frequency/activity observability，並把 DCO step 前後的頻率差與 `helper_error / spll_locked / time_valid` 對齊記錄。只有在確認 clock effect 後，才進一步判斷 FINC/FDEC 方向或 DDMTD/feedback mapping。

## Artifact hashes

完整 hash 清單見：

`artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/log_sha256.log`

重要 raw log SHA-256：

- `program.log`：`5742be4916f0cb9f7c8b00fa212d16d6f619037135999c40b03e85eb3e6adc66`
- `runtime_snapshot.log`：`67a4f42c1d37fdc81a2ba2481321fe9a46c84f13990530d694a5f455aa8caa19`
- `dco_state.log`：`cc223b5529b3458dbfb2a11a9e1e0ecda7533520f0fc9b2abf7f14a66a69a7f2`
- `dco_readback.log`：`0e841fa9890d28cd9ee9d9f60da8304fef614e04ff6eabc663b365973e25f781`
- `runtime_timeseries.log`：`0be3caa45241ed9b71abf7fcd3708a0d000e8f7dfdf361595b4e67bedb348a94`

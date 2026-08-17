# EXP-WRPC-SLAVE-SI5340-PAGE-SEQUENCE-20260817

## 實驗名稱

修正 Slave SI5340 DCO 的 page 3 / page 0 runtime 暫存器序列

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-SI5340-PAGE-SEQUENCE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave 單一 RTL 變因燒錄實驗

## 想驗證什麼

確認 Slave 的 DCO runtime transaction 雖然已完成，是否其實把 `N_FSTEP_MSK` 寫到了錯誤的 page。目標是讓 SoftPLL HPLL correction 真正作用到 SI5340 的 N1 divider，再觀察 helper error、SoftPLL lock、servo state 與 `time_valid` 是否開始收斂。

成功判準：

1. 每次 DCO update 依序完成四筆 I2C transaction：選 page 3、寫 `0x0339`、選 page 0、寫 `0x001D`。
2. Slave 的 `completed_steps` 持續增加，且 helper error 不再固定於 clamp。
3. Slave 能進入 `spll_locked=1`、servo `TRACK_PHASE` / `WAIT_OFFSET_STABLE`，最後穩定 `time_valid=1`、`pps_valid=1`。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

- runtime FSM 從三筆 transaction 擴充為四筆 transaction。
- 先寫 page register `0x01 = 0x03` 選 page 3。
- 在 page 3 寫 `0x39`，即完整位址 `0x0339` 的 `N_FSTEP_MSK`。
- 再寫 `0x01 = 0x00` 回到 page 0。
- 最後寫 `0x1D` 發出 FINC/FDEC。

Master、Master firmware role、PHY、PTP、PI、lock threshold、DDMTD source、DDMTD polarity 與 DCO direction 均未修改。

這個暫存器定義以 [Skyworks Si5341/Si5340 Rev. D Reference Manual](https://www.skyworksinc.com/-/media/Skyworks/SL/documents/public/reference-manuals/Si5341-40-D-RM.pdf) 為依據：`0x0339` 是 `N_FSTEP_MSK`，`0x001D[0]` / `[1]` 分別是 FINC / FDEC。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- RTL source commit：`3dbd164ca34d72d572e120ceb200a976f472eb57`
- Master 固定 baseline tag：`master-diagnostic-baseline-20260817`
- Quartus：Quartus Prime 17.0 Build 595
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave SOF SHA-256：`0745d4acbb77ca053f0f7830369e28ce08fc894168efb1c0c6c8176716ed6ea5`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- DCO RTL SHA-256：`a78c55ecf7bcb685bd73d4d5e4c6b93c114622eb5f5f7b3783f0024fcfdf5b6b`
- Static SI5340 table RTL SHA-256：`a42138acbe6113e17148a79f422ca3bde13d85c298ab6872a89135d6b64ac671`

## Compile 結果

pain 使用：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_sh --flow compile quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.qpf
```

結果：

```text
Quartus Prime Full Compilation was successful. 0 errors
Fitter Status : Successful
Logic utilization : 5,094 / 427,200 ALMs
Total registers : 7,180
Total RAM Blocks : 113
```

本次 compile-only 證據只代表新的 RTL 已成功產生 SOF，不代表硬體同步成功。

## 燒錄結果

待燒錄後立即補上：

```text
Programming cable:
JTAG ID:
Programmer checksum:
Configuration result:
```

## JTAG/runtime 原始結果

待燒錄後執行既有的 `read_wb_runtime.tcl`、`read_dco_state.tcl`、`read_dco_activity.tcl` 與 `read_wb_timeseries_session.tcl`，並將原始檔案放在：

```text
artifacts/EXP-WRPC-SLAVE-SI5340-PAGE-SEQUENCE-20260817/
```

## Observation

Compile 階段確認只有 Slave DCO page sequence 產生 RTL 變化；新的 SOF 已產生，尚未以此 SOF 燒錄，因此目前還不能對 Slave runtime 或同步狀態下結論。

## Conclusion

目前只能確認 RTL 修正與 Quartus compile 成功。是否解除 Slave servo 卡點，必須等燒錄後以 `completed_steps`、helper error、`spll_locked`、servo state、`time_valid` 與 `pps_valid` 的原始 JTAG 證據判斷。

## Next Step

只燒錄這一版 Slave SOF，Master 保持 `9f848ec` / `f19bea8` known-good baseline。燒錄完成後立即保存 programmer log，再執行至少 60 秒的唯讀 JTAG time-series；若沒有 `time_valid=1`，依證據進入下一個 Slave 單一變因，不回頭改 Master role。

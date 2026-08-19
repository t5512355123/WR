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

Slave 於 2026-08-17 23:13（Asia/Taipei）使用 `DE5 [1-11.2]` 燒錄；Master 未重新燒錄，維持歷史成功 baseline。

```text
Programming cable: DE5 [1-11.2]
JTAG ID: 0x02E660DD
Programmer checksum: 0x30A15E22
Configuration result: Configuration succeeded -- 1 device(s) configured
Quartus Programmer: successful, 0 errors, 0 warnings
```

原始 programmer log：

```text
artifacts/EXP-WRPC-SLAVE-SI5340-PAGE-SEQUENCE-20260817/exp_wrpc_slave_si5340_page_sequence_20260817_program.log
SHA-256: da787d337708c895dda67992a11012b6e424cb17be17c6fb855962d398fde497
```

## JTAG/runtime 原始結果

燒錄後立即執行既有的 `read_wb_runtime.tcl`、`read_dco_state.tcl`、`read_dco_activity.tcl` 與 `read_wb_timeseries_session.tcl`。所有原始檔案均保存於：

```text
artifacts/EXP-WRPC-SLAVE-SI5340-PAGE-SEQUENCE-20260817/
```

主要原始檔案與 SHA-256：

```text
exp_wrpc_slave_si5340_page_sequence_20260817_runtime_snapshot.log
f445571a119c529f77849c4e47a38273ff01a7400256bc4d2ca20a6b5dfb8537

exp_wrpc_slave_si5340_page_sequence_20260817_dco_state.log
d61ed1b26d35cdf271ac414fb759c844f7c60a608d1e1a8060113a5582f66675

exp_wrpc_slave_si5340_page_sequence_20260817_dco_activity.log
f13570eb82f6cbebb0ee9daf0a2770c10ca261738c38c0cb9c8ad32f87d577ef

exp_wrpc_slave_si5340_page_sequence_20260817_dco_state_final.log
0195183bcbabd7eee35d81152a644ba2c08cb9d3d9e29bafc578de1cf1c809a9

exp_wrpc_slave_si5340_page_sequence_20260817_runtime_timeseries.log
b8a5812eb793416b250bc00c200fb67591afa039a8ccccfe394be3a69016dfbe

exp_wrpc_slave_si5340_page_sequence_20260817_runtime_final.log
ff7e1219eade5dbb27518d87001c991b403eb14b14f9ba89df6a62c4317e08e0
```

燒錄後的關鍵 raw evidence：

```text
Master DE5 [1-11.1]
  cpu_marker: 0x0000B004
  WDIAGS_MODE: 2
  WDIAGS_PTP: 6
  link/time_valid/pps_valid: 1/1/1
  PTP RX/TX: 0x00006EC7 / 0x0000FACE（最後 snapshot）

Slave DE5 [1-11.2]
  cpu_marker: 0x0000B004
  WDIAGS_MODE: 3
  WDIAGS_PTP: 6
  status_low: 0xEF
  link/time_valid/pps_valid: 1/0/1（有效 frame 的主要狀態）
  WDIAGS_SSTAT: 0x00000000
  WDIAGS_PSTAT: 0x00000001
  WDIAGS_UCNT: 0x00000000
  WDIAGS_CKO / WDIAGS_SETP: 0x00000000 / 0x00000000
  PTP RX/TX: 0x00000000 / 0x00000003（最後 snapshot）
```

DCO readback：

```text
DCO_STATE final: 0005002100000320
  completed_steps = 0x0021
  rt_state = 0
  bus_busy = 0
  static_ready = 1
  dco_error = 0
```

這表示 runtime FSM 有完成多次 transaction，且最後不在 busy/error 狀態；它證明的是 FPGA 內部交易流程完成，不等於已證明 SI5340 輸出頻率修正有效。

## Observation

1. Quartus compile 與 Slave programming 均成功；本次實驗只改變 Slave 的 DCO page sequence，Master 沒有改動。
2. `completed_steps` 由先前 baseline 的交易完成狀態持續增加，最終讀到 `0x0021`；`rt_state=0`、`bus_busy=0`、`dco_error=0`。因此四筆 runtime transaction 的 FSM handshake 至少已被執行並返回 idle。
3. Slave 在有效觀測列中維持 `MODE=3`、`link_up=1`、`pps_valid=1`，但沒有進入 `SSTAT` servo state，`PSTAT.locked=0`、`UCNT=0`、`CKO=0`、`SETP=0`，`time_valid` 沒有升為 1。
4. 60 秒雙板 session 的 Master 部分維持歷史 baseline 的 `MODE=2` 與 `status=0xFF`；Slave 部分可取得有效 frame，但也出現少量 link/runtime transient，不能把短暫的 `link_up=1` 視為同步完成。

## Conclusion

本次實驗的證據支持：

- Slave 的新 SOF 可以成功配置。
- DCO runtime FSM 可以完成 transaction，且沒有顯示 busy/error。
- Master 的已知成功 role 沒有被這次變更破壞。

本次實驗的證據不支持：

- Slave 已經 SoftPLL lock。
- Slave 已進入 servo tracking。
- 兩張 DE5a 已完成 White Rabbit 時間同步。

因此本實驗結果為「compile/program 成功，功能驗證未通過」，不能標記為同步成功。由於 page sequence 修正只證明 FPGA 交易流程，不足以證明 SI5340 的實體 feedback 已被正確驅動，下一輪必須維持 Master 不變，針對 Slave 的 SI5340 feedback/方向或 DCO 寫入有效性做下一個單一變因驗證。

## Next Step

不要修改 Master role，也不要再改 PHY。下一個 Slave 實驗先利用現有 read-only evidence 確認 DCO direction 與 SI5340 feedback 是否一致；若方向仍未收斂，再只反轉 Slave DCO FINC/FDEC direction，重新 compile、燒錄並立即建立另一份實驗紀錄。若方向修正仍沒有 `SSTAT`/`UCNT` 活動，則應把焦點轉為 SI5340 I2C transaction 的 ACK/錯誤可觀測性，而不是繼續猜測 role 或 PHY。

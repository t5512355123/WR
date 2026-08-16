# EXP-WRPC-DCO-STATE-OBS-20260817：DPLL request/FSM 唯讀狀態觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-DCO-STATE-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：單一診斷變因；只新增 DPLL request/FSM 唯讀觀測，Master 維持原 image。

## 這次想驗證什麼

上一輪 DPLL-only 觀測得到：

```text
DPLL source=0004 destination=0004 accepted=0000 done=0000
```

這只能證明 load 次數跨過目前的 CDC 計數路徑，不能說明：

1. DPLL data 是否真的改變。
2. `dpll_pending` 是否被設定。
3. controller 是否進入 runtime I2C FSM。
4. DPLL transaction 是否完成。

本輪新增一個 JTAG 唯讀 probe，直接讀取 DPLL data、pending、FSM state、bus state 與 one-shot 狀態；不改變 DPLL 控制條件、SI5340 register data、PHY、DMTD、PTP 或 servo 演算法。

## Git、分支與工具

- GitHub repository：`git@github.com:t5512355123/WR.git`
- 分支：`exp/jtag-runtime-observability`
- 本輪 source commit：`8c8b4442988dd9040190f45eb045aa9114991398`
- pain checkout：detached HEAD，固定於 `8c8b444`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`

## 相較 baseline 唯一修改了什麼

只新增下列唯讀觀測：

- `si5340a_controller_dco.v` 新增 `oDCO_DPLL_STATE` 64-bit snapshot。
- Slave top 新增 `WR_DCO_DPLL_STATE_SLAVE` probe，instance index 10。
- `read_dco_diag.tcl` 解碼 DPLL input/previous data、`rt_state`、pending、方向與 I2C FSM flags。

沒有修改：

- DPLL-only 的 transaction gate。
- SI5340 page/register/FINC/FDEC data。
- `g_softpll_reverse_dmtds`。
- PHY、QSFP lane、reference clock、DMTD clock。
- wrpc-sw、PTP、servo 演算法與 firmware MIF。

## Master/Slave image provenance

### Master

- 沿用既有 baseline image，沒有重新燒錄。
- source commit：`5e816ead4240878740dc259a5d9c55482f7dd180`
- MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`
- SOF SHA-256：`e629810b214379e283b4ef9aba0867126ffedcdc85a3e25134bb84eb0871ec8a`

### Slave

- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA-256：`2afa5aa2e9044a6cfede42c695fbe7d2cae4ce882fb49ea9033a1bc1da7c73f0`
- SOF SHA-256：`c55b522a548ec26f6bca23a2c27cb8ec9bb3a1b2ea3d330865e8340b9b0e6669`
- Fitter：Successful
- Full Compilation：successful，0 errors；Quartus log 顯示 276 warnings
- Timing：`timing_closed=NO`
- Worst setup slack：`-0.172 ns`
- Worst hold slack：`-3.561 ns`
- Worst recovery slack：`1.137 ns`
- Worst removal slack：`0.353 ns`
- Unconstrained clocks/input/output：`3 / 742 / 79`
- Compile log SHA-256：`d459a9c7adf79c3ddd065d485ba0a2e4c3fc9038d099b3d4ad5117a3379487f0`

## 燒錄結果

只燒錄 Slave：

```text
Cable: DE5 [1-11.2]
SOF checksum: 0x30A4DF88
Device JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- 燒錄時間：2026-08-17 07:17:14–07:17:32（pain）
- Programmer log：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-STATE-OBS-20260817/program_slave.log`
- Programmer log SHA-256：`c3364ecdc0ae4054ce6b84786da28d11c079c6bd2a039d636ab1291e5c88fe78`

## JTAG/runtime 原始結果

### DPLL request/FSM snapshot

執行命令：

```text
quartus_stp -t scripts/jtag/read_dco_diag.tcl 1000
```

完整原始檔：

- pain：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-STATE-OBS-20260817/dco_state.log`
- SHA-256：`9a3a084bdf951244abef81edd27d7f93e385dc86ab258db2e32b20097a069283`

Master 沒有新增 probe，因此工具回報 `No In-System Sources and Probes instance was found`；這是預期結果，因為本輪只燒錄 Slave。Slave 讀值如下：

```text
DCO_DIAG label=BEGIN_HPLL source=6514 destination=6514 accepted=0DE7 done=0000
DCO_DIAG label=BEGIN_DPLL source=0004 destination=0004 accepted=0000 done=0000
DCO_DPLL_STATE prev_data=8000 input_data=8000 rt_state=0 dpll_pending=0 hpll_pending=1 select_dpll=0 direction=0 bus_state=0 static_ready=1 bus_done=0 prev_valid=1 done_once=0
DCO_DIAG label=END_HPLL source=8535 destination=8535 accepted=0DE7 done=0000
DCO_DIAG label=END_DPLL source=0004 destination=0004 accepted=0000 done=0000
DCO_DPLL_STATE prev_data=8000 input_data=8000 rt_state=0 dpll_pending=0 hpll_pending=1 select_dpll=0 direction=0 bus_state=0 static_ready=1 bus_done=0 prev_valid=1 done_once=0
```

這表示在兩次讀取之間：

- DPLL source/destination load count 都是 `4`，但 DPLL accepted/done 都是 `0`。
- DPLL current data 與 previous data 都是 `0x8000`。
- `dpll_pending=0`，runtime FSM 仍在 `rt_state=0`、`bus_state=0`，沒有進入 DPLL I2C transaction。
- `static_ready=1`，但這不等於 DPLL transaction 已完成，也不等於 SoftPLL 已 lock。

### 60 秒唯讀 runtime session

執行命令：

```text
quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 60 1000 5
```

完整原始檔：

- pain：`/home/b10504072/04_WR/build/artifacts/EXP-WRPC-DCO-STATE-OBS-20260817/runtime_60s.log`
- SHA-256：`e371d283263a9e3584aab15e8f6bd7ad6d4b406905bc539019e59cf696de3588`

原始結果摘要：

- `SESSION_TIME_SERIES_DONE`：已出現；60 個 sample session 正常結束。
- Master：`accepted=60/60`。
- Slave：`accepted=52/60`，`8/60` 在五次 retry 後未接受；這是 JTAG snapshot/frame consistency 的觀測結果，不把它解讀成 WR link 斷線。
- Slave `status_low` 在 `0xCF/0xEF` 間變化：`link_up=1`，`time_valid=0`；`pps_valid` 會在 0/1 間變化，但沒有穩定有效。
- Slave `WDIAGS_SSTAT` 主要為 `1`，另有少量讀值為 `0` 或 `2`；沒有觀察到 `TRACK_PHASE` 所需的 state `4/5`。
- Slave `WDIAGS_PSTAT=1` 且 `spll_locked=0`；`WR_LOCK` 的 `unlocked` 維持高值，沒有出現 SoftPLL lock 證據。
- Slave `foreign_count=1`、`wr_config=3`、`is_wr=1`、`calibrated=1`；PTP RX/TX 與 raw tag/IRQ counters 持續增加，表示 runtime 與 parent/PTP/servo 資料路徑仍有活動。
- `HELPER_ERROR` 在 session 中可到達 `-150000` 與 `+150000` 邊界，`HELPER_OUTPUT` 對應出現 `0xFFFB` 與 `0x0005`；這支持 helper 輸出仍在飽和邊界附近，不能視為已鎖定。

## Observation

本輪觀測直接回答了「DPLL request 是否真的發生」：沒有。雖然 load count 已經跨過目前的計數路徑，但 DPLL data 沒有改變、pending 沒有成立、FSM 沒有執行 DPLL transaction。另一方面，Slave 並非完全沒有 runtime 活動：PTP、tag/IRQ 與 servo 相關計數仍增加，parent record 也存在；真正未通過的是 SoftPLL lock 與後續 `time_valid`。

因此目前證據把問題優先收斂到：

```text
servo/helper 輸出與 DPLL data 形成條件
        -> DPLL request 是否產生
        -> SoftPLL lock / time_valid
```

但這輪尚不能判定是 helper 參數、feedback clock、SI5340 實際輸出，或其他上游條件造成；也不能把 CDC 宣稱為已證明根因。

## Conclusion

本輪新增的 DPLL request/FSM 唯讀觀測版已成功 compile、燒錄並完成 60 秒 runtime session。證據支持：Slave 的 PTP/servo runtime 有活動、link 仍為 up，但本輪沒有發生 DPLL data change 或 DPLL I2C transaction；`PSTAT.locked=0`、`time_valid=0`，因此 White Rabbit 時間同步仍未完成。

證據不支持下列說法：

- 不能說 DPLL transaction 已成功。
- 不能說 `static_ready=1` 就代表 SoftPLL locked。
- 不能說 CDC 已經是根因；本輪只證明目前沒有進入 DPLL request/FSM。

## Next Step

下一步先做 source-level、唯讀的 servo/helper 與 DPLL data 形成條件審查；暫不重新燒錄、不寫入控制 register。要先確認 `0x8000` 是「尚未產生 request 的預設值」還是「feedback/servo 計算後的實際固定值」，再決定是否需要下一個單一變因實驗：

- data 未改變：先查 servo 輸出與 DPLL data 形成條件。
- data 改變但 pending 未成立：查 controller request compare/gate。
- pending 成立但 FSM 不完成：查 I2C start/busy/ACK。
- transaction 完成但 helper 仍飽和：查 SI5340 實際輸出與 feedback clock，不再把 CDC 當成已證明根因。

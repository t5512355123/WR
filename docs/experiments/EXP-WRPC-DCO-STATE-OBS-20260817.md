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

本節在燒錄完成後補入，保留原始 log SHA-256 與重要欄位；在補入前，本紀錄只宣稱 image configuration 成功，不宣稱 WR synchronization 成功。

## Observation

待讀取新 probe 與 runtime time-series 後填寫。

## Conclusion

目前唯一由本次結果支持的結論是：新增 DPLL request/FSM 唯讀觀測版已成功 compile 並成功燒錄到 Slave。尚無證據支持 Slave 已達到 `PSTAT.locked=1`、`time_valid=1` 或 `pps_valid=1`。

## Next Step

在同一顆已燒錄的 Slave 上執行 `read_dco_diag.tcl` 與唯讀 runtime time-series；不重新燒錄、不寫入控制 register。依照 snapshot 判斷下一個單一變因：

- data 未改變：先查 servo 輸出與 DPLL data 形成條件。
- data 改變但 pending 未成立：查 controller request compare/gate。
- pending 成立但 FSM 不完成：查 I2C start/busy/ACK。
- transaction 完成但 helper 仍飽和：查 SI5340 實際輸出與 feedback clock，不再把 CDC 當成已證明根因。

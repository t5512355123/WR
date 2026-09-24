# 實驗紀錄：Slave DCO controller 狀態唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-STATE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/master-9f-observability`
- Git commit：`0593519b7e8a2b8b007554689c2a20d8133632fe`

## 這次想驗證什麼

在上一個 DCO handshake 實驗已看到 completion counter 增加，但 Slave 仍未同步。本次不再修改控制行為，只增加 Slave-only JTAG probe，直接觀察 DCO request、pending、I2C controller state、transaction start/done 與 completion counter 的狀態鏈，判斷卡點究竟在 request、I2C controller、DCO feedback，或是 JTAG snapshot。

## 相較 baseline 唯一修改

只在 Slave 增加唯讀觀測：

- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd` 新增 probe index 9。
- `quartus/jtag_runtime_diag/si5340a_controller_dco.v` 暴露 `oDCO_DEBUG`，但不改任何控制輸出。
- `scripts/jtag/read_dco_state.tcl` 讀取 probe index 9。

原有 DCO handshake、Master role、PHY、ref channel、clock polarity、DMTD mapping 與 SoftPLL 演算法均未修改。Master 保持 exact `9f848ec` 映像。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave SOF SHA-256：`360044fe97ae0062d77765ef12b5d6132763a0ef74ececaaeb8b0156ca5fa21f`
- Fitter：Successful
- Timing：`TIMING_CLOSED=NO`；worst setup slack `-0.393 ns`
- Build artifact：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-STATE-20260817/`

Master 維持已知成功的 `9f848ec` 映像：

- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- 目標 role：`WDIAGS_MODE=2`、`WDIAGS_PTP=6`

## 燒錄結果

Slave 使用 cable `DE5 [1-11.2]`，時間 17:49:58--17:50:17：

```text
Using programming cable "DE5 [1-11.2]"
Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x309F55AB
Device 1 contains JTAG ID code 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

- Programmer log SHA-256：`b8918402c43266ad2b24ee86ae6022eaf37e9ac01b47a883f48d82e7ab0259e3`
- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-STATE-20260817/program_slave.log`

## JTAG/runtime 原始結果

### DCO controller state probe

原始輸出：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-STATE-20260817/dco_state.log`

```text
DCO_STATE_CONFIG gap_ms=1000
=== DE5 [1-11.1] ===
error: ERROR: No In-System Sources and Probes instance was found.
=== DE5 [1-11.2] ===
DCO_STATE A=00BF000700002B20 B=00BF000700002B20
```

兩個 64-bit 狀態值相同。依本次 probe map 解碼：

- `rt_state=0`：runtime DCO state machine idle。
- `bus_state=0`、`bus_done=0`：取樣當下沒有進行中的 I2C transaction，也沒有新的 done event。
- `static_ready=1`：SI5340 static initialization 已完成。
- `dpll_pending=0`、`hpll_pending=0`：取樣當下沒有待處理的 DPLL/HPLL request。
- `i2c_state=0`、`runtime_start=0`、`bus_start=0`：取樣當下沒有新的 runtime transaction start。
- `dco_step_count=0x0007`：controller 曾記錄 7 次 DCO step request。
- `hpll_prev_data=0x00BF`：保存的 HPLL previous data 為 `0x00BF`。

Master 端沒有 probe index 9，因此 `read_dco_state.tcl` 對 `DE5 [1-11.1]` 的錯誤是預期結果，不代表 Master 燒錄失敗。

### 10 秒 read-only runtime session

原始輸出：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DCO-STATE-20260817/runtime_10s.log`

Master 端多數有效取樣維持：

```text
status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
WDIAGS_PTP=6
```

Slave 端有效取樣主要維持：

```text
status_low=EF time_valid=0 pps_valid=1 wr_mode=3 link_up=1 spll_locked=0
WDIAGS_PTP=4 或 6
```

Slave 的代表性原始欄位為：

```text
WR_SPLL_ACTIVITY: REF_COUNT=00000000 TAG_COUNT=00000000
                 HELPER_ERROR=00000000 HELPER_OUTPUT=00000000
                 VISIT_MASK=00000000 TRANSITIONS=00000000 LAST_STATE=00000007
WR_SPLL_EVENTS: TAG_VALID_COUNT=00000000/00000000
                TRR_WRITE_COUNT=00000000/00000000
WDIAGS_SSTAT:00000000 WDIAGS_PSTAT:00000001 WDIAGS_PTP:00000004
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 link_up=1 spll_locked=0
WR_LOCK: result=0 spll_locked=0 polls=0 unlocked=0
```

部分 JTAG frame 因跨多組 mailbox 讀取而標示 `FRAME_VALID=0`，因此只使用 `accepted=1` 的列作為證據；未把不完整 frame 拼成結論。

## Artifact hashes

- DCO state log SHA-256：`c1bb7abd38ff3fa9ecd4701b9b1f8014edb959fe520a0bf9fd4968b83588feb9`
- Runtime log SHA-256：`143d10bd1eb817fd7351605e8a9abdf5cae03c5adc85dd8fe5649fe56cf59222`

## Observation

1. 本次新增的 DCO state probe 可以正常從 Slave 讀回；取樣當下 controller 為 idle、static ready、無 pending request，且歷史 step counter 為 7。
2. 這個狀態能證明「本次讀取時沒有正在執行的 DCO transaction」，但不能證明 DCO 永遠沒有動，也不能單獨證明 I2C 或 SI5340 是根因。
3. Master runtime 仍維持已知基準的 `status=0xFF、mode=2、PTP=6、time_valid=1`。
4. Slave link 與 PPS 相關狀態可出現有效值，但 `time_valid=0、spll_locked=0`，且本次 session 的 SoftPLL activity/event counters 多數為 0；因此仍未形成可宣稱同步的證據。
5. 本次 read-only session 的部分 frame 不完整，已依 `FRAME_VALID`/`accepted` 過濾，不能把讀值不穩定誤判為硬體狀態轉換。

## Conclusion

本次實驗成功完成「Slave DCO state observability」的編譯、燒錄與唯讀讀取；但同步未成功。證據只支持：Slave DCO controller 在取樣時是 idle 且 static initialization ready，而 Slave 的 `time_valid=0、spll_locked=0` 仍然存在。現階段不能把根因定為 I2C、SI5340、DCO mapping 或某一個 calibration 值；下一步仍應先建立使用同一套最新 observability 的 Master diagnostic baseline，再固定 Master，只針對 Slave 做單一變因。

## Next Step

先以 `9f848ec` 的 Master startup command 與目前最新唯讀 observability 建立 Master diagnostic baseline，驗證 `marker=B004、MODE=2、PTP=6、status=0xFF、PTP RX/TX 持續增加`。Master baseline 通過後，保存其 MIF/SOF/checksum；之後不再修改 Master role，只回到 Slave 進行下一個單一變因實驗。

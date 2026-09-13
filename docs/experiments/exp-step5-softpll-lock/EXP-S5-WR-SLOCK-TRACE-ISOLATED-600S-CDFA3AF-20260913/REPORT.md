# EXP-S5-WR-SLOCK-TRACE-ISOLATED-600S-CDFA3AF-20260913

## 結論

`STEP5 = NOT COMPLETE`。

本輪新加入的隔離 S_LOCK trace 已經能可靠讀取；但 WR extension 在完整 600 秒觀測開始前已進入 `WR_S_LOCK_TIMEOUT`，並降級為一般 PTP。之後 SoftPLL 曾出現主迴路鎖定狀態，但這不能把已失敗的 WR extension 重新判為 Step5 通過。

此外，本輪的 smoke 與 600 秒觀測是兩個分開的 observer session，中間沒有重新啟動硬體。因此 600 秒觀測的第一筆樣本已經帶有前一 session 之後的 sticky failure，不能用來宣稱「從啟動到 failure」的精確時間。

## 實驗身分

- Branch: `exp/step5-softpll-lock`
- Source commit: `cdfa3af9a383cd5d2130106765bedbdee21090f0`
- Board: `DE5 [1-11.2]`，Slave
- Trial: `EXP-S5-WR-SLOCK-TRACE-ISOLATED-600S-CDFA3AF-20260913`
- Observer exit: `0`
- Observer duration: `600349 ms`
- Samples: `278`
- Sample errors: `0`
- Smoke gate: `38 samples`, `0 sample errors`, observer exit `0`

## Build / program gate

- Master 與 Slave firmware 均以 source commit `cdfa3af` 重建。
- Master/Slave Quartus full compilation 均成功。
- Master/Slave programming 均成功，均為 `0 errors, 0 warnings`。
- Master MIF SHA256: `2bccd32a30a7a2bf34a0486e3fda1d0898c0f3820248c4252aad92efaae82b5e`
- Slave MIF SHA256: `1d4102d4092a1f6cbda2a4b8f938968af3bcfcb0eeb558f5bd457eb7320f7de6`
- Master SOF SHA256: `fe8c01ccdacd8553c410193af90bbbf867ae72c3e2fc81191a887a905c35f948`
- Slave SOF SHA256: `7e59459633ca1467ec88eeb647a43dfee53d7bdce187d0c5f4ade64dae4982ab`
- Timing closed: `NO`; Master WNS `-0.058 ns`、Slave WNS `+0.015 ns`

## Smoke gate evidence

60 秒 smoke 確認新的 diagnostic bank 沒有讀址錯誤或立即被覆寫：

- `SLOCK_TRACE_MAGIC=5752534C`
- `SLOCK_TRACE_STAGE=2(POLL)`
- `SLOCK_TRACE_RETRY` 從 `3` 下降至 `2`
- `SLOCK_TRACE_ENTRY_TICS` 維持 `0000307F`
- `SLOCK_TRACE_REMAINING_MS` 由約 `191685` 降至約 `166995`
- `SLOCK_TRACE_SEQ` 持續增加
- 60 秒末端仍是 `WRS_S_LOCK`、`WR_FAILURE=00000000`、`WR_LOCK_RESULT=code=1/check_lock=0`

因此隔離 trace 的 magic、stage、retry、timer 與 sequence transport 是有效的。

## 完整 600 秒結果

### WR extension

完整觀測第一筆樣本（`567 ms`）已經是：

```text
WR_FAILURE=02020001
WR_LOCK_RESULT=D9FF0702
  code=2
  check_lock=1
  fail_reason=3(WR_S_LOCK_TIMEOUT)
  fail_tics_low16=55807
SLOCK_TRACE_MAGIC=5752534C
SLOCK_TRACE_STAGE=4(FAILURE)
SLOCK_TRACE_RETRY=0
SLOCK_TRACE_REMAINING_MS=0
SLOCK_TRACE_ENTRY_TICS=0000307F
SLOCK_TRACE_POLL_RET=1
SLOCK_TRACE_WR_STATE=2
SLOCK_TRACE_SEQ=00016ABC
```

這證明 trace 能記錄 failure stage，但因為它是在 smoke session 之後才啟動完整 session，不能把 `567 ms` 當成真實的硬體 failure 起點。可信的判定是：在兩個 session 之間 WR S-lock 已經耗盡並被 sticky 記錄；完整 session 全程維持 `PPSI_PDSTATE=FAILURE`、`PPSI_EXTSTATE=PTP`、`WR_STATE=WRS_IDLE`。

### SoftPLL / PSTAT

完整 session 中可看到：

- `SPLL_SEQ_STATE=SEQ_READY` 曾成立，並在末端仍為 `SEQ_READY`。
- `PSTAT_LOCKED=1` 曾成立，末端仍為 `1`。
- 主迴路狀態在約 `30.439 s`、`79.816 s`、`142.670 s`、`162.876 s`、`203.280 s`、`275.099 s`、`560.180 s` 等區段出現 lock flag 變化或重新初始化跡象。
- 600 秒末端仍可見 `SPLL_DELOCK_COUNT=214`，表示不是「一次鎖定後完全無擾動」的穩定閉迴路。

這些欄位仍需先用正確 bit mapping 重算，才能給出可靠的 frequency/phase/Main lock 首次時間。

## 觀測器有效性問題

Source `vendor/wrpc-sw/lib/task-diags.c` 的 `SPLL_MAIN_STATE` packing 是：

```text
bit 0 = enabled
bit 1 = Main locked
bit 2 = frequency locked
bit 3 = phase locked
```

但目前 `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl` 解讀成：

```text
bit 0 = enabled
bit 1 = frequency locked
bit 2 = phase locked
bit 3 = Main locked
```

因此目前完整 run 的 `FIRST_MAIN_FREQ_LOCKED_MS`、`FIRST_MAIN_PHASE_LOCKED_MS`、`FIRST_MAIN_LOCKED_MS` 不能直接採信。原始 `SPLL_MAIN_STATE` word 必須保留，先修正 reader 再離線重算。

## Step5 判定

本輪不能通過 Step5，理由是：

1. WR extension 已記錄 `WR_S_LOCK_TIMEOUT`，並落入 `PPSI_PDSTATE=FAILURE` / `PPSI_EXTSTATE=PTP`。
2. SoftPLL/PSTAT 的後段鎖定不等於 WR calibration/extension 成功。
3. 主迴路 lock bit 的現有報告存在已確認的 observer 解碼錯誤。
4. 600 秒內可見多次 lock/失鎖變化與 `SPLL_DELOCK_COUNT` 增加，尚未證明長時間穩定。

## 下一步

只修改 observer，不修改 production control：

```tcl
set main_enabled      [bit32 $main_state 0]
set main_locked       [bit32 $main_state 1]
set main_freq_locked  [bit32 $main_state 2]
set main_phase_locked [bit32 $main_state 3]
```

以此修正後的 reader 對本輪 raw 做離線重算，並保留原始 `SPLL_MAIN_STATE` word。下一輪禁止改 PI、timeout、bootstrap、guard、arbiter 或 WR handshake；只有在正確解碼後仍確認 PLL 完整鎖定晚於 WR deadline，才進入下一個功能性時序實驗。

## 原始檔案

- `raw/observer-smoke.log`
- `raw/observer-600s.log`
- `build-info-master.txt`
- `build-info-slave.txt`
- `build-jtag-master.log`
- `build-jtag-slave.log`

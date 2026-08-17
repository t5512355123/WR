# 實驗紀錄：恢復 Slave DCO observability lock-handoff positive control

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-RESTORE-DCO-OBS-HANDOFF-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only known-good image restore
- Git branch：`exp/master-9f-observability`
- 建立時 commit：`3f30074`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

最新 page3/start-hold SOF 已證明 DCO transaction 可以完成，但 runtime 顯示 Slave `WR_LOCK_ENABLE=0`、`polls=0`、主要 SoftPLL event counters 為 0。較早的 DCO-observability image 曾在相同 Master baseline 下重現 `rx_msg=0x1001`、`fail_state=2`、`WR_LOCK enable=4` 與 locking polls。

本輪只恢復那顆已知能走到 lock-handoff 的 Slave SOF，確認 `runtime_start_hold` 是否是造成 handoff regression 的變因。這不是同步成功實驗；它是為了重新建立正確的 lock-path positive control。

## 相較 baseline 的唯一變因

- Master：維持歷史成功 `9f848ec` exact SOF，不重新燒錄。
- Slave：由 page3/start-hold SOF 恢復為已實驗證明的 DCO-observability SOF：
  - source commit：`1b52223b4bcab4f440189ce95c8219edb811675c`
  - SOF SHA-256：`f57e2b099048a3129ff51b9760a701c1b0ea4306994dbe38b32910d7345cdc1b`
  - MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 不改 Master role、PHY、QSFP、MIF、WR parser 或 runtime command。

## 判準

- Positive control：Slave `rx_msg=0x1001`、`fail_state=2`、`WR_LOCK enable/polls` 出現活動。
- 若恢復後仍有 `spll_locked=0`，只能說 lock handoff 重現，不能宣稱同步。
- 最終同步仍需 `spll_locked=1、time_valid=1、pps_valid=1` 並長時間穩定。

## 編譯結果

本輪不重新編譯，使用既有已驗證的 commit/SOF provenance；前次 compile record：`EXP-WRPC-SLAVE-CLEAN9F-DCO-OBS-20260818`。

## 燒錄結果

- 燒錄時間：2026-08-18 05:29:02 至 05:29:21（pain terminal 時間）
- Programmer：Quartus Prime 17.0 Build 595
- JTAG cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- 使用 SOF：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof`
- SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- Programmer checksum：`0x30A3C175`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：successful，0 errors、0 warnings
- 原始 programmer log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-RESTORE-DCO-OBS-HANDOFF-20260818/program_slave_restore_dco_obs.log`
- Programmer log SHA-256：`f46307a14ada6d7cb5bf162efc943045e48e793c1bffe5db2d355cc6450d7cff`

這證明歷史 positive-control Slave SOF 已成功載入；尚未證明 runtime handoff 或兩片同步成功。

## JTAG/runtime 原始結果

- 原始 runtime log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-RESTORE-DCO-OBS-HANDOFF-20260818/runtime_restore_dco_obs_10s.log`
- Runtime log SHA-256：`19f205bbc8c94de913a6b7d84f1d86208271698d4a7621cc56e4b953793b3047`
- 觀測方式：同一 JTAG session 連續約 10 秒取樣；Master 10/10 通過重試，Slave 4/10 通過重試，最後一筆有效 frame 仍可解碼，因此不把失敗 frame 當成同步證據。

### Master

- `status=0xFF`、`WDIAGS_MODE=2`、`WDIAGS_PTP=6`
- `time_valid=1`、`pps_valid=1`
- `TAG_COUNT`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT` 持續增加
- `PPS_ESCR=0x00000F0C`

### Slave

- `status=0xCF`、`WDIAGS_MODE=3`、`WDIAGS_PTP=9`
- `link_up=1`，但 `time_valid=0`、`pps_valid=0`
- `WDIAGS_SSTAT=1`、`WDIAGS_PSTAT=1`、`WDIAGS_UCNT=4`
- `PPS_ESCR=0x00000F00`、`DMS_L=0x0008246B`、`CKO=0x00F24F41`、`SETP=0`
- `WDIAGS_FOREIGN_META=0x03000001`、`PARSE_META=0x050126E7`
- `WR_SIGNAL: rx_msg=0x1001, rx_count=1, tx_msg=0x1000, tx_count=1, fail_role=2, fail_state=2`
- `WR_LOCK: result=1, spll_locked=0, polls=883644, unlocked=883644, calibration_fail=0, enable=4, seq_state=4, align_state=0, mode=3, delock_count=0`
- `WR_SPLL_HW_BLOCK_VALID: RCER=0x00000001, OCER=0x0010A201, OCCR=0x00000101, TRR_CSR=0x0012A2D0`
- `WR_SPLL_LOCKDET: HELPER=0x00000000, MAIN=0x00000000`
- `WR_SPLL_ACTIVITY: REF_COUNT=0x00034BC9, TAG_COUNT=0x000336E9, LAST_STATE=0x00000004, TRANSITIONS=0x00000003, IRQ_COUNT=0x00111988`
- `WR_SPLL_EVENTS: TAG_VALID_COUNT=0x0011A2D1/0x0011A2D1, TRR_WRITE_COUNT=0x0011A2D1/0x0011A2D1`

## Observation

這次正向控制確實重現了歷史上的後段路徑：Slave 收到 Master LOCK（`rx_msg=0x1001`），`WR_LOCK result=1`、`enable=4` 且 locking polls 持續增加；同時 RCER 已置位，reference/tag/TRR/IRQ 計數器都有活動。這表示目前不是「完全沒有進入 Slave lock handoff」或「tagger 完全沒有工作」。

但是 Slave 的 helper/main lock detector 都仍為 0，`spll_locked=0`，且 `time_valid=0、pps_valid=0`。因此資料只支持「有效 tag 與 TRR 活動已抵達 SoftPLL 後段」，尚不能支持「SoftPLL 已閉鎖」或「SI5340 已把時鐘回授到正確頻率」。

## Conclusion

1. Master historical baseline 在本輪未改動，且仍維持 `mode=2、PTP=6、status=FF、time_valid=1、pps_valid=1`。
2. Slave historical DCO-observability image 已成功燒錄，並重現 `WRS_S_LOCK`、`WR_LOCK enable/polls`、RCER、reference/tag/TRR/IRQ 活動。
3. 本輪未達成兩片同步：Slave `spll_locked=0、time_valid=0、pps_valid=0`。
4. 因此目前最有證據支持的問題區段已從 WR signaling/handoff 往後收斂到 SoftPLL lock detector 的輸入/鎖定條件或 clock-feedback/DMTD sampling；這仍是下一層待驗證的假設，不能直接宣稱根因是 SI5340 或 DCO。

## Next Step

保留 Master `9f848ec` 角色與目前 Slave positive-control bitstream，不再改 Master role，也不重複 reverse-DMTD 實驗。下一輪先做同一顆 Slave SOF 的唯讀 correlation，將 `WR_LOCK polls、RCER、TAG_SOURCE_COUNT、REF_COUNT、TAG_VALID_COUNT、TRR_WRITE_COUNT、IRQ_COUNT、SPLL seq/last state、helper/main lock` 與 DCO step count 對齊；只有在確認 valid tag/TRR 與 lock detector 的時間關係後，才選下一個單一 Slave source 變因。任何下一次燒錄另建 Experiment ID 並立即記錄。

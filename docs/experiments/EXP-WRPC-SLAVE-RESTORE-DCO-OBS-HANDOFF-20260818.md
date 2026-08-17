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

本節待完成。至少保存 Master/Slave 的 status、role、parent、WR signaling、WR lock、SoftPLL event counters、PPS_ESCR 與 frame validity。

## Observation

本節待補原始結果。

## Conclusion

本節只能依本輪實際 JTAG 證據撰寫；恢復已知 image 不等於兩片 DE5a 已同步。

## Next Step

依照 positive-control 是否重現，決定是否回到 start-hold source 做更小的 handoff/DCO 變因。任何下一次燒錄另建 Experiment ID 並立即記錄。

# 實驗紀錄：恢復歷史 Slave lock-path positive-control

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-POSITIVE-CONTROL-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only historical bitstream restore、燒錄後 JTAG runtime 觀測
- Git branch：`exp/master-9f-observability`
- Git commit：`8ec9bcc`（以此 source/docs baseline 建立並執行本實驗）
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

目前 start-hold Slave SOF 可以完成 DCO transaction，DCO step 會增加；但長時間 correlation 中 `WR_LOCK、RCER、valid tag、TRR、IRQ、SSTAT、UCNT` 仍為零。repository 內有一顆歷史上曾在相同 Master role 下重現後段 lock path 的 Slave positive-control SOF。本輪先恢復那顆**已知 artifact**，確認目前缺少的 upstream lock-path activity 是否能重新出現。

本輪不嘗試新的 Master role，不修改 Master、不修改 `g_softpll_reverse_dmtds`、PHY、PTP、SoftPLL 演算法、PI、threshold 或 MIF。

## 相較目前 baseline 唯一修改了什麼

只把 Slave FPGA configuration image 從目前 start-hold SOF 暫時替換成歷史 positive-control SOF：

- 目前 baseline：`DE5a_wr_slave_jtag.sof`，SHA-256 `001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`，Programmer checksum `0x30A22D41`
- restore image：`artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof`
- restore image SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- restore image historical source：`1b52223b4bcab4f440189ce95c8219edb811675c`
- restore image MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- 預期 Programmer checksum：`0x30A3C175`

Master 維持歷史 `9f848ec` exact image：

- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Master Programmer checksum：`0x30A46449`
- Master role 判準：`status=0xFF、WDIAGS_MODE=2、WDIAGS_PTP=6`

## 燒錄前保護與 provenance

- 不重新編譯 Master。
- 不覆蓋目前 start-hold SOF；原 SOF、MIF、compile log 與 runtime log 保留在原實驗 artifact 目錄。
- 使用 pain 上現有的 restore SOF，先以 `sha256sum` 核對後才執行 Programmer。
- Slave cable：`DE5 [1-11.2]`
- Programmer command：

```text
quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof
```

## 成功判準

第一層只要求恢復歷史 lock-path activity：

```text
Slave WR_LOCK enable/polls > 0
RCER != 0
TAG_SOURCE / REF / TAG / TRR / IRQ 有活動
```

這些出現時，只能說 upstream WR lock/SoftPLL tag path 被重新建立，不能直接宣稱同步完成。

最終同步仍要求同一觀測窗穩定看到：

```text
Master: status=FF、MODE=2、PTP=6、time_valid=1、pps_valid=1
Slave : MODE=3、link_up=1、PSTAT.locked=1、SSTAT 前進、UCNT 增加、time_valid=1、pps_valid=1
```

## MIF / SOF / 燒錄結果

待實際核對與燒錄後立即補入：

- restore SOF SHA-256：上列值
- restore MIF SHA-256：上列值
- Programmer checksum：待實際輸出
- JTAG ID：待實際輸出
- configuration result：待實際輸出
- Programmer raw log：`artifacts/EXP-WRPC-SLAVE-POSITIVE-CONTROL-RESTORE-20260818/program_slave_positive_control_restore.log`
- Programmer log SHA-256：待補

## JTAG/runtime 原始結果

待燒錄後執行同一套 read-only correlation 與雙板 time-series 後補入。至少保存：

- `servo_dco_correlation_positive_control.log`
- `runtime_positive_control_restore_60s.log`
- 每份 raw log 的 SHA-256

## Observation

待實驗結果填寫。若 restore image 重現 `WR_LOCK/RCER/TAG/TRR/IRQ`，表示目前 start-hold image 與歷史 positive-control 在 lock-path observability 或硬體時序上存在可辨識差異；若仍全部為零，問題更可能在目前板端外部狀態、Master/Slave link session 或 firmware/runtime handoff，不能把責任歸給 start-hold RTL。

## Conclusion

只能依燒錄後原始 programmer 與 JTAG 證據填寫。沒有 `PSTAT.locked=1、time_valid=1、pps_valid=1` 的證據，不得宣稱兩片 DE5a 已完成 White Rabbit 同步。

## Next Step

依 restore 結果只選一個 Slave 變因：

1. 若 positive-control 恢復 lock-path activity：保留該 image，下一輪只針對 DCO/clock feedback 或 start-hold 差異做 A/B。
2. 若 positive-control 也沒有 lock-path activity：不再改 Master role，回到 Slave parent/WR signaling runtime 與板端 link/session 的證據收斂。

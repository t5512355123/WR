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

- restore SOF SHA-256：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- restore MIF SHA-256：`9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`
- Programmer command：`quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/slave.sof`
- 燒錄時間：2026-08-18 06:57:40 開始；06:57:44 開始 configuration；06:57:59 完成
- Programmer version：Quartus Prime Programmer 17.0 Build 595 Standard Edition
- Programmer cable：`DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A3C175`
- configuration result：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer result：0 errors、0 warnings
- Programmer raw log：`artifacts/EXP-WRPC-SLAVE-POSITIVE-CONTROL-RESTORE-20260818/program_slave_positive_control_restore.log`
- Programmer log SHA-256：`E89764A9855F272B5A296F0D7943AB0E366BB4538718EAFDF041317AEDE2FA07`

## JTAG/runtime 原始結果

燒錄完成後執行同一套 read-only correlation。這顆 restore image 的結果不是「讀到全零」，而是 JTAG 觀測端找不到 Sources and Probes instance：

- 執行時間：2026-08-18 06:58:54
- command：`quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 60 500`
- `DE5 [1-11.1]`：`ERROR: No In-System Sources and Probes instance was found.`
- `DE5 [1-11.2]`：`ERROR: No In-System Sources and Probes instance was found.`
- `HPLL_HELPER_CORRELATION_DONE`：Tcl script evaluation successful，但沒有產生任何 sample
- raw log：`artifacts/EXP-WRPC-SLAVE-POSITIVE-CONTROL-RESTORE-20260818/servo_dco_correlation_positive_control.log`
- raw log SHA-256：`25085936ff63797e818504261d58cbb074ebc4f42b0389ebdd8b22d49ffd3fd3`

因此本輪沒有 `WR_LOCK、RCER、TAG、TRR、IRQ、SSTAT、PSTAT、UCNT` 的 runtime 讀值，也沒有可用的 status/time-valid sample。這是觀測介面缺失或 image/script 不匹配，不應解讀成這些 runtime counter 確實為零。

## Observation

這顆 restore image 的 Programmer 證據完整：JTAG ID 正確，且 configuration succeeded。但燒錄後兩條 JTAG 都找不到 Sources and Probes，因此目前無法確認這顆 image 是否有進入 WR lock path，也無法確認 Slave 的 `time_valid/pps_valid` 狀態。

這顆 image 與目前 read-only correlation script 的 probe 需求不相容，或它本身就是沒有 SLD Sources and Probes 的 clean image。這個結果不能用來支持「Slave lock 失敗」、也不能用來支持「Slave 已同步」。

## Conclusion

本輪已證明：

1. 歷史 positive-control Slave SOF 可以成功配置到 `DE5 [1-11.2]`。
2. 目前這顆 restore image 在燒錄後沒有可供本診斷腳本使用的 Sources and Probes instance。

本輪沒有證明 Slave 的 WR lock、SoftPLL lock 或時間同步結果。因為缺少 `PSTAT.locked=1、time_valid=1、pps_valid=1` 的同窗證據，不能宣稱兩片 DE5a 已完成 White Rabbit 同步。

## Next Step

下一步不改 Master role。先選用一顆已確認含有 Sources and Probes 的 Slave diagnostic image（或重新 compile 目前 diagnostic source），完成 image/probe 對應後再做同一套 read-only correlation。只有取得有效 sample，才能繼續判斷是 parent/WR signaling、SoftPLL activation 還是後段 gating。

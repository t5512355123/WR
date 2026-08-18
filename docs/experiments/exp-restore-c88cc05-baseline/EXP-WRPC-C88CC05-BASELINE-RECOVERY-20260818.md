# EXP-WRPC-C88CC05-BASELINE-RECOVERY-20260818

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-C88CC05-BASELINE-RECOVERY-20260818`
- 建立日期：2026-08-18（Asia/Taipei）
- 狀態：恢復實驗準備中；本文件建立當下尚未由本輪重新燒錄。

## Git 來源

- Branch：`exp/restore-c88cc05-baseline`
- 實驗準備 branch commit：`cb4932360a840ddd5af2c18eaff717811a1c7de3`
- 燒錄當下 pain checkout：`f17c4be`（本輪只使用已保存的 c88cc05 SOF，沒有在 pain 重新編譯）。
- 本次紀錄完成 commit：`f276133e38e64a31cd7992b6be46e62e5cbbeef8`
- 歷史已驗證來源：`ed21eaa`（加入兩片 DE5a 唯一身份）與 `c88cc05`（Quartus compile 前清除 cache）。
- Quartus：Quartus Prime 17.0 Build 595，Standard Edition。

## 這次想驗證什麼

確認目前 pain 上的 runtime 是否只是使用了後續診斷映像，而不是已保存的 `c88cc05` clean SOF。恢復 exact artifact 後，先驗證：

1. Master：`marker=B004`、`WDIAGS_MODE=2`、`WDIAGS_PTP=6`、低位 status=`0xFF`、PTP RX/TX 有活動。
2. Slave：能否離開 `WDIAGS_PTP=4`，並看到 `FOREIGN_META=0x03000001` 或其他 foreign-master/parent 證據。
3. 恢復後若 Slave 仍未 lock，只把問題留在 Slave parent/servo/SoftPLL 路徑，不再改造 Master role。

## 相較 baseline 唯一修改了什麼

本輪第一個 A/B 只替換 FPGA 目前的 programming image：

- 不修改 PHY、QSFP、lane、polarity、pre-emphasis、PTP 演算法或 startup role command。
- 不重新編譯，不把目前未提交的 pain QSF partition 設定帶入新的結論。
- 以保存的 `c88cc05` clean SOF 作恢復；恢復前先保存 programmer log，恢復後立即執行唯讀 JTAG runtime script。

## 映像與 hash

### 目前 pain 上的映像（恢復前）

| 映像 | 路徑 | SHA-256 |
|---|---|---|
| Master current diagnostic SOF | `quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof` | `51d76eddf8f8a56b743f5d9f83885274e1706960b6dd9a73be545922a3f93b76` |
| Slave current diagnostic SOF | `quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof` | `001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee` |

### 準備恢復的 c88cc05 clean SOF

| 板卡 | Artifact | SHA-256 | 已記錄 programmer checksum |
|---|---|---|---|
| Master | `build/artifacts/unique_mac_clean_c88cc05/quartus_sof/DE5a_wr_master_jtag.sof` | `f565c0a209cf1567f048df25b0f3312e9db4bf45a3fc46914a87efefbf2b1abf` | `0x30A0A429` |
| Slave | `build/artifacts/unique_mac_clean_c88cc05/quartus_sof/DE5a_wr_slave_jtag.sof` | `926d4a57f50dce0e39e437af7eba164a8ca1ec327c989b59d5f6480a038eb2cb` | `0x30A5A091` |

對應 build metadata 中保存的 MIF hash：

- Master MIF：`0705b4be17ed742fbd32860de8a8cbbebf91285c71e0e54465516a59e1b2dc7a`
- Slave MIF：`dbc19106386ebca90f3460309a8b41f09e5bde0694b91484e527ed4a56ef9d35`

## 恢復前的 pain JTAG 原始結果

使用者在 pain 執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

得到：

```text
Master: WDIAGS_MODE=2, WDIAGS_PTP=00000004
        WDIAGS_PTP_RX=00007EBA, WDIAGS_PTP_TX=000145E5
        WDIAGS_FOREIGN_META=0000FF00
        cpu_marker=0x0000B004, fault=0, link/status low byte=0xFF

Slave : WDIAGS_MODE=3, WDIAGS_PTP=00000004
        WDIAGS_PTP_RX=00000000, WDIAGS_PTP_TX=00000000
        WDIAGS_FOREIGN_META=0000FF00
        cpu_marker=0x0000B004, fault=0, link/status low byte=0xEF
```

## 目前 Observation

- `WDIAGS_MODE=2/3` 仍表示兩片的 role 設定是 Master/Slave，不是兩片都被切成同一個 role。
- `WDIAGS_PTP=4` 代表 `PPS_LISTENING` 或尚未進入穩定 PTP 狀態；不能直接宣稱 Master 已達歷史成功的 `PTP=6`。
- `FOREIGN_META=0000FF00` 解碼為沒有有效 foreign-master 記錄／parent 選擇；它不是 `c88cc05` 曾觀察到的 `03000001`。
- Master PTP RX/TX 有活動，只能證明 runtime 與封包計數器有活動；Slave RX/TX 為 0 且沒有 foreign record，支持「目前 pair 未重現 c88cc05 runtime」的觀察。
- 以上是恢復前證據，不能反推光路、SoftPLL 或 firmware 根因已經確定。

## Conclusion（恢復前）

目前證據支持：pain 上正在使用的 current diagnostic SOF 沒有重現已驗證的 `c88cc05` runtime 結果；最安全的下一步是恢復保存的 exact clean SOF，並重新取得同一份 JTAG 原始輸出。尚未有證據支持修改 Master role 或更換光路。

## Next Step

1. 在 pain 以保存的 `c88cc05` Master/Slave SOF 進行 programming。
2. Programming 完成後立即把完整 programmer output 保存到本實驗 artifact 目錄。
3. 等待固定時間後執行 `read_wb_runtime.tcl`，保存單次與短時間序列原始 output。
4. 若重現 `MODE=2/PTP=6/status=FF` 與 Slave foreign record，再凍結 Master，只針對 Slave 進行後續研究。

## 燒錄與實驗結果（2026-08-18）

### 燒錄結果

使用 Quartus Prime 17.0 Build 595、JTAG cable `DE5 [1-11.1]` 與 `DE5 [1-11.2]`：

- Master programming：成功，`0 errors, 0 warnings`，programmer checksum=`0x30A0A429`。
- Slave programming：成功，`0 errors, 0 warnings`，programmer checksum=`0x30A5A091`。
- 完整原始 programmer output：
  - `/home/b10504072/04_WR/artifacts/EXP-WRPC-C88CC05-BASELINE-RECOVERY-20260818/program_master.log`
  - `/home/b10504072/04_WR/artifacts/EXP-WRPC-C88CC05-BASELINE-RECOVERY-20260818/program_slave.log`
- programming 前的 current SOF 已保存在：
  - `pre_restore_master_current.sof`，SHA-256=`51d76eddf8f8a56b743f5d9f83885274e1706960b6dd9a73be545922a3f93b76`
  - `pre_restore_slave_current.sof`，SHA-256=`001dc7b64afd6ae82dd086126b065f626a8f2c88d6bfa8a95aecbc6198d603ee`

### 唯讀 JTAG 結果

恢復後先做延遲觀測，再做最後單次 snapshot。最後 snapshot 原始檔 SHA-256 為 `98c0692d134f461e74041280128e364867454420767476bca047be1ce0961fcf`，讀值為：

```text
Master: status_probe=101EDC43265082FF
        cpu_marker=B004, fault=0
        WDIAGS_MODE=2
        WDIAGS_PTP=6
        WDIAGS_PTP_RX=000000EF, WDIAGS_PTP_TX=00000218
        WDIAGS_FOREIGN_META=00000001

Slave : status_probe=401EB661323C82CF
        cpu_marker=B004, fault=0
        WDIAGS_MODE=3
        WDIAGS_PTP=9
        WDIAGS_PTP_RX=0000021C, WDIAGS_PTP_TX=000000A1
        WDIAGS_FOREIGN_META=03000001
        WDIAGS_SSTAT=00000001, WDIAGS_UCNT=00000016
```

短時間序列原始檔為 `/home/b10504072/04_WR/artifacts/EXP-WRPC-C88CC05-BASELINE-RECOVERY-20260818/runtime_after_restore_60s.log`，SHA-256=`49898c9eaea9781336595585f8c4af6d436f4f27ae9cfb6cd4a0c4eff4498905`。序列中 Master 反覆出現 `WDIAGS_PTP=6` 且 RX/TX 增加；Slave 進入 `WDIAGS_PTP=9`、`FOREIGN_META=03000001`，並且 `UCNT`、`DMS`、`CKO` 有非零活動。少數跨多個 mailbox 欄位的 snapshot 出現暫時性欄位不一致，因此不把單一不一致列當成 role 失敗；最後 snapshot 已重新讀取並得到一致的 Master/Slave 狀態。

### Observation

1. exact `c88cc05` clean SOF 燒錄後，原本的 `WDIAGS_PTP=4`／`FOREIGN_META=0000FF00` 不再是穩定狀態。
2. Master 已重現歷史 diagnostic baseline 的核心證據：`marker=B004`、`MODE=2`、`PTP=6`、低位 status=`0xFF`，且 PTP RX/TX 有活動。
3. Slave 已看到並選到 Master 的 foreign record：`MODE=3`、`PTP=9`、`FOREIGN_META=03000001`，並有伺服器活動；這重現了 c88cc05 的 parent signaling 結果。
4. 這次結果支持「先前 pain 上使用的 `51d76e…`／`001dc7…` current diagnostic SOF 沒有重現 c88cc05 clean runtime」；不需要發明新的 Master role 切換方法。

### Conclusion（只能由目前證據支持的範圍）

本實驗成功恢復並重現 `c88cc05` 的 Master role 與 Slave foreign-master/parent signaling。它證明問題主要是目前燒錄映像／建置 provenance 不一致，而不是目前證據已經證明 QSFP 光路故障。此結果仍**不等於**兩片已完成 sub-ns White Rabbit 時間同步：Slave 的 `PSTAT.locked` 尚未提供 lock=1 證據，仍需另外研究 servo/SoftPLL 到 `time_valid` 的路徑。

### Next Step

凍結已重現的 c88cc05 Master exact SOF，不再修改 Master role。後續研究只使用本 branch，先保存這兩份 SOF 與 hash，再針對 Slave 進行唯讀的 `SSTAT`、`PSTAT.locked`、`UCNT`、`CKO`、`SETP`、PPS validity time-series；每次若需要重新燒錄，必須立即新增同 branch 的實驗紀錄。

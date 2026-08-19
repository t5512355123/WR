# 實驗紀錄：Slave readback baseline 重確認

- Experiment ID：`EXP-WRPC-SLAVE-BASELINE-RECONFIRM-20260818`
- 日期：2026-08-18
- 實驗類型：已知穩定 Slave readback 映像重燒錄；本紀錄先保存燒錄證據，雙板 runtime 讀取另行補入
- Git branch：`exp/master-9f-observability`
- Git commit：`182411f`
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

在 Master 已重新載入歷史成功 `9f848ec` role 後，重新載入已保存的 Slave readback baseline，建立可比較的雙板起點。Slave 不能只以 `link_up` 或 `pps_valid` 判定成功；後續需觀察 parent/servo/SoftPLL，並以 `time_valid=1`、SoftPLL lock 與穩定有效 frame 作為同步成功判準。

## 相較 baseline 唯一修改

沒有修改 source、firmware、startup command、PHY、QSFP lane、clock、PTP、servo 或 role API。這次只重新燒錄已保存的 Slave SOF。

## 映像與 hash

| 項目 | 值 |
|---|---|
| Slave SOF | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| Slave SOF SHA-256 | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| Slave MIF SHA-256 | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Slave defconfig SHA-256 | `a8d3a90fa2b724a6f3f01a93e887364b12b140a8837f35882e7c6aa73386c212` |
| Slave identity header SHA-256 | `33ded2dc62811525a395d12a5a396dda1553339119eba2f37c86cf8cf4639d55` |

## 燒錄結果

使用 cable `DE5 [1-11.2]`。原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-BASELINE-RECONFIRM-20260818/program_slave.log
```

原始 log SHA-256：`1e528b2c7fd328338a29374e0fbc03ca5251a84b0d714b8c4a85df6507b81a4a`

Quartus Programmer 原始結果：

```text
Info (213011): Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x309FA629
Info (213045): Using programming cable "DE5 [1-11.2]"
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## Runtime 原始結果

雙板重新配置後，使用固定唯讀 JTAG session 與 HPLL/helper correlation；沒有寫入 WR 設定，也沒有重新 compile。原始檔案：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_timeseries.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot_after30s.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot_after90s.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/hpll_helper_correlation_60s.log
```

Slave 10-sample session 中有 7/10 accepted；accepted 與 retry 過程仍可見 `link_up` transient。代表性 snapshot：

```text
marker=B004 seen=1
CPU fault=0, im_valid=1
MODE=3
status_low=EF
link_up=1（部分 sample 變成 CF/01）
time_valid=0
pps_valid=1 或短暫為 0
PSTAT=0x1、SSTAT=0、spll_locked=0
PTP RX/TX：snapshot 為 0/0，session 中只有少量 RX/TX 增加
```

60 秒 `hpll_helper_correlation.tcl` 的 Slave 讀值為 60/60 筆，代表性首尾欄位如下：

```text
STEP=18、STEP_DELTA=0、STEP_EVENT=0
PSTAT=00000001、SSTAT=00000000、SPLL_STATE=00000000
HELPER_STATE=00000000
HELPER_ERROR_SIGNED=0
HELPER_OUTPUT=00000000
```

correlation log SHA-256：`86ef7bd1c5571c368fbfbc0976e5efe822c129a02092af013f41ec8f17704a08`

## Observation

本輪沒有看到 Slave 有效 SoftPLL/Helper feedback：60 筆中沒有 DCO step event，helper error/output/state 全部保持零；這個零值不能解讀成相位誤差已經完美收斂，因為同時 `PSTAT.locked=0、SSTAT=0、time_valid=0`。

Master 在同一輪維持 `MODE=2/status=FF/link_up=1`，但 `WDIAGS_PTP=6` 只在部分早期 sample 出現，後續 snapshot 為 `PTP=1`；這是 Master runtime 的觀測異常，不能用來宣稱雙板同步成功。

## Conclusion

證據支持：Slave 的 CPU 已執行、SOF 已配置、PHY/link 曾有效，且目前主要阻塞仍在 Slave `TAG/TRR/IRQ → SoftPLL sequence → Helper` 的 input/feedback 路徑；尚不能把根因確定為某個 register、FINC/FDEC 方向或 physical clock。

證據不支持：Slave 已完成 SoftPLL lock、`time_valid=1`，或兩張 DE5a 已完成 White Rabbit 時間同步。

## Next Step

保留目前 Master/Slave SOF，不改 Master role、不反轉 FINC/FDEC、不改 PI/threshold、不新增跨 clock-domain RTL。下一步用現有 JTAG 欄位做 60～300 秒唯讀關聯，先回答 `TAG/TRR/IRQ/SoftPLL sequence/Helper` 哪一段沒有活動，再決定是否需要極小的 Slave-only functional A/B。

# EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817

## 實驗名稱

修正 Slave DCO 除頻時脈握手，確認 I2C transaction 是否能完成

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-HANDSHAKE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave 單一 RTL 變因燒錄實驗

## 想驗證什麼

確認 Slave DCO transaction 是否因高速 `iCLK` 與除頻 `i2c_system_clk` 之間的 start pulse 遺失而卡住。成功判準分兩層：

1. DCO request 可以被 I2C controller 接受，`bus_state` 會變成 busy，並在完成後回到 idle；`bus_done`、`oDCO_ERROR` 與 `completed_steps` 必須能被觀察。
2. 在 DCO transaction 可完成後，Slave 的 `SSTAT/PSTAT`、SoftPLL lock、`time_valid` 是否朝有效狀態前進；兩台板的完整同步仍須另外用穩定時間序列確認。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：

- state 1、3、5 不再看到單一 `runtime_start` pulse 就前進；
- 改為保持 request，直到除頻 I2C controller 回報 `bus_state=1`；
- Master、Master firmware role、PHY、PTP、PI、lock threshold、DCO 資料方向與 register table 均未修改。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- RTL source commit：`131f3a5440922b8b4bded1dbecbdeac318891343`
- 燒錄紀錄 commit：`待燒錄完成後填入`
- Master 固定 baseline tag：`master-diagnostic-baseline-20260817`
- Quartus：Quartus Prime 17.0 Build 595
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave SOF SHA-256：`727fed98af743d9bb1822d15967388c9c372a6ae4183cfe540cfa60083fca227`

## Compile 結果

```text
Quartus Prime Full Compilation was successful. 0 errors, 267 warnings
Worst-case setup slack: -0.393 ns / -0.817 ns / 0.698 ns / 1.477 ns
Worst-case hold slack:  -3.488 ns / -4.016 ns / -1.222 ns / -1.572 ns
```

Timing warnings 延續既有 diagnostic project 的限制；本段只記錄 compile 結果，不把 compile 當成硬體功能成功。

## 燒錄結果

燒錄完成後立即填入：

```text
Programming cable:
JTAG ID:
Programmer checksum:
Configuration result:
Raw programmer log:
```

## JTAG/runtime 原始結果

燒錄完成後立即填入 DCO state、helper、SSTAT/PSTAT、PTP、parent 與 time_valid/pps_valid 時間序列。

## Observation

待燒錄與 runtime 觀測完成後填入，不預先假設結果。

## Conclusion

待燒錄與 runtime 觀測完成後填入，只寫證據真正支持的內容。

## Next Step

若 DCO transaction 完成但 Slave 仍沒有 lock，固定此 handshake 變因，下一輪只檢查 HPLL/DMTD feedback 或 SI5340 register mapping；若 transaction 仍卡住，保留 Master 不變，繼續針對 I2C controller 的 busy/done/error 狀態做唯讀診斷。

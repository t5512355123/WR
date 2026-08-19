# EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817

## 實驗名稱

以目前 Slave MIF 重測 DCO 除頻時脈握手

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：Slave 單一 RTL 變因燒錄實驗

## 想驗證什麼

確認 Slave DCO transaction 是否因高速 `iCLK` 與除頻 `i2c_system_clk` 之間的 start pulse 遺失而卡住，並確認修正後是否能讓 Slave servo 朝 `time_valid=1` 前進。

成功判準：

1. DCO `bus_state` 能由 idle 進入 busy，再回到 idle；`bus_done`、`oDCO_ERROR` 與 `completed_steps` 可觀察。
2. Slave 的 `SSTAT/PSTAT`、SoftPLL lock、`time_valid` 能在雙板時間序列中穩定有效。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：state 1、3、5 保持 request，直到除頻 I2C controller 回報 `bus_state=1`。Master、Master firmware role、PHY、PTP、PI、lock threshold、DCO 資料方向與 register table 均未修改。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- RTL source commit：`131f3a5440922b8b4bded1dbecbdeac318891343`
- 燒錄紀錄 commit：`c598da5d27c18b2c5ef94e2de041f44993ed1092`
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

Timing warnings 延續 diagnostic project 的既有限制；compile 成功不代表硬體功能成功。

## 燒錄結果

```text
Programming cable: DE5 [1-11.2]
JTAG ID: 0x02E660DD
Programmer checksum: 0x309F55AB
Configuration result: Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

原始 programmer log：

```text
artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817/program.log
SHA-256: fd84dc52c61ed4a56403aa2b3eca0667719830253902ce118995a466d93219f9
```

## JTAG/runtime 原始結果

燒錄後執行既有的 `read_wb_runtime.tcl`、`read_dco_state.tcl 60`、`read_dco_activity.tcl 60` 與 `read_wb_timeseries_session.tcl 15 1000 3`。

Master 仍讀到：

```text
cpu_marker: 0x0000B004 seen=1
WDIAGS_PTP:   00000006
WDIAGS_PTP_RX:00006C40
WDIAGS_PTP_TX:0000F422
WDIAGS_MODE:   2
```

Slave snapshot 讀到 marker `B004`、`WDIAGS_MODE=3`、`WDIAGS_PTP=4`、PTP counters 有活動，但仍為 `time_valid=0`。

DCO probe：

```text
DCO_STATE A=0005000400002B20 B=0005000400002B20
DCO_ACTIVITY A=0000000400940004 B=0000000400940004
```

依 probe map 解碼，兩片讀值都顯示 `rt_state=0`、`bus_state=0`、`static_ready=1`、`hpll_pending=0`、`busy=0`、`error=0`、`completed_steps=4`、`last_hpll_data=0x0005`；DCO activity 也顯示 completed step `4`、busy `0`、error `0`。這與前一版長時間 `busy=1、completed_steps=0` 不同，支持 transaction 已能完成。

15 秒雙板時間序列的有效 Slave frame 仍顯示：

```text
DECODE: status_low=EF time_valid=0 pps_valid=1 wr_mode=3 link_up=1 spll_locked=0
WR_LOCK: result=0 spll_locked=0
```

期間有少數 JTAG frame 無法接受，出現短暫 `link_up=0` 或 `status_low=CF/00`；因此本輪不能把它宣稱為穩定 runtime，也不能宣稱同步成功。

原始 runtime logs：

```text
artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817/runtime_snapshot.log
SHA-256: e233cfc23dbbc1827e057d8f5c44da204824ae22307628e537c8fc87ace907ef

artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817/dco_state.log
SHA-256: fe605bf560ef940da94c4e930573331a6949b5be2b29ed87a8cd6e2a40012e31

artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817/dco_activity.log
SHA-256: 70b75f6b96c7df82e51c315e8d8968daa377695b7eb6fdd6a01f2e83cb26ddb2

artifacts/EXP-WRPC-SLAVE-DCO-HANDSHAKE-CURRENT-MIF-20260817/runtime_timeseries.log
SHA-256: 654c9369ea23e4fc049ec177b89156adf2569647b562098e123a5daa4bcb3563
```

## Observation

1. 本次握手修正讓 DCO transaction 從前一版的長時間 busy/零完成數，變成 `completed_steps=4`、busy=0、error=0。
2. Master 維持 `B004 / mode=2 / PTP=6` 的固定 baseline。
3. Slave 仍沒有進入 `spll_locked=1` 或 `time_valid=1`；目前不能宣稱兩台 DE5a 已同步。
4. DCO handshake 已不再是唯一可疑點；下一個優先方向是 HPLL/DMTD feedback 的有效性、方向或 SI5340 register mapping。

## Conclusion

本實驗支持的結論是：除頻時脈握手修正有效改善了 DCO transaction completion，但沒有完成 Slave servo lock。現有證據將問題進一步收斂到「DCO 寫入完成後，SoftPLL feedback 是否真的作用於正確的 clock/DCO 路徑」，仍不能直接指向某個 register 或 polarity 根因。

## Next Step

固定本次 handshake 版本與 Master baseline。下一輪只做一個 Slave 變因：先以 source/read-only audit 核對 HPLL feedback 的資料方向、DMTD source 與 SI5340 FINC/FDEC register mapping，再選一個最小 RTL 修正；不改 Master、PTP role、PI、lock threshold 或 PHY。

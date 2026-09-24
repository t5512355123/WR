# 實驗紀錄：恢復 Slave reverse DDMTD 基線

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-REVERSE-RESTORE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗 branch：`exp/master-9f-observability`
- Git commit：`c1300a26227906ad912b7941a7e6f3eb967f9531`
- 實驗名稱：恢復 Slave 的 reverse DDMTD 取樣方向，確認 direct-DDMTD 失敗是否只是取樣方向/除二設定造成

## 想驗證什麼

確認恢復原本的 `g_softpll_reverse_dmtds => true` 後，Slave 是否能恢復有效 tag、helper feedback 與 SoftPLL lock；Master 完全沿用歷史成功的 `9f848ec` role，不重新設計 Master role 切換。

本次只驗證 Slave 基線恢復，不宣稱時間同步成功。

## 相較 baseline 唯一修改

- 相較前一個 direct-DDMTD 實驗，只將 `DE5a_wr_slave_jtag.vhd` 的 `g_softpll_reverse_dmtds` 從 `false` 恢復為 `true`。
- 另修正建置腳本的 Quartus clean 路徑，使 `quartus_sh --clean` 在專案目錄中執行；這是建置修正，不是 WR 硬體功能變更。
- Master role、Master source、PHY、PTP 與 SoftPLL 演算法均未修改。

## Build / provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Slave project：`DE5a_wr_slave_jtag`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`10503c222b9b1bed5461e055aea052ba1d5c4129e2c9f32be856fba7b0509576`
- Slave SOF SHA-256：`78ed192d416bcee6fe92297f2b08eab6a721ef5527d3bed31e03d70488648ad9`
- Fitter：`Successful`
- Timing：`TIMING_CLOSED=NO`；worst setup `-0.401 ns`，worst hold `-3.548 ns`
- Master 仍為已保存的 clean-9f 映像：MIF `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`，SOF `383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`

## 燒錄結果

- Programmer：Quartus Prime Programmer 17.0
- Cable：`DE5 [1-11.2]`
- Device：`10AX115N2F45@1`
- JTAG ID：`0x02E660DD`
- SOF checksum：`0x30A3C175`
- 結果：`Configuration succeeded`、`Successfully performed operation(s)`、0 errors / 0 warnings
- 時間：2026-08-17 17:12:19 至 17:12:37（Asia/Taipei）
- 原始燒錄 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-REVERSE-RESTORE-20260817/program_slave.log`

## JTAG/runtime 原始結果

同一 JTAG session 執行：

```text
quartus_stp -t scripts/jtag/read_wb_timeseries_session.tcl 10 1000 3
```

原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-REVERSE-RESTORE-20260817/runtime_10s.log`

runtime log SHA-256：`aea34293e0e262ba8bb18eb5e909d4ab11604d65b46fad6a42cd0341412e692b`

代表性結果：

```text
Master:
  status_low=FF time_valid=1 pps_valid=1 wr_mode=2 link_up=1
  WDIAGS_PTP=00000006，PTP RX/TX 持續增加

Slave:
  status_low=CF 或 EF，time_valid=0，pps_valid=0/1
  wr_mode=3，link_up=1，spll_locked=0
  parent foreign_count=1，is_wr=1，calibrated=1
  WDIAGS_PTP=00000008，PTP RX/TX 持續增加
  WR_LOCK result=1，seq_state=4，polls/unlocked 持續增加
  HELPER=00010000，MAIN=00000000
  TAG_VALID_COUNT、TRR_WRITE_COUNT、TAG_SOURCE_COUNT 持續增加
  HELPER_ERROR=FFFDB610（signed 負值，固定在約 -150000 的 clamp）
```

## Observation

1. 恢復 reverse DDMTD 後，Slave 的有效 tag、TRR write 與 source activity 都恢復為持續增加；direct-DDMTD 版本的有效 tag 為零，因此 direct 版本不是可用基線。
2. Slave 已看到 WR parent，`is_wr=1` 且 `calibrated=1`；PTP RX/TX 也在增加，表示不是單純 PHY 斷線或 parent 消失。
3. Slave 仍沒有進入 SoftPLL lock：`PSTAT` lock bit 為 0、`spll_locked=0`、`time_valid=0`，helper lock detector 仍未成立。
4. Master 在相同觀測窗維持歷史成功的 `MODE=2`、`PTP=6`、`status=0xFF`、`time_valid=1`、`pps_valid=1`。

## Conclusion

證據支持：reverse DDMTD 是目前 Slave 必須保留的取樣基線；恢復後確實恢復了有效 tag activity，但沒有讓 Slave 完成 SoftPLL lock 或時間同步。問題已從「direct/reverse 取樣方向」進一步收斂到 reverse 版本下的 helper reference phase/clock mapping、錯誤方向或 lock 條件；目前不能宣稱根因已確定。

## Next Step

維持 Master `9f848ec` role 與 Slave reverse 基線不動，先做 read-only source audit，核對：

- `ref_src=0` 對應的實際 ref channel；
- `clk_dmtd_i`、`clk_ref_i`、`phy_rx_rbclk_i`、`phy_rx_rbclk_sampled_i` 的 domain 與方向；
- tagger enable / event polarity / cadence；
- `HELPER_ERROR` 的 signed 解讀與 clamp 觸發原因；
- `lock_count=0` 是沒有有效 sample，還是 sample 持續超過 threshold。

下一個硬體實驗只能選一個 Slave-only 變因，且必須在 source audit 後決定；不先改 Master、不同時改 ref channel、polarity 與 DMTD mapping。

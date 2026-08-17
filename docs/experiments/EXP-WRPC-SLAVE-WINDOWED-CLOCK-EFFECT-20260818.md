# EXP-WRPC-SLAVE-WINDOWED-CLOCK-EFFECT-20260818

## 實驗基本資料

- Experiment ID：`EXP-WRPC-SLAVE-WINDOWED-CLOCK-EFFECT-20260818`
- 日期：2026-08-18
- 研究分支：`exp/master-9f-observability`
- Git commit：`79f27502e937b6ab7c3136e8020440c95ffec24f`
- Quartus：Quartus Prime 17.0 Build 595
- 實驗目的：在不改 Master role、PHY、PTP 或 FINC/FDEC direction 的前提下，觀察 Slave 的三個 clock domain 在固定 1 ms window 內的活動數，區分「FPGA FSM 完成但 clock 沒動」與「clock 確實有活動」。

## 相較 baseline 的唯一修改

本輪只修改 Slave `DE5a_wr_slave_jtag.vhd` 的觀測邏輯：

1. 移除前一輪會增加 timing/resource 風險的 32-bit cumulative clock counter 與未使用的 instance 11。
2. 重用既有 JTAG instance 7 `WR_CLOCK_ACTIVITY_SLAVE`。
3. 在 `CLK_50_B2J` domain 加入簡單的 1 ms window latch，將 QSFPA reference、QSFPB/DMTD、recovered RX 三個同步後 toggle 的事件數鎖存到 instance 7。
4. `read_clock_activity.tcl` 以 `count * 256000` 估算來源頻率；這是活動估計，不是外部儀器校正值。

Master 保持歷史成功 baseline，不重新編譯、不重新燒錄、不改 role：

```text
WDIAGS_MODE=2
WDIAGS_PTP=6
status=0xFF
time_valid=1
pps_valid=1
```

本輪沒有修改 SI5340 page sequence、0x0339 mask、0x001D FINC/FDEC、SoftPLL、PTP filter 或 PHY。

## Compile 證據

```text
Full Compilation was successful
0 errors, 269 warnings
Fitter Status : Successful
TIMING_CLOSED=NO
WORST_SETUP_SLACK_NS=-0.184
WORST_HOLD_SLACK_NS=-3.514
WORST_RECOVERY_SLACK_NS=1.469
WORST_REMOVAL_SLACK_NS=0.321
UNCONSTRAINED_CLOCKS=4
UNCONSTRAINED_INPUT_PATHS=584
UNCONSTRAINED_OUTPUT_PATHS=84
```

SOF 與來源雜湊：

| 項目 | SHA-256 |
|---|---|
| Slave SOF | `0dfcbad40e5199cde46ef185f945eeba27e3e772098e7e63da3816e1f5a7ca59` |
| Slave QSF | `4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233` |
| Slave SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Slave MIF | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |

## 燒錄結果

```text
Cable: DE5 [1-11.2]
Programmer checksum: 0x30A423D0
Device: 10AX115N2F45@1
JTAG ID: 0x02E660DD
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

因此本輪的 FPGA programming 成功；這不代表 WR synchronization 成功。

## Clock-effect 結果

Slave 1 ms window 的原始結果：

```text
CLOCK_ACTIVITY label=BEGIN ... WINDOW_US=1000 REF=488 REF_EST_HZ=124928000 DMTD=488 DMTD_EST_HZ=124928000 RX=488 RX_EST_HZ=124928000 ... LINK_UP=1 LINK_OK=1
CLOCK_ACTIVITY label=END   ... WINDOW_US=1000 REF=489 REF_EST_HZ=125184000 DMTD=488 DMTD_EST_HZ=124928000 RX=488 RX_EST_HZ=124928000 ... LINK_UP=1 LINK_OK=1
```

這表示 observer 能看到三個 clock domain 的活動，且數值約在 125 MHz 附近；但它只能證明「分頻 toggle 被觀測到」，不能證明 SI5340 FINC/FDEC 已造成可控的頻率偏移，也不能證明 clock phase 已鎖定。

DCO readback：

```text
DCO_STATE A=0005000300000320 B=0005000300000320
DCO_READBACK value=000500030003050D
```

此輪 readback valid、無 NACK、value match 仍然存在；但 `completed step` 與 windowed clock count 之間沒有形成可用的「每一步造成多少頻率改變」證據。

## Runtime / JTAG 原始結果

原始檔案保存於：

```text
artifacts/EXP-WRPC-SLAVE-WINDOWED-CLOCK-EFFECT-20260818/
```

重點現象：

- Master 在大多數有效 frame 維持 `status_low=FF`、`wr_mode=2`、`time_valid=1`、`pps_valid=1`、`link_up=1`，PTP RX/TX 持續增加。
- Slave 曾出現 `status_low=EF`、`pps_valid=1`、`link_up=1`，但 `time_valid=0`、`spll_locked=0`。
- Slave 的 30 秒 session 中多次出現 `accepted=0 retries=3`。
- Slave 曾出現 `status_low=CF`、`link_up=0`，後面偶爾恢復到 `link_up=1`，但仍沒有 `time_valid=1`。
- Slave 最後一批有效資料仍顯示 `time_valid=0`、`spll_locked=0`，所以沒有通過同步 baseline。

## Observation

1. 1 ms window observer 可以得到接近 125 MHz 的活動估計，說明 clock domain 至少有可觀測 toggle。
2. 但這個 observer 版本的整體 runtime 不穩定：Slave 有多次 frame retry、link transient 與 `accepted=0`。
3. 因此不能把本輪的 clock count 當成有效的 WR physical actuator 證據；首先必須回到穩定 baseline，再用更低侵入性的方式觀察。
4. Master role 沒有被本輪修改，Master 的成功證據仍然有效；問題仍集中在 Slave runtime/servo 路徑，但這一版 observer 本身不能作為功能 baseline。

## Conclusion

本輪證據支持：

> 既有 instance 7 可以讀到 1 ms window 的 clock activity，數值約落在 125 MHz 附近；但加入 window latch 後，Slave runtime 出現不穩定與 link transient，因此這個硬體診斷版不適合留在板上，也不足以證明 SI5340 actuator 已實際改變輸出頻率。

本輪證據不支持：

- 不能宣稱 Slave 完成 White Rabbit synchronization。
- 不能宣稱 FINC/FDEC direction 正確或錯誤。
- 不能宣稱 readback value 等於 physical clock effect。
- 不能宣稱 timing 已 sign-off，因為 setup/hold slack 仍為負。

## Next Step

1. 立即恢復 `aa0825a` 的 readback SOF，避免診斷版的 runtime transient 影響後續研究。
2. 保存本輪 compile、program、windowed clock 與 30 秒 session 原始資料後，不再疊加 observer 變因。
3. 目前最保守的功能研究仍是：保持 Master `9f848ec` role baseline，回到穩定 Slave readback baseline，再針對 SI5340 physical effect 使用更低侵入、非持續 RTL 計數器的量測方法；沒有外部量測或穩定的頻率差異前，不反轉 FINC/FDEC。

## 原始檔案雜湊

```text
program.log            9844a67cdea04d6de667ec740dda7f39f5f432cf1df756612affb8bf3510b9ac
quartus_jtag_slave_compile.log 8cdf987e3071b221ea8ac481ee3de42e88045f688ed843f9dd4f2b441045998e
build_info_jtag_slave.txt b3b74beea86d35b3e847797621b19c644f08ff74eb29cf78dce37af797406f4f
runtime_snapshot.log   39949afdbe9d7a542cd16a60946289673d747aef3605ec7cc96ad0a691dee9d2
dco_state.log          a71d9e7377be5da9d96f613b4233ab122588b62883bacd7fffaa0cb22281e926
dco_readback.log       f4ff6cc8ab587a052374a0e7a97ca087b0c3501f12a012acab5d4ca993c7cd91
clock_activity.log     40170e8493fc155c2301031b91b746747965b5451361205c683725849fb9650e
runtime_timeseries.log 8117770469705a5f6f81ab7953e27cc31027e53c172b49ecde4e46d335bd3f76
```

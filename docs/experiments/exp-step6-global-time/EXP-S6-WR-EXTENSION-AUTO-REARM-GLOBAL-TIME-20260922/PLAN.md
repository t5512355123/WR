# EXP-S6-WR-EXTENSION-AUTO-REARM-GLOBAL-TIME-20260922

## 目的

修復 Slave 在 WR extension `WRS_S_LOCK` timeout 後停留於普通 PTP fallback、導致 Global Time 永遠無效的問題，並確認兩台 DE5a 的 Global Time 能在同一個 runtime session 中恢復且持續有效。

## 唯一 production 變因

在 `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c` 增加窄條件 recovery：只有當

- PTP state 是 `PPS_SLAVE`；
- WR role 是 `WR_SLAVE`；
- 仍保有 WR parent；
- parent 宣告 `WR_MASTER` 或 `WR_M_AND_S`；以及
- failure reason 是 `WR_FAIL_REASON_WR_S_LOCK_TIMEOUT`

才走標準 `PPS_SLAVE -> PPS_UNCALIBRATED -> WRS_PRESENT` restart path。其他 handshake failure 維持原本 terminal PTP fallback。

不修改 SoftPLL、PI/gain/threshold、PSTAT、Global-Time snapshot wiring、timeout 常數、RTL、SDC 或 PHY。

## 實驗流程

1. Laptop commit/push source。
2. Pain 以乾淨 worktree `fb0d038b` pull source，build firmware 與兩份 JTAG SOF。
3. Slave 先、Master 後燒錄。
4. 使用 read-only Step 1--6 dashboard，每 10 秒採樣，不啟用主機端 120 秒等待 gate。
5. 觀測兩板 Global Time validity、snapshot stability、TAI/CYCLES 是否持續前進。

## 通過條件

- 兩板 `TIME_VALID=1`、`PPS_VALID=1`；
- 兩板 `SNAPSHOT_VALID=1`、`SNAPSHOT_STABLE=1`；
- TAI 與 cycles 可讀且持續增加；
- recovery 後至少連續多次採樣維持有效。


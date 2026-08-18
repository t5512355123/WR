# EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-SOURCE-AUDIT

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-PTP-TO-RTS-LOCK-SOURCE-AUDIT-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`4fda4d5`（本次 source audit 的基準）
- 實驗類型：唯讀 source audit
- FPGA compile：未執行
- FPGA 燒錄：未執行
- 目的：釐清 Slave 從 PTP 啟動、WR parent 選擇到 SoftPLL tagger 啟用的實際呼叫鏈

## 為了驗證什麼

前一輪 Slave 燒錄後的唯讀結果為：

```text
MODE=3
RCER=0
PTP_RX 大多為 0
TAG_SOURCE_COUNT 會增加
TAG_VALID/TRR_WRITE/IRQ=0
SSTAT=0
```

因此本輪只驗證以下問題：

1. `ptp start` 是否真的啟動 PPSI/WR runtime。
2. Slave 的 WR parent 是否在 Announce/WR TLV 中建立。
3. 一般 WR PTP Slave 是否會呼叫 `rts_lock_channel(0)`。
4. 哪一個實際呼叫會設定 `RCER`，以及後續如何形成 `TAG_VALID -> TRR -> IRQ`。

本輪不修改 Master role、不修改 PHY、不修改 FINC/FDEC、PI、lock threshold 或 DDMTD polarity。

## 相較 baseline 唯一修改了什麼

沒有修改 source、firmware、RTL、MIF、QSF、SDC 或 bitstream。本輪只有閱讀目前 repository 的 source，並與既有 JTAG 結果及外部 White Rabbit 討論交叉核對。

## Source audit 證據

### 1. `ptp start` 的實際入口

- `vendor/wrpc-sw/wrc_main.c:165-166` 在系統初始化時執行 `wrc_ptp_set_mode(WRC_MODE_SLAVE)` 與 `wrc_ptp_start()`。
- `vendor/wrpc-sw/wrc_main.c:252-257` 建立 `ptp`、`ptp_bmc`、`spll-bh` 等 task；因此 PTP packet/update 與 SoftPLL background update 是分開的 runtime task。
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c:427-435` 將 `wrc_ptp_run(1)` 對應到 `wrc_ptp_start()`。
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c:300-368` 的 `wrc_ptp_start()` 讀取 calibration、呼叫一次 `pp_state_machine()`、設定 `PPS_INITIALIZING`、重設 WR servo，最後才把 `ptp_enabled` 設為 1。
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c:440-498` 的 `wrc_ptp_update()` 在 `ptp_enabled` 後接收 PTP frame，呼叫 `pp_state_machine()`，無封包時仍週期性推進 state machine。

結論：`ptp start` 不是「直接宣告同步完成」，而是啟動後續 PTP/BMCA/WR state machine。

### 2. Slave parent 的建立條件

- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/hooks.c:164-220` 的 `wr_bmca_s1()` 處理最佳 foreign master 的 WR Announce TLV。
- 只有當 Announce 的 WR flags 表示 `WR_MASTER` 或 `WR_M_AND_S` 時，才會將 `parentDetection` 設為 `PD_WR_PARENT`。
- 隨後才更新：

```text
parentIsWRnode
parentWrModeOn
parentCalibrated
parentWrConfig
```

- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/hooks.c:294-300` 的 `wr_ready_for_slave()` 要求 WR extension active、local `wrModeOn`、`parentWrModeOn` 且 WR state 為 `WRS_IDLE`，才允許進入 PTP Slave。
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/hooks.c:250-270` 在進入 `PPS_UNCALIBRATED` 時，若 parent config 是 `WR_MASTER` 或 `WR_M_AND_S`，才會設定 `WRS_PRESENT` 並重新啟動 WR Slave handshake；否則會走 handshake failure。

結論：`FOREIGN_META` 中看到一筆 foreign master，不能單獨等同 parent 已完成；仍要同時看到 WR parent flags 與 WR state machine 的進展。

### 3. 一般 WR PTP Slave 的 SoftPLL 啟動點

- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-present.c:20-40`：WR Slave 在 `WRS_PRESENT` 收到對方 `LOCK` signaling 後，才把下一 state 設為 `WRS_S_LOCK`。
- `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c:14-50`：進入 `WRS_S_LOCK` 時呼叫 `WRH_OPER()->locking_enable(ppi)`；輪詢則呼叫 `locking_poll()`。
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c:30-35`：WR node 的 `locking_enable` 實作是 `wrpc_spll_locking_enable`。
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c:19-30`：`wrpc_spll_locking_enable()` 在非 GM 模式下呼叫：

```text
spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS)
spll_enable_ptracker(0, 1)
calib_t24p_init()
```

因此，一般 WR PTP Slave 的實際主路徑不是 `rts_lock_channel(0)`，而是：

```text
WR parent / signaling
    -> WRS_PRESENT
    -> 收到 LOCK
    -> WRS_S_LOCK
    -> wrpc_spll_locking_enable()
    -> spll_init(SPLL_MODE_SLAVE, 0, ...)
```

### 4. `rts_lock_channel(0)` 的實際角色

- `vendor/wrpc-sw/ipc/rt_ipc.c:93-107` 的 `rts_lock_channel()` 只有在 `pstate.mode == RTS_MODE_BC` 時接受請求。
- 該函式本身才會呼叫 `spll_init(SPLL_MODE_SLAVE, channel, 0)`，並更新 `pstate.current_ref`。
- `vendor/wrpc-sw/ipc/rt_ipc.c:187-192` 顯示它是透過 Mini-IPC export 的 RPC handler。
- 在目前 source audit 到的 WR PTP path 中，沒有看到 `wr_bmca_s1()`、`wr_ready_for_slave()` 或 `wr_s_lock()` 呼叫 `rts_lock_channel()`。

結論：不能用「沒有看到 `rts_lock_channel(0)`」直接判定一般 WR PTP Slave 沒有啟動 SoftPLL。對目前 WR node path，更重要的證據是 `wrpc_wr_lock_enable_count`、`SPLL->RCER`、`TAG_VALID`、`TRR_WRITE` 與 `IRQ`。

### 5. `spll_init()` 到 `RCER` 的關係

- `vendor/wrpc-sw/softpll/softpll_ng.c:331-368`：`spll_init()` 先清除 `OCER`、`RCER`、`OCCR`，再將 sequence state 設為 `SEQ_CLEAR_DACS`。
- `vendor/wrpc-sw/softpll/softpll_ng.c:424-430`：非 disabled mode 會先設定 `EIC_IER=1` 與 `OCER bit0=1`，但 reference channel `RCER` 不在這裡直接開啟。
- `vendor/wrpc-sw/softpll/spll_helper.c:100-124`：`helper_start()` 最後呼叫 `spll_enable_tagger(s->ref_src, 1)`。
- `vendor/wrpc-sw/softpll/spll_common.c:113-125`：reference channel 的 `spll_enable_tagger()` 會設定 `RCER bit[channel]`。

因此可形成更精確的 downstream chain：

```text
wrpc_spll_locking_enable()
    -> spll_init()
    -> sequence: SEQ_CLEAR_DACS / SEQ_WAIT_CLEAR_DACS
    -> SEQ_START_HELPER
    -> helper_start()
    -> spll_enable_tagger(ref_src, 1)
    -> RCER bit0
    -> valid tag / TRR / IRQ
```

注意：`spll_init()` 後不代表 RCER 會立刻保持為 1；它要等 background sequence 走到 `helper_start()`。所以單一瞬間讀到 `RCER=0` 仍不能單獨證明 `locking_enable()` 從未被呼叫，但若長時間同時 `SPLL_STATE=0`、`RCER=0`、`TAG_VALID=0`、`TRR_WRITE=0`、`IRQ=0`，就支持 runtime 沒有完成這條 downstream path。

## 目前 runtime 證據如何解讀

已保存的 Slave 唯讀結果顯示：

```text
MODE=3
marker=B004
CPU fault=0
TAG_SOURCE_COUNT 大多增加
RCER=0
TAG_VALID=0
TRR_WRITE=0
IRQ=0
SSTAT=0
HELPER_STATE=0
HELPER_ERROR=0
HELPER_OUTPUT=0
```

這些證據支持的最保守結論是：

> Slave 的某種 raw source activity 存在，但目前沒有證據顯示 WR PTP 已完成 parent/WR signaling handoff，並讓 SoftPLL sequence 穩定走到 reference tagger、TRR 與 IRQ。問題邊界優先位於 WR parent/handshake 到 `wrpc_spll_locking_enable()`，或位於 `spll_init()` 後的 sequence/tagger enable；尚不能只靠這些資料判定是哪一個。

這些證據不支持以下過度結論：

- 不能說 Master role 需要重新設計。
- 不能說 `rts_lock_channel(0)` 是目前唯一或必經的 WR PTP 路徑。
- 不能說 `TAG_SOURCE_COUNT` 增加就代表 valid DDMTD tag 已產生。
- 不能說 `RCER=0` 一定代表 `locking_enable()` 從未呼叫。
- 不能宣稱 Slave 已完成 White Rabbit synchronization。

## 外部討論共識

已將本輪證據送至「White Rabbit 技術應用」對話交叉討論。共識是：

1. 維持歷史成功的 Master `9f848ec` role，不新增 Master role switching。
2. 先查 `ptp start -> parent selection -> WR signaling -> locking_enable -> RCER`。
3. 先做 source/register mapping 的唯讀稽核，不先改 PHY、PI、FINC/FDEC、DDMTD polarity，也不先新增 RTL probe。

## Compile / 燒錄結果

本輪沒有 compile，也沒有燒錄，因此：

- 沒有新的 MIF hash。
- 沒有新的 SOF hash。
- 沒有 Quartus compilation result。
- 沒有 Programmer checksum 或 JTAG configuration result。
- 不能把本輪 source audit 寫成硬體實驗成功。

## 結論

目前最合理的 debug boundary 是：

```text
Master role baseline
    ↓ 保留，不修改
Slave PTP packet / foreign master
    ↓
WR parent flags / signaling
    ↓
WRS_S_LOCK / wrpc_spll_locking_enable
    ↓
spll_init / helper_start / RCER
    ↓
TAG_VALID / TRR / IRQ
    ↓
SoftPLL servo / time_valid
```

本輪只完成 source-level 因果鏈整理，尚未證明實機卡在哪一個節點。

## Next Step

下一步仍維持唯讀、無燒錄：

1. 用現有 JTAG mailbox 連續讀取 `wrpc_wr_lock_enable_count`、`wrpc_wr_lock_poll_count`、`wrpc_wr_handshake_fail_count`、`WR state`、parent flags、`SPLL sequence state`、`RCER`、`TAG_VALID`、`TRR_WRITE`、`IRQ`。
2. 觀察 `wrpc_wr_lock_enable_count` 是否曾由 0 變為非 0；這比猜測 `rts_lock_channel()` 更直接。
3. 若 `lock_enable_count` 增加但 `RCER` 長期為 0，才把問題縮到 `spll_init()` 後的 sequence/helper/tagger enable。
4. 若 `lock_enable_count` 始終為 0，則優先查 WR parent/LOCK signaling/WR state handoff。
5. 只有 read-only evidence 仍無法區分時，才設計下一個最小 firmware observability 變因；任何 compile 或燒錄都要另立實驗紀錄。

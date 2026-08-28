# EXP-WRPC-STEP4-RUNTIME-BUSDONE-STATIC-FSM-CORRELATION-20260828

## 結論

本輪依分支3建議，只加入唯讀 observability，不修改 runtime 或 static FSM 功能行為。完整 Quartus compile、雙板 fresh program 與 Master-only `mode master\n` 被動觀測均完成。

本輪不能證明「runtime DCO completion 的 `bus_done` 使 static FSM false advance」。依預先定義的停損規則，因為 `SYSTEM_START_SEEN=1` 且 startup `system_start` 先於 static state 0→1，正式判定為：

```text
RUNTIME_BUSDONE_STATIC_FSM_FALSE_RESTART = NOT_PROVEN
RUNTIME_CAUSAL_CHAIN = STOPPED_BY_SYSTEM_START
NEXT_REQUIRED_ISOLATION = separate system_start from runtime bus_done before retest
FUNCTIONAL_FIX_THIS_ROUND = NONE
```

但本輪得到一個新的、雙板一致的 startup 證據：`system_start` 出現後，static state 立即離開 0，接著 `oPLL_REG_CONFIG_DONE`/SI config drop、WR-core reset 與 CPU reset 都被 sticky timestamp 捕捉到。這是 startup path 的強烈 source-backed correlation，不能倒推成 runtime `bus_done` 的因果證明。

## Source-backed instrumentation

Source commit：`2b3c76eb6ee25eacc5eb3da49415c428c44a95f4`。

修改範圍只有：

- `quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v`：暴露 static register state、static controller config-done falling-edge pulse 與 static access-start。
- `quartus/jtag_runtime_diag/si5340a_controller_dco.v`：轉接 static/runtime bus observability，包括 `RUNTIME_STATE`、`BUS_STATE`、`BUS_DONE`、`RUNTIME_START`、`BUS_ENABLE`、`SYSTEM_START`。
- `DE5a_wr_master_jtag.vhd`、`DE5a_wr_slave_jtag.vhd`：在 `CLK_50_B2J` domain 加入不受 CPU/WR reset 清除的 free-running counter、first-event sticky timestamps，以及 JTAG probes 28–33；既有 probes 0–27 未改編號。
- `scripts/jtag/read_runtime_busdone_static_fsm_correlation.tcl`：只讀取 probes；唯一寫入是指定的 Master VUART `mode master\n` stimulus，Slave 不注入。

目前 source 中可直接對照的 startup path 是：

```text
initial_config: cnt == 21'h1ffffe -> oINITIAL_START
si5340a_controller_dco: system_start = user_start_rise | initial_start
si5340a_controller_dco: static controller iENABLE = system_start
si5340a_controller_dco: static_bus_enable = system_start | !static_ready | bus_state
```

其中 `initial_config` 的 21-bit counter 會在 FPGA configuration 後約 42 ms 產生一次 startup pulse；這正是本輪 timestamp `0x001FFFFF` 的 source-backed 對應。

## Build and programming provenance

- Git branch：`exp/step4-softpll-enable`
- Source/reader commit：`2b3c76e`
- Raw record commit：`61c3e27`
- Quartus build：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.457 ns`
- Slave full compilation：successful；`TIMING_CLOSED=NO`；worst setup slack `-0.454 ns`
- Master MIF SHA-256：`01d30160aa3e922829f2de73cc6c37ed46a8d57e98391157d86c43fbd57f59ab`
- Slave MIF SHA-256：`cb8e0ef92d9270effce788958bc3d8bc88bf3f3a6ff51883a2a1279771508d4c`
- Master SOF SHA-256：`3d7cd7270bbb30bcf31489f8ae36d61164644730179623d0d0290234cb51796c`
- Slave SOF SHA-256：`da21789892e6ede35660e8c6b5f6d21616d118af327bc850ca82964a813042c2`
- Master program：cable `DE5 [1-11.1]`，checksum `0x30AF64BE`，JTAG ID `0x02E660DD`，configuration succeeded。
- Slave program：cable `DE5 [1-11.2]`，checksum `0x30AFDECB`，JTAG ID `0x02E660DD`，configuration succeeded。
- Build 與 program 均使用 fresh output；沒有使用舊 SOF 作為本輪硬體證據。

## Capture protocol

- Samples：160 per board。
- Interval：200 ms；每板約 32.9 s。
- Observer domain：`CLK_50_B2J`。
- Baseline：先讀 sample 1–9。
- Stimulus：Master 在 sample 10 只注入一次 `mode master\n`，共 12 bytes；每個 byte 的 Wishbone VUART write 都回報完成。
- Slave：完全沒有 stimulus；reader 在 Slave 明確輸出 `CORRELATION_INJECT_SKIPPED`。
- 讀取方式：DCO probe 8、correlation probes 28–33、既有 live/reset/status probes；沒有 CPU hold/release、CPU reset write、WR/PHY/SoftPLL control write。

## Baseline and raw result

兩板 fresh program 後的第一筆 correlation sample 都顯示：

```text
ARMED=1
STATIC_CURRENT=00
STATIC_READY=1
SI_CONFIG_DONE=1
WR_CORE_RESET_N=1
CPU_RESET=0
RT_STATE=0
BUS_STATE=0
BUS_DONE=0
RUNTIME_START=0
RUNTIME_BUS_ENABLE=0
DPLL_LOAD=0
HPLL_LOAD=0
RESET_STICKY_RAW=00010200020201FF
```

Startup correlation timestamps 在 Master 與 Slave 都一致：

```text
T_SYSTEM_START_SEEN       = 001FFFFF
T_STATIC_STATE_LEAVE_ZERO = 00200000
T_STATIC_READY_DROP       = 00200001
T_SI_CONFIG_DROP          = 00200001
T_WR_CORE_RESET_ASSERT    = 00200001
T_CPU_RESET_ASSERT        = 00200001
T_BUS_DONE                = 00203941
T_STATIC_DONE_PULSE       = 00203B42
T_DAC_LOAD                = 00000000
T_RUNTIME_START           = 00000000
STATIC_BEFORE             = 00
STATIC_AFTER              = 01
```

這個順序首先排除了本輪 runtime-DCO causal chain：`T_DAC_LOAD` 與 `T_RUNTIME_START` 都沒有發生，而 `SYSTEM_START_SEEN` 在 state transition 前已被捕捉。`T_BUS_DONE`/`T_STATIC_DONE_PULSE` 的 timestamp 晚於 state leave，因而不能把 state leave 解釋為一次已隔離的 runtime completion。

Master-only `mode master` 的 12 個 VUART bytes 在 sample 10 皆有 log，且之後 Master/Slave 的 correlation sticky timestamps 都沒有新增第二組事件；這也表示本輪 capture 沒有得到 command-triggered runtime DCO completion。

## Decision and next boundary

依分支3定義：

1. static state 確實從 `00` 留到 `01`，並造成 ready/config/reset chain 的可觀測關聯。
2. 但 `SYSTEM_START_SEEN=1`，且 startup path 先發生；所以不能宣稱 `STATIC_FSM_FALSE_RESTART_FROM_RUNTIME_BUS_DONE=PROVEN`。
3. 本輪停止，不做 functional fix；特別不修改 static completion gating。
4. 下一個必要隔離是先處理/排除 `initial_config -> system_start -> static controller iENABLE` 的 startup transaction，再重跑 runtime-only bus_done correlation。

## Raw evidence

完整 raw capture、build info/log、programming result、source snapshot、source diff 與 reader source 保存在：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-RUNTIME-BUSDONE-STATIC-FSM-CORRELATION-20260828/`

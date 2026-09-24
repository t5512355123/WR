# EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829

## 實驗目的

在 `exp/step4b-slave-softpll-startup` 恢復 Master 的正常 boot role，解除前一輪
Slave Step4B 的 upstream blocker。這一輪只改：

```text
CONFIG_INIT_COMMAND="vlan off;ptp stop"
→ CONFIG_INIT_COMMAND="mode master;vlan off;ptp stop;ptp start"
```

Source commit：`732c8e42b6086a79dccbe7d935d1f7594ccc6c35`。

## 實驗流程

- 兩張 DE5a fresh build、fresh program。
- 正確使用 `quartus/jtag_runtime_diag` Master/Slave mailbox image。
- focused Step2 regression：20 samples、500 ms gap。
- full `read_wb_runtime.tcl --raw` dashboard。
- 另以 `read_step4_runtime_context.tcl` 讀取未經 dashboard semantic gate 的原始 SoftPLL shadow。

先前誤執行的 `quartus/rs422_uart_diag` build 不納入任何判定；它不是本輪使用的
JTAG Wishbone mailbox image。

## Build / program provenance

Build info 原檔保存在本實驗 raw 目錄：

- `raw/EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829/build_info_jtag_master.txt`
- `raw/EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829/build_info_jtag_slave.txt`

摘要：

- Quartus 17.0.0 Build 595；Master/Slave full compile successful。
- timing closed：`NO`；Master worst setup slack `-0.177 ns`，Slave `-0.272 ns`。
- Master SOF SHA256：`9615cc59ef02ad3f967b0651701d2335d280ce010ab87f5da109ea2c20e8522b`。
- Slave SOF SHA256：`f236e4f0158a6167cc0ec436ccfb331929df1e836fc2f2fff6534ac67b5a018a`。
- Master cable `DE5 [1-11.1]` programming successful，JTAG ID `0x02E660DD`。
- Slave cable `DE5 [1-11.2]` programming successful，JTAG ID `0x02E660DD`。
- programming 均為 0 errors / 0 warnings。

## Upstream 結果

Full dashboard 已證明：

```text
Master Step1 = PASS
Master Step2 = PASS
Master WDIAGS_MODE = 2 (MASTER)
Master WDIAGS_PTP = 6 (MASTER)

Slave Step1 = PASS
Slave Step2 = PASS
Slave WDIAGS_MODE = 3 (SLAVE)
Slave WDIAGS_PTP = 9 (SLAVE)
Slave Step3 = PASS
STEP4B_ALLOWED = YES
```

Master 的 Step4A event chain 也為 PASS，reset/re-entry deltas 全部為 0。

## Slave 原始 SoftPLL 證據

`runtime-context-raw.log` 未經 dashboard 的重複讀值顯示：

```text
SPLL_STATE = 00030004
LOCK_ENABLE = 00000004
SPLL_INIT_COUNT = 00000004
SPLL_STATE_VISIT_MASK = 00000618
SPLL_LAST_STATE = 00000004
RCER = 00000001
OCER = E4CDB001 / F3AFBE01
```

依 source mapping：

- `SPLL_STATE=0x00030004` 代表 `mode=3 (SLAVE)`、`align=0`、`seq=4`。
- `LOCK_ENABLE=4` 與 `SPLL_INIT_COUNT=4` 證明 WR lock handoff 與 `spll_init()` 已進入。
- `SPLL_STATE_VISIT_MASK=0x618`、`SPLL_LAST_STATE=4` 證明 sequencer 已離開 disabled/reset。
- `RCER=1` 證明 reference channel 已 enable。
- `OCER` 的低 byte 是 `0x01`；`0xE4CD` / `0xF3AF` 是 VHDL source 明確保留的
  FB low-qualification diagnostic alias，且會隨 runtime counter 改變。
- Slave 的 DMTD accepted、TAG、TRR write/pop、IRQ、helper counters 在 full
  dashboard before/after window 全部為正 delta；四個 reset/re-entry delta 全部為 0。

## 為何本輪仍不能寫 Step4B PASS

目前 dashboard 結果仍是：

```text
STEP4B_ALLOWED = YES
STEP4B_RESULT = STARTUP_NOT_PROVEN
STEP4B_FIRST_INACTIVE_BOUNDARY = SPLL_STARTUP
```

這個結果是 reader decode/validation 問題，不是可直接宣告的 SoftPLL failure：

1. Step4B reader 先把十六進位文字 `00030004` 轉成 Tcl 整數，再交給會重新以
   十六進位解析文字的 `field32()`，因此得到錯誤的 `mode=25`、`seq=18`。
2. `OCER` 上半部是 source-defined live diagnostic alias；reader 卻要求整個
   word 上半部為零，並用 full-word stable-read。這會把有效的 `...01` 讀值變成
   `INVALID`。
3. focused Step2 reader 對 `PTP=01014106` / `00004109` 直接比較 full word，
   所以雖然 20/20 samples 穩定且 dashboard semantic gate 已證明 Step2 PASS，
   focused summary 仍錯誤列為 FAIL。

因此本輪結論是：

```text
UPSTREAM = PASS
SLAVE_SOFTPLL_RAW_STARTUP = OBSERVED
FORMAL_STEP4B = NOT YET PASS
BLOCKER = DIAGNOSTIC_READER_SEMANTICS
```

## Raw evidence

- `raw/EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829/dashboard-raw.log`
- `raw/EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829/step23-jtag-step2-raw.log`
- `raw/EXP-WRPC-STEP4B-RESTORE-MASTER-BOOT-INIT-20260829/runtime-context-raw.log`

本輪尚未詢問 merge，也沒有合併到 `main`。

## 下一步

只修正 read-only dashboard/focused regression 的十六進位欄位解析與 OCER
source-defined alias/stability handling，重新 build/program/觀測一次；不修改
SoftPLL、DMTD、WR signaling、PTP、PHY、SI5340 或 reset/FSM 功能。

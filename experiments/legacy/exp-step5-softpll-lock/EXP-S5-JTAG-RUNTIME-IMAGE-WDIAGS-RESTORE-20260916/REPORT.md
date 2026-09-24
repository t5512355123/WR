# EXP-S5-JTAG-RUNTIME-IMAGE-WDIAGS-RESTORE-20260916

日期：2026-09-16（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
目的：使用包含 JTAG WB mailbox 的 runtime image，重新建立兩張 DE5 的
WDIAGS／In-System Sources and Probes 觀測前置條件，並以既有 mapping
self-test 確認 transport 與 mapping 語意。  
本輪不修改 production C、RTL、SDB、SoftPLL 控制參數或硬體控制流程。

## Verdict

```text
IMAGE_CONTRACT = PASS
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
WDIAGS_TRANSPORT = PASS
WDIAGS_MAPPING_SEMANTICS = INVALID
CLASSIFICATION = MAP_SEMANTICS_INVALID
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

這輪修正了上一輪的前置問題：JTAG runtime image 內確實有 mailbox，且兩張
板都能被 `quartus_stp` 讀取。兩板合計 20 筆 sample 全部完成 transaction、
沒有 timeout；但是既有 Tcl reader 對 mapping magic 的 validity 檢查 20/20
失敗。因此本輪只能判為「transport 已通、mapping contract 尚未通」，不能
把它當成 Step5 PLL lock 結果。

## Laptop → GitHub → Pain provenance

本輪 Pain 使用 Laptop 推送後的相同 checkout：

```text
SOURCE_COMMIT = e43fa9ff64b930b1bac4913cb9be4687a9a1d93e
PAIN_CHECKOUT = e43fa9ff64b930b1bac4913cb9be4687a9a1d93e
BRANCH = exp/step5-softpll-lock
QUARTUS = 17.0.0 Build 595 04/25/2017 SJ Standard Edition
```

Laptop 端 image contract analyzer 為 PASS，確認 master/slave QSF 都包含
`wr_jtag_wb_mailbox.vhd`、mailbox 使用 source/probe instance 1，且 build
與 programmer 指向 `quartus/jtag_runtime_diag` 的 JTAG runtime image。

離線 analyzer 輸出保留於 [preflight-verdict.json](analysis/preflight-verdict.json)。

## Build evidence

兩張板都完成 full compile；Quartus build records 與完整 compile log 保留於
[raw/build](raw/build)。

| image | result | SOF SHA-256 | MIF SHA-256 | timing |
|---|---|---|---|---|
| Master `DE5 [1-11.1]` | successful | `e82ebffd667c6eb08d7c4154c210c14371a5a70dc38781f637922c33574cbf5e` | `3561639e6a714ef6829e9952e01eded056f85197c7d67d88e05830f77a25e615` | `TIMING_CLOSED=NO`, WNS `-0.047 ns` |
| Slave `DE5 [1-11.2]` | successful | `78eb0237277342c23ba8d06c6f6d68f8df7838cf4006fe48c6efcf8a298776c5` | `9447f9a509fa7568aa412d0e506a5894bc4ddd04f22b52e93a50c9ec454436fa` | `TIMING_CLOSED=NO`, WNS `-0.268 ns` |

Timing 尚未 closed 是目前既有 implementation caveat；本輪沒有修改 timing
或以 timing 狀態替代 Step5 verdict。

## Programming evidence

兩張板 programming 都成功，原始輸出保留於
[program-jtag-master.log](raw/program-jtag-master.log) 與
[program-jtag-slave.log](raw/program-jtag-slave.log)。

| image | cable | programmer checksum | result |
|---|---|---|---|
| Master | `DE5 [1-11.1]` | `0x30B89B19` | configuration succeeded; 0 errors, 0 warnings |
| Slave | `DE5 [1-11.2]` | `0x30B84088` | configuration succeeded; 0 errors, 0 warnings |

## WDIAGS transport and mapping preflight

執行：

```text
timeout 180s /mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wdiags_mapping_selftest.tcl 1000
```

原始輸出保留於 [wdiags-preflight.log](raw/wdiags-preflight.log)。本次輸出
顯示兩個 hardware 都能建立 instance 1 並完成四個 WB read：

```text
WDIAGS_WB_READS = COMPLETE
WDIAGS_TRANSPORT_TIMEOUT_ROWS = 0
WDIAGS_MAP_SAMPLE_ROWS = 20
WDIAGS_MAP_VALID_ROWS = 0
WDIAGS_MAP_RESULT (DE5 [1-11.1]) begin_valid=0 end_valid=0
WDIAGS_MAP_RESULT (DE5 [1-11.2]) begin_valid=0 end_valid=0
WDIAGS_MAP_DONE
JTAG_WDIAGS_PREFLIGHT_RC = 0
```

實際 sample 具有完整回應，並非 timeout。例如兩張板都回傳非 `TIMEOUT` 的
`COUNTER` 與 `INVERSE`；而且低 16 bits 滿足互補關係：

```text
Master: COUNTER=...013B, INVERSE=...FEC4
Slave:  COUNTER=...00CB, INVERSE=...FF34
```

所以這次不能再分類為 `NO_PREFLIGHT_ROWS` 或 `TRANSPORT_TIMEOUT`。

Laptop analyzer 結果：

| field | result |
|---|---:|
| `done_marker_seen` | `true` |
| `sample_rows` | `20` |
| `transport_complete_rows` | `20` |
| `transport_timeout_rows` | `0` |
| `mapping_valid_rows` | `0` |
| `board_count` | `2` |
| `classification` | `MAP_SEMANTICS_INVALID` |
| analyzer return code | `2` |

return code 2 是預期的「資料完成但語意 validity 不成立」判定，不是 analyzer
crash，也不是 Step5 failure。

## Source-backed mapping audit

在 preflight 後對照 source，發現既有 reader 的 magic expectation 已經落後
目前 firmware map：

| CPU address | 既有 Tcl reader 的解讀 | 目前 firmware source 的解讀 |
|---|---|---|
| `0x00100B2C` (`0x12C`) | `MAGIC_A`, expected `A5A5122C` | Helper PI snapshot request count |
| `0x00100B30` (`0x130`) | `MAGIC_B`, expected `A5A51330` | Helper PI snapshot acknowledgement count |
| `0x00100B34` (`0x134`) | mapping counter | mapping counter；snapshot 後由 bank-commit count overlay |
| `0x00100B38` (`0x138`) | mapping inverse | mapping inverse；snapshot 後由 overwrite count overlay |

證據來源：

```text
vendor/wrpc-sw/include/hw/wrc_diags_regs.h:28-33
vendor/wrpc-sw/include/hw/wrc_diags_regs.h:85-88
vendor/wrpc-sw/dev/wdiags.c:1023-1041
vendor/wrpc-sw/dev/wdiags.c:1244-1265
vendor/wrpc-sw/lib/task-diags.c:330
scripts/jtag/read_wdiags_mapping_selftest.tcl:42-50, 93-99
```

目前 firmware 的 `wdiags_write_mapping_self_test()` 並沒有寫入固定的
`A5A5122C`／`A5A51330`；它在 snapshot 尚未啟動時把 counter/inverse 寫到
`0x134/0x138`，而 `0x12C/0x130` 已由 snapshot request/ack counter 擁有。
這與本輪硬體讀值一致：`0x12C/0x130` 為 zero，`0x134/0x138` 則是會增加且
互補的 counter/inverse。這是 observer contract mismatch 的直接證據，不能
用來推論 Main 或 Helper PLL 行為。

## Scope freeze

本輪保持以下項目不變：

```text
production C control logic = unchanged
RTL / SDB / PHY / reset = unchanged
SoftPLL PI / gain / threshold / timeout = unchanged
bootstrap / arbiter / mailbox hardware = unchanged
DAC behavior and ordering = unchanged
```

本輪只使用已存在的 JTAG runtime image、離線 contract analyzer 與只讀
WDIAGS preflight。沒有觸發 Helper PI snapshot，也沒有執行 F4L observer，
因為 mapping contract 尚未完成驗證。

## Next boundary

下一輪仍不調 PI、不改 timeout，也不以現有固定 magic 重新包裝結果。應在
Laptop 先修正 `scripts/jtag/read_wdiags_mapping_selftest.tcl` 的 observer
contract，使它依目前 header/source 驗證 `0x134/0x138` 的 counter/inverse，
並明確把 `0x12C/0x130` 當作 snapshot request/ack counters；完成離線測試後，
依同一流程重新 build/program，再重跑 preflight。只有 mapping contract
通過後，才恢復 F4L Main/Helper correlation，進一步判斷 Step5 lock。

## Evidence inventory

```text
analysis/image-contract.json
analysis/preflight-verdict.json
raw/build/build-info-jtag-master.txt
raw/build/build-info-jtag-slave.txt
raw/build/firmware-master-hashes.sha256
raw/build/firmware-slave-hashes.sha256
raw/build/quartus-jtag-master-compile.log
raw/build/quartus-jtag-slave-compile.log
raw/build/session-build-jtag-master.log
raw/build/session-build-jtag-slave.log
raw/program-jtag-master.log
raw/program-jtag-slave.log
raw/wdiags-preflight.log
```

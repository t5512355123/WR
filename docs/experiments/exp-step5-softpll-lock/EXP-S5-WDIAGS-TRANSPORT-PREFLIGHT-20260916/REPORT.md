# EXP-S5-WDIAGS-TRANSPORT-PREFLIGHT-20260916

日期：2026-09-16（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`
目的：在重跑 F4L Main diagnostic correlation 前，先以既有 WDIAGS mapping
self-test 確認兩張 DE5 的 JTAG／In-System Sources and Probes 前置通道可用。
本輪不修改 production C、RTL、SDB 或任何 SoftPLL 控制參數。

## Verdict

~~~text
CLASSIFICATION = NO_PREFLIGHT_ROWS
PREFLIGHT_PASS = NO
STOP_REASON = NO_IN_SYSTEM_SOURCES_AND_PROBES
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
~~~

Pain 端兩張板都完成了與 Laptop 相同 commit 的 full compile 與 programming，
但 preflight 在兩個 cable 上都回報：

~~~text
ERROR: No In-System Sources and Probes instance was found.
~~~

因此本輪沒有任何 `WDIAGS_MAP_SAMPLE` row，不能判定 WDIAGS mapping 正確或錯誤，
也不能把此結果當成 PLL／Step 5 failure 的根因。`quartus_stp` 的 Tcl evaluation
return code 為 0，只代表腳本執行完成；離線 analyzer 以 return code 2 明確拒絕
把沒有資料的 session 判為 preflight pass。

## Scope and control freeze

Laptop 本輪新增的兩個檔案只有離線判定器與測試：

~~~text
scripts/experiment/step5_wdiags_transport_preflight.py
scripts/tests/test_step5_wdiags_transport_preflight.py
~~~

判定器將「無 row」、「transaction timeout」、「transport 完成但 mapping 不符」
與「兩張板皆完成且 begin/end 有效」分開，不從 preflight 推論 Step 5 lock。
Production C／RTL、PHY、reset、mailbox、arbiter、bootstrap、timeout、PI/gain/
threshold、DAC 與控制分支均未修改。離線測試通過：

~~~text
WDIAGS_PREFLIGHT_OFFLINE_TESTS_PASS
~~~

## Laptop → GitHub → Pain provenance

~~~text
SOURCE_COMMIT = f38fa9c5d504feb5201314ba421fc6d515ff9a15
PAIN_CHECKOUT = f38fa9c5d504feb5201314ba421fc6d515ff9a15
~~~

Pain build records 顯示兩張板均使用上述 checkout，Quartus 17.0 Build 595，
full compilation successful：

| image | result | SOF SHA-256 | MIF SHA-256 | timing |
|---|---|---|---|---|
| Master `DE5 [1-11.1]` | successful | `6b8ae9d565544b427e491ffc158fabe68084aa4fc14f1c9dcb7b24877c51eb98` | `53fce63fb394830c599e7d317a5f10ebc605c868632c2fe6e7185f7ef3c28413` | `TIMING_CLOSED=NO`, WNS `-2.873 ns` |
| Slave `DE5 [1-11.2]` | successful | `f5ea70c511bcf44b99fe0395ca63f6aae15fc3d68782db9d1b99e4da925d9241` | `43f9ee660c6c574b20041cd421c57892e3b8409b4b48459ff4159192c3a1b19c` | `TIMING_CLOSED=NO`, WNS `-3.007 ns` |

完整建置 identity、hash 與 compile log 保留於 [raw/build](raw/build)。Timing
尚未 closed 是既有 implementation caveat，本輪不以它作為 Step 5 verdict。

## Programming

兩張板 programming 均成功，完整輸出位於：
[program-master.log](raw/program-master.log) 與
[program-slave.log](raw/program-slave.log)。

| image | cable | programmer checksum | result |
|---|---|---|---|
| Master | `DE5 [1-11.1]` | `0x30ADDBBE` | configuration succeeded; 0 errors, 0 warnings |
| Slave | `DE5 [1-11.2]` | `0x30AB920F` | configuration succeeded; 0 errors, 0 warnings |

## WDIAGS preflight

執行：

~~~text
timeout 180s /mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_wdiags_mapping_selftest.tcl 1000
~~~

腳本設定與既有 mapping self-test 一致：

~~~text
gap_ms=1000
expected_magic_a=A5A5122C
expected_magic_b=A5A51330
~~~

實際輸出摘要：

~~~text
=== DE5 [1-11.1] ===
ERROR: No In-System Sources and Probes instance was found.

=== DE5 [1-11.2] ===
ERROR: No In-System Sources and Probes instance was found.

WDIAGS_MAP_DONE
Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
PREFLIGHT_RC=0
~~~

原始輸出保留於 [wdiags-preflight.log](raw/wdiags-preflight.log)。由於兩個 board
都在 `start_insystem_source_probe` 前置步驟失敗，沒有完成 mailbox transaction，
所以沒有 sample、沒有 valid/invalid mapping row，也沒有 board-level begin/end
結果。

## Offline replay

離線判定保留於 [preflight-verdict.json](analysis/preflight-verdict.json)：

| field | result |
|---|---:|
| `done_marker_seen` | `true` |
| `sample_rows` | `0` |
| `transport_complete_rows` | `0` |
| `transport_timeout_rows` | `0` |
| `mapping_valid_rows` | `0` |
| `board_count` | `0` |
| `classification` | `NO_PREFLIGHT_ROWS` |
| `preflight_pass` | `false` |
| analyzer return code | `2` |

這個 return code 是預期的資料不足判定，不是 analyzer crash。Laptop 端 raw
檔案與 Pain 端收集時的 SHA-256 一致：

~~~text
program-master.log   969a973ec7169a78ca5f3c9441421b726e58c0ce6bd94b9f2afb720fdf382ab3
program-slave.log    9332aedc5e68ab14c347e1ea35fb5e5a5e3afc3259a88aa2f11d439422207934
wdiags-preflight.log 202750957a1d4aa195246ea7553c494bc8aa348beb42ee777c08ca0fb12df615
~~~

## Interpretation and next boundary

本輪證明的是：兩張板的 bitstream programming 成功，但目前這個 session 無法
取得任何 In-System Sources and Probes instance。它不能區分以下兩者：

1. programmed image／Quartus STP 對該 JTAG interface 的 source/probe instance
   不相容或未包含；
2. JTAG chain、cable 或當下介面狀態使 source/probe discovery 失敗。

因此現在不能宣稱 WDIAGS address mapping 錯，也不能宣稱 WDIAGS mailbox、Helper
或 Main producer 已失效，更不能據此調整 PI 或重新定義 Step 5。先前 F4L 的
WDIAGS timeout 與本輪兩板都沒有 instance 互相支持「診斷通道前置條件尚未成立」
這個判讀，但仍不足以指定其硬體／映像根因。

下一個必要實驗邊界是只讀的 JTAG／SignalTap image compatibility 與
source/probe availability inventory：確認 programmed SOF 是否含有可被目前
Quartus STP 發現的 instance、cable/chain 是否正確，以及既有 reader 是否仍能
在同一 session 建立 probe。只有 preflight 能產生可信的兩板 sample 與 begin/end
結果後，才重跑 frozen-control 的 WDIAGS mapping self-test，再回到 F4L Main
phase correlation。此輪不重跑 F4L、不調參、不修改 production code、不宣告
Step 5、不 merge 到 main。

## Evidence inventory

~~~text
raw/build/build-info-master.txt
raw/build/build-info-slave.txt
raw/build/firmware-master-hashes.sha256
raw/build/firmware-slave-hashes.sha256
raw/build/quartus-master-compile.log
raw/build/quartus-slave-compile.log
raw/build/firmware-master-build.log
raw/build/firmware-slave-build.log
raw/program-master.log
raw/program-slave.log
raw/wdiags-preflight.log
analysis/preflight-verdict.json
~~~

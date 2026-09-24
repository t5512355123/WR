# EXP-S5-DCO-LIVENESS-20260912

## 結論

本輪完成的是 **L1 離線 source-level liveness／transaction-completion 驗證**，不是 FPGA 硬體 Step5。L1 測試結果為 `PASS`，但 Step5 仍為 `NOT_COMPLETE`，沒有進行 merge。

最重要的兩個證據是：

1. 在 Main 保持 residual work 的 contention window 中，固定優先仲裁讓 Helper 完成 `0` 筆交易；`SOURCE_LIVENESS_RISK_REPRODUCED=YES`。
2. 注入一個 NACK 後，`ACK_ERROR=1`，但 Helper 仍被計為完成 `1` 筆，`DCO_ERROR=0`；`TRANSACTION_COMPLETION_DEFECT_REPRODUCED=YES`。

這兩項結果說明下一輪硬體實驗應優先觀察「仲裁等待」與「ACK/NACK/timeout 是否真的等於 applied/completion」，而不是再盲目掃 PI gain。

## 實驗邊界與 provenance

- 日期：2026-09-12（Asia/Taipei）
- branch：`exp/step5-softpll-lock`
- source commit：`ddec72141edc93b28f77c402cab8859f48c09f1e`
- Pain checkout：同一個 `ddec721`
- 測試主體：production `si5340a_controller_dco`、production I2C engine 與 pin-level I2C model
- 模擬器：ModelSim Intel FPGA Edition 10.5b (2016.10)
- 硬體燒錄：`NOT_APPLICABLE_L1_OFFLINE`
- 唯一 production RTL 變因：無；本輪只修正 testbench 的 transaction accounting，並把 contention target 擴大到 `16'hffff`

這一輪沒有修改 arbiter、ACK error、PI、startup FSM 或 SoftPLL；也沒有把離線結果冒充成硬體結果。ModelSim 執行時出現 48 個既有 optional-port／symbol warnings，但 compile errors 與 runtime errors 均為 0，測試本身以 `L1_TEST_RESULT=PASS` 結束。

## 測試方法

執行的工作包是：

```text
scripts/experiment/tb_dco_liveness.sv
scripts/experiment/run_dco_liveness.sh
```

Pain 上的執行命令為：

```text
MODELSIM_BIN=/mnt/ds1515/opt/intelFPGA/17.0/modelsim_ase/linuxaloem \
  bash scripts/experiment/run_dco_liveness.sh
```

testbench 直接驅動 production DCO controller 的 runtime load interface，並在 I2C pin level 驗證：slave address、page select、mask register、DCO register 的四筆 write 順序。每個 logical DCO transaction 的四筆 write 共用一個 persistent `logical_slot`；因此不會再把單一 register write 誤判成完整 transaction。

## 結果

| Case | 輸入 | Main completed | Helper completed | Transactions | Wrong page | Sequence errors |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `MAIN_JUMP` | 32768 → 32832 | 4 | 0 | 4 | 0 | 0 |
| `HELPER_JUMP` | 5 → 261 | 0 | 4 | 4 | 0 | 0 |
| `MAIN_HELPER_CONTENTION` | Main 32768 → 65535；Helper 5 → 261；1 ms | 208 | 0 | 208 | 0 | 0 |
| `NACK_COMPLETION` | Helper 5 → 69；第一個 data ACK 強制 NACK | — | 1 | — | — | — |

contention 詳細輸出：

```text
L1_CONTENTION MAIN_BEFORE_FIRST_HELPER=-1 FIRST_HELPER_TIME_NS=-1
SOURCE_LIVENESS_RISK_REPRODUCED=YES
```

NACK 詳細輸出：

```text
L1_CASE=NACK_COMPLETION NACKS=1 HELPER_COMPLETED=1 ACK_ERROR=1 DCO_ERROR=0
TRANSACTION_COMPLETION_DEFECT_REPRODUCED=YES
```

總結輸出：

```text
L1_DCO_LIVENESS_SUMMARY MAIN_COMMANDS=212 HELPER_COMMANDS=5 TRANSACTIONS=217 WRONG_PAGE=0 SEQUENCE_ERRORS=0 FAIL_COUNT=0
L1_TEST_RESULT=PASS
```

## 判讀

`MAIN_JUMP` 與 `HELPER_JUMP` 證明目前 production serializer 在正常 ACK 模型下，兩個 owner 的 absolute target 及四筆 page/mask/write contract 可以完成；`WRONG_PAGE=0`、`SEQUENCE_ERRORS=0` 是有效的正向證據。

但 contention case 的 `Helper=0` 不是「Helper 永遠不能完成」的證明，而是在一個持續有 Main residual 的一毫秒觀測窗內，證明固定優先仲裁可以讓 Helper 沒有取得任何服務。這足以把 fair arbitration／bounded wait 列為硬體 first-loss telemetry 的高優先觀測項目。

NACK case 更直接指出 completion contract 的風險：目前 source-level path 將 sticky `ACK_ERROR` 與 DCO completion/applied accounting 分離；因此 transaction 可能在 I2C 失敗後仍被上層看成完成。這是應先在低擾動 telemetry 中核對的候選根因，但本輪尚未修改它。

## Step5 判定

```text
L1_TEST_RESULT = PASS
STEP5_RESULT   = NOT_COMPLETE
HARDWARE_STEP5 = NOT_ASSESSED
```

Step5 需要實體兩板、同一份 source／MIF／SOF provenance、upstream Step1–4B settled PASS，以及完整 closed-loop lock／quality／stability evidence。本輪沒有這些硬體條件，因此不能宣告 Step5 PASS。

## 下一步

依 `Astra建議_2.md`，下一輪應是 L2 low-perturbation hardware first-loss telemetry：固定 source/image manifest，先確認 Step1–4B 在同一 settled window 成立，再記錄每一筆 DCO request 的 owner、target、queue、start、ACK、completion、applied 與 failure reason，並分離 diagnostic bank ownership。

L2 只回答「先失敗的是等待、ACK/completion contract、還是 plant/measurement」，不在同一輪同時改 arbiter、ACK semantics 與 PI。只有在 L2 把 earliest failure boundary 固定後，才選擇一個最小 production functional fix，重新 compile/program 並做硬體驗證。

## 原始資料

- [final L1 log](raw/l1-dco-liveness-ddec721.log)
- [前一版 monitor 修正 log](raw/l1-dco-liveness-f95d3d3.log)
- [manifest](manifest.json)
- [verdict](verdict.json)
- [summary CSV](analysis/l1-summary.csv)
- [raw checksums](raw/checksums.sha256)


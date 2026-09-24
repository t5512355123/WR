# EXP-WRPC-STEP4-CORRELATION-20260820

## 實驗識別

- 實驗名稱：Step 4 helper correlation 位址與內部狀態唯讀稽核
- 日期：2026-08-20
- Branch：`exp/step4-softpll-enable`
- Git commit：`44ea3346b4fc54617175e6f4577f76ee5a0c29ed`
- 想驗證的問題：上一輪 correlation 的 `800040xx` 欄位彼此不自洽；本輪加入 `p_adder`、`tag_d0`、`p_setpoint`、`ref_src`，判斷是 helper 內部 tag arithmetic/measurement 異常，或是 JTAG/WDIAGS 讀取映射問題。

## 相較 baseline 的唯一修改

只增加唯讀診斷欄位，沒有修改 SoftPLL 功能：

- WDIAGS 增加 helper 內部狀態 shadow。
- JTAG correlation 增加 `P_ADDER`、`TAG_D0`、`P_SETPOINT`、`REF_SRC`。
- WDIAGS RAM 擴充至 `0x100..0x128`。
- 未修改 PI gain、lock threshold、DDMTD polarity、DCO gain、SI5340 控制或 WR signaling。

## Fresh build provenance

- Quartus：17.0.0 Build 595 (2017/04/25 SJ Standard Edition)
- Master MIF SHA256：`341396c774d0a979245100fb9afb621be9dab8a001b0aba17e81fcd02349d85a`
- Slave MIF SHA256：`3bccfe42448f41ad8569a77b4e5c699e923154035dfa20d7055ad98415f6a69f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- 共用 SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`3b11da746ba56e2130d0919598fcf2c56b7937a06629b1367ddc76def8456832`
- Slave SOF SHA256：`a632034817d6295e3d2b7cd262d8d532f36fd333071adddecb55de5626bcb10b`
- Master programmer checksum：`0x30A45305`
- Slave programmer checksum：`0x309FEEBA`
- Quartus compile：Master/Slave `Full Compilation was successful`，各 0 errors；既有 timing closure warnings 仍存在。

## 燒錄結果

- Master：`DE5 [1-11.1]`，`Configuration succeeded`，0 errors。
- Slave：`DE5 [1-11.2]`，`Configuration succeeded`，0 errors。
- 原始輸出位於本目錄的 `program_master.log`、`program_slave.log`，pain 亦保留完整 build/program logs。

## JTAG runtime 結果

本輪 fresh SOF 的 correlation 與 time-series 已完成，Quartus Tcl 執行成功；但 correlation 欄位顯示固定的位址 alias，不能把這些欄位當成 helper 演算法的有效數值：

- `TAG_D0` 與 `P_SETPOINT` 能讀到看似合理的 tag 值。
- `TAG_SOURCE_RAW` 多次等於 `RAW_TAG`。
- `EXPECTED_DELTA` 多次等於 `EXPECTED_TAG`。
- `HELPER_UPDATE_COUNT`、`REF_SRC`、`PRECLAMP_ERROR` 反覆讀到相同的低位值。
- 例如第一筆 sample：`RAW_TAG=0970B7A6`、`TAG_D0=0970B7A6`，但 `EXPECTED_TAG=0970AE67`、`P_SETPOINT=0970AE67`；同時 `TAG_SOURCE_RAW=0970B7A6`、`EXPECTED_DELTA=0970AE67`、`HELPER_UPDATE_COUNT=000000E0`、`REF_SRC=000000E0`。這種固定欄位對應不符合各變數的語意。

source audit 找到第一個異常節點：private WDIAGS peripheral 的 SDB window 仍只有 `0x00..0xFF`，但 correlation shadow 寫到 `0x100..0x128`。因此 JTAG 讀取 `0x00100A00..0x00100A28` 時已經離開 private WDIAGS，會碰到後續 peripheral 的位址空間。這是 observability address-map 問題，不是已證明的 SoftPLL measurement 或 control root cause。

同一輪的 bounded time-series 有有效 sample 顯示：

- Master：`status_low=FF`、`wr_mode=2`、`WDIAGS_PTP=6`，PTP RX/TX 持續增加。
- Slave：`status_low=EF`、`wr_mode=3`、`WDIAGS_PTP=9`、`WDIAGS_FOREIGN_META=03000001`，PTP RX/TX 持續增加。
- Slave 仍為 `LOCK_ENABLE=4`、`SPLL_STATE=00030004`、`HELPER_STATE=00000000`、helper error 約為 `-150000`，尚未進入 `START_MAIN`。

因此本輪只支持「Step 1~3 維持、Step 4 correlation 觀測仍無法判讀」；不宣稱 Step 4 PASS 或 FAIL。

原始證據：

- `jtag_hpll_helper_correlation_20x1200ms.log`
- `jtag_runtime_snapshot.log`
- `jtag_timeseries_10x1000ms.log`
- `program_master.log`、`program_slave.log`
- `programmed_sof.sha256`

## 下一步

1. 先提交只修正 peripheral SDB window 的 observability mapping change。
2. 由該 commit 重新 clean build/compile/program，再重跑同一份 correlation script。
3. 只有 correlation 欄位自洽後，才依第一個真正異常的 runtime node 設計一個最小 functional A/B；不修改 SoftPLL 演算法。

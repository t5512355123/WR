# EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824

## 實驗身分

- Experiment ID：`EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-post-div-edge-observability`
- Git HEAD：`13d4c832c5eeda3760b5b058d0e31ef27ef842ea`
- 目的：在不燒錄、不重新編譯的前提下，重新檢查 Step 1～Step 3 regression barrier，並確認新增的 post-divider edge diagnostics Tcl 可以在 pain 上正常執行。

## 本輪允許範圍

本輪只執行既有 JTAG read-only diagnostics 與新增腳本的 read-only smoke test：

- 沒有修改 Master／Slave role switching。
- 沒有修改 PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。
- 沒有寫入 Wishbone control register；mailbox transaction 只用於既有 read protocol。
- 沒有 Quartus compile。
- 沒有 program FPGA。

本 branch 的 source-only commit `13d4c832` 新增的是 sampler 實際輸入（post-divider）邊緣計數的唯讀觀測，以及對應 JTAG alias；因為本輪沒有產生或燒錄 SOF，這些新 counter 尚未部署到板上。

## 建置與 provenance

為保存 MIF provenance，本輪曾在 pain 重新產生 Master／Slave firmware MIF；這不是 FPGA programming，也沒有被本輪硬體使用：

- Quartus 版本：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Pain checkout：`13d4c832c5eeda3760b5b058d0e31ef27ef842ea`
- Pain git status：只保留既有未追蹤項目 `?? "\\"`
- Master MIF SHA-256：`13abfd299224e7dbc88ec7c4d541a6f1940bcf05b9741202206bf5b69a82714a`
- Slave MIF SHA-256：`43a534070326ada2f3556e4d67361d12538dafc9cbdb96203af709bc7e6a6cef`
- 本輪 SOF SHA-256：無；本輪未 compile、未 program

JTAG script SHA-256：

| Script | SHA-256 |
|---|---|
| `read_wb_runtime.tcl` | `95cf3d27fd2d99951c801eabaa0cb2d4068c90f49eb6c9ead569a85aefa2c8cf` |
| `read_wr_handshake_focused.tcl` | `e9a531ff776d991992b5875cb8a94182d8daed35fb68b020631dc538a1b5605b` |
| `read_step23_register_reliability.tcl` | `6415ed2ce5b2b97ca54f4a1d5914833966dbe2405e00d8428e402b1e5e650a1e` |
| `read_master_ptp_slave_parent_long.tcl` | `bdeed134c9d0905c0af820321e2508a4541e41b0e7b23102f7cf0af8029d077f` |
| `read_step4_startup_focused.tcl` | `fdf96fecbe8aac864b74ce2dd8c0ea08d20dfdc314f21eb83c52f74a91fed9c3` |

## 執行命令

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wr_handshake_focused.tcl 20 500

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step23_register_reliability.tcl 10 250 all

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_wb_runtime.tcl

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 10 500

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_step4_startup_focused.tcl 1 0 events
```

五個 Tcl 執行都回報 `Evaluation of Tcl script ... was successful`，Quartus SignalTap II 為 0 errors、0 warnings。最後一個命令特別用來確認新增的 post-div read path 不會造成 Tcl exception；它讀到的 post-div counter 為 0，不能解讀為新硬體 counter 已存在，因為本輪沒有燒錄新 SOF。

## Runtime 原始結果摘要

### Step 1：PHY / Link

`read_wb_runtime.tcl` 兩片均顯示：PHY ready、RX ready、TX ready、timing link、link OK、CPU reset deasserted、RX/TX encoding error gate 正常。因此本輪現場 evidence 支持：

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

Master `DE5 [1-11.1]`：

- `MAC=02:00:22:33:44:01`，但 runtime `MODE=3`、`PTP=4`，不是要求的 Master `MODE=2`、`PTP=6`。
- focused accepted samples 中，Master 只有 `7/20` valid、`13/20` invalid；7 筆 valid 均為 `MODE=3/PTP=4`。
- parent-long valid sample 也持續看到 `MODE=3/PTP=4`、`FOREIGN=0000FF00`。

Slave `DE5 [1-11.2]`：

- `MAC=02:00:22:33:44:02`、`MODE=3`、focused valid samples 為 `PTP=9`。
- focused gate 的 Slave Step 2 為 PASS；PTP/MiniNIC counters 有活動，RXERR 沒有增加。
- reliability script 對 `FOREIGN_META` 有 2 次 invalid，其他 8 次為 no-record `0000FF00`；這是 measurement instability，不能當成穩定 foreign-master PASS。

因此整體 Step 2 barrier 不能通過。Master 的 repeated accepted evidence 已足以構成目前板上 runtime 的 Step 2 failure；Slave 的 foreign read 還另外保留 measurement-invalid/retest 證據。

```text
STEP2_REGRESSION = FAIL
```

這個 FAIL 是「目前已燒錄影像的 runtime gate 不符合要求」，不是 fresh `13d4c832` SOF 的功能失敗結論，因為本輪沒有 compile/program，也沒有本輪 SOF provenance。

### Step 3：WR Parent / Signaling

目前兩片 focused sample 都沒有取得穩定的 WR signaling positive evidence：

- `WR_RX_SIGNAL=0x0000/0`。
- `WR_TX_SIGNAL=0x0000/0`。
- `LOCK_ENABLE=0`。
- live state 為 `WRS_IDLE`。
- Master 沒有可適用的 Slave parent handshake；Slave 也沒有穩定 foreign/parent/LOCK/SLAVE_PRESENT 組合。

因此本輪不能宣稱 Step 3 PASS：

```text
STEP3_REGRESSION = FAIL
```

Step 3 的 failure evidence 是現場 accepted read 中持續出現的零 signaling/lock-enable，不是單一 stale mailbox 值。不過因為板上 SOF 未知且不是本輪 HEAD fresh image，不能把它直接歸因為 `13d4c832` 的 source functional regression。

### Step 4：post-divider diagnostics smoke test

`read_step4_startup_focused.tcl 1 0 events` 成功執行並讀出新增欄位：

- `REF_NATIVE_EDGE_COUNT64`、`FB_NATIVE_EDGE_COUNT64` 可讀。
- `REF_POST_DIV_EDGE_COUNT64`、`FB_POST_DIV_EDGE_COUNT64` 可讀，但目前板上讀值為 0。
- Tcl 輸出 `counter_cdc=GRAY2_HI_LO_HI`，沒有 exception。

因為沒有新 SOF，這一段只能證明 Tcl/read path 可執行，不能證明 post-divider counter RTL 已部署，也不能拿來判斷 `/2` 假設。

## Dashboard 判定檢查

本輪 `read_wb_runtime.tcl` 的行為符合回歸規則：

- `WDIAGS_PTP` 仍以合法 enum `1..9` 驗證；stale/filler 或重試後不一致會保留為 invalid evidence。
- `WDIAGS_MODE`、`FOREIGN_META`、`PARSE_META`、WR state、`LOCK_ENABLE`、`SPLL_STATE`、RCER/OCER 均先經 source-backed validation/retry。
- `PTP_TX delta=0` 不單獨讓 Step 2 FAIL；要看 PTP RX 與 MiniNIC TX/RX 的長窗口 activity。
- counter decrease 被保留為 reset/wrap/snapshot boundary 的 retest information，不直接等同硬體錯誤。
- 本輪每個 Tcl script 都完整結束，沒有 `expected integer but got DECREASED` 或其他 Tcl exception。

本輪 dashboard 顯示的 Master `PTP=4`、Slave `FOREIGN_META=0/255` 等，是通過 read validation 後的合法 runtime 值或明確 invalid/retest evidence，不是把 `0xA5A5A...` 當成合法 enum。

## Regression barrier 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED = NO
```

### Failure classification

- **JTAG／dashboard measurement issue：** Slave `FOREIGN_META` 的部分 read invalid，以及 focused status probe 出現 invalid samples；這些已被分開統計，沒有直接混成合法欄位。
- **目前板上 runtime gate issue：** Master role/PTP 不符合 Master baseline，兩片 WR signaling/LOCK_ENABLE 沒有成立；這是目前硬體影像的觀測結果。
- **尚未能宣稱 fresh HEAD hardware/firmware failure：** 本輪沒有 Quartus compile、沒有 program，沒有可把 `13d4c832` 連到板上 SOF 的證據。

## Raw evidence

- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/focused.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/reliability.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/parent_long.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/step4_script_smoke.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/provenance.txt`
- `raw/EXP-WRPC-STEP23-REGRESSION-POSTDIV-20260824/firmware_build.log`

## 下一步

1. 不允許進行 Step 4 functional experiment。
2. 先取得目前板上兩片 SOF 的實際 SHA-256／programmer provenance，或重新依使用者批准的 exact commit 做 clean Quartus build；在此之前不要把現場 failure 歸因到 `13d4c832`。
3. 只有 Step 1～3 在同一份 fresh/current hardware image 上重新取得可靠 PASS，才可 program post-div observability SOF，再比較 raw native、post-div、DMTD 與 D0 transition rate。

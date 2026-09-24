# 實驗紀錄：Master PTP 與 Slave parent 五分鐘精簡唯讀觀測

- Experiment ID：`EXP-WRPC-MASTER-PTP-SLAVE-PARENT-LONG-READONLY-20260818`
- 日期：2026-08-18
- 實驗類型：唯讀 runtime 觀測；沒有 compile、沒有燒錄、沒有修改 FPGA image
- Git branch：`exp/master-9f-observability`
- 觀測工具 commit：`21e6c5b507424bb37e158b2eca85f862312577c9`
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

在不改 Master role、Slave RTL、firmware、PHY 或 SoftPLL 控制參數的前提下，先用較少欄位、較長時間的 JTAG 觀測回答兩件事：

1. Master 的 `WDIAGS_PTP` 是否長時間穩定為歷史成功值 `6`。
2. Slave 是否持續收到 PTP、建立 parent，並開始產生有效 SoftPLL tag/TRR/IRQ 活動。

## 唯一變因

只有觀測方式改變：使用新建的精簡 script，每張板 150 筆、間隔 2 秒，約 5 分鐘。沒有修改任何硬體或 firmware 功能。

## 使用中的 FPGA 映像

沿用上一輪已燒錄的映像，沒有重新燒錄：

| 項目 | 值 |
|---|---|
| Master SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` |
| Master programmer checksum | `0x30A46449` |
| Slave SOF SHA-256 | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| Slave programmer checksum | `0x309FA629` |
| MIF | Master `b85fc3...`；Slave `f24527...`，沿用前一輪紀錄 |

## 執行與原始結果

執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 150 2000
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-PTP-SLAVE-PARENT-LONG-READONLY-20260818/runtime_5min.log
```

原始 log SHA-256：`f689fa2326bf56e144df2a6b939dceacebbbe8d52479db62b0679194c80773b4`

Quartus STP 回報：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
Info: Elapsed time: 00:10:25
MINIMAL_RUNTIME_DONE
```

### Master 150 筆

```text
MODE=2：150/150
marker=B004 seen=1：持續出現
CPU fault=0、im_valid=1：持續出現
status=FF：132/150
status=F3：18/150
WDIAGS_PTP=1：102/150
WDIAGS_PTP=3：27/150
WDIAGS_PTP=4：21/150
WDIAGS_PTP=6：0/150
PTP_RX：固定為 0x2D
PTP_TX：固定為 0x78
```

Master role 沒有掉成 Slave，`MODE=2` 與 marker/CPU 證據穩定；但是 `PTP=6` 沒有在本輪出現，且 status 有 18 筆為 `F3`。因此不能宣稱已完整重現歷史 `MODE=2/PTP=6/status=FF/PTP counter 持續增加` 的五項 baseline。

### Slave 150 筆

```text
MODE=3：150/150
marker=B004 seen=1：持續出現
CPU fault=0、im_valid=1：持續出現
PTP_RX=0：150/150
PTP_TX=0：150/150
TAG=0：150/150
TAG_VALID=0：150/150
TRR_WRITE=0：150/150
IRQ=0：150/150
HELPER_ERROR=0：150/150
SSTAT=0：150/150
```

`TAG_SOURCE` 的 raw counter 在取樣期間持續變化，但沒有對應的有效 `TAG/TAG_VALID/TRR/IRQ`。`PSTAT` 在 0 與 1 間變化；`time_valid` 沒有成立，沒有 SoftPLL lock 證據。Slave 的 raw `FOREIGN`/`PARSE` 欄位也沒有提供一個可穩定宣稱 parent 已成立的完整證據。

## Observation

這次把兩個問題分開了：

1. Master role 本身仍是 `MODE=2`，但本輪 `WDIAGS_PTP` 主要為 `1`，不是歷史成功值 `6`；JTAG 精簡讀取也看到 PTP RX/TX 不再增加。因此 Master 還不能當作完整 control-plane baseline。
2. Slave 有 raw `TAG_SOURCE` 活動，但有效 tag、TRR write、IRQ、SoftPLL state 與 helper 都沒有活動，且 PTP RX/TX 全為 0。這比「helper ref-source gating」更前面，不能直接跳到 FINC/FDEC 或 helper 控制方向。

## Conclusion

證據支持：

- 本輪沒有新增 Master role 切換方法。
- Master CPU/role 的 `MODE=2` 與 marker 證據穩定。
- Slave CPU 仍在執行，但在本輪沒有形成有效 PTP RX/TX 或 SoftPLL tag/TRR/IRQ 活動。
- 目前問題邊界應先保留在 Master PTP runtime / Master-to-Slave parent acquisition 與 raw tag source 到 valid tag 的前段，尚不能宣稱已經只剩 helper。

證據不支持：

- 兩片 DE5a 已完成 White Rabbit 時間同步。
- Master 的 `WDIAGS_PTP=6` 已長時間穩定。
- `TAG_SOURCE` 增加就等於有效 DDMTD tag 已產生。
- `HELPER_ERROR=0` 就等於相位誤差為零。
- FINC/FDEC 方向是目前已證明的根因。

## Next Step

不修改 Master role、不反轉 FINC/FDEC、不改 PHY/PTP/PI/threshold、不新增 RTL observer。先做 source-level read-only audit，逐一核對 `TAG_SOURCE_COUNT`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT` 的 RTL 定義、valid/enable/reset 與 clock-domain 條件；同時核對 `WDIAGS_PTP` 的 firmware enum/mapping。只有取得穩定 PTP/parent 證據後，才回到 Slave SoftPLL input/helper 分支。

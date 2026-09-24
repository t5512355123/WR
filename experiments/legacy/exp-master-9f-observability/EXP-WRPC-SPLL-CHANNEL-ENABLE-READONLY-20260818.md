# 實驗紀錄：SoftPLL 通道 enable 唯讀稽核

- Experiment ID：`EXP-WRPC-SPLL-CHANNEL-ENABLE-READONLY-20260818`
- 日期：2026-08-18
- 實驗類型：原始碼稽核加 JTAG runtime 唯讀觀測；沒有 compile、沒有燒錄、沒有修改 FPGA image
- Git branch：`exp/master-9f-observability`
- Git commit：`fa96357`（補充 `RCER/OCER/OCCR/TRR_CSR/EIC` 唯讀欄位）
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

驗證前一輪五分鐘觀測中的現象：Slave 的 `TAG_SOURCE` raw counter 會增加，但 `TAG_VALID`、`TRR_WRITE` 與 `IRQ` 都是零。這次要確認 SoftPLL 的參考通道是否根本沒有被 enable，並區分：

1. DDMTD 是否有產生 raw tag event。
2. `RCER/OCER` 是否允許 event 進入 tag arbitration。
3. tag 是否進入 TRR FIFO 並觸發 CPU IRQ。

## 唯一變因

只修改 JTAG 觀測腳本，新增既有 diagnostic shadow register 的唯讀欄位：

```text
OCER、RCER、OCCR、TRR_CSR、EIC_IMR、EIC_ISR
```

沒有寫入任何 Wishbone register，沒有寫 `DATA_SNAPSHOT`，沒有修改 Master role、Slave role、PHY、PTP、SoftPLL 參數或 RTL。

## 原始碼稽核結果

### raw source 與 valid tag 是兩個不同階段

在 `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd` 中：

- `tags_p` 是各 DDMTD channel 的 raw event。
- `diag_tag_source_count` 只要看到 `tags_p` 就增加，因此它只能證明 raw event 出現。
- `tags_req` 只有在 raw event 出現且對應的 `RCER/OCER` channel enable 時才會提出 request。
- `tags_grant_p = tags_req and tags_grant`，再經過一個 clock stage 形成 `tag_valid`。
- `TRR` 的 write request 還要滿足 `tag_valid=1` 且 FIFO 未滿。

因此下面這組結果在邏輯上是相容的：

```text
TAG_SOURCE 增加
RCER       = 0
TAG_VALID  = 0
TRR_WRITE  = 0
IRQ        = 0
```

### firmware 對 channel enable 的路徑

在 `vendor/wrpc-sw/softpll/softpll_ng.c` 與 `vendor/wrpc-sw/softpll/spll_helper.c` 中：

- `spll_init()` 會先清除 `SPLL->OCER` 與 `SPLL->RCER`。
- `helper_start()` 才會依 `ref_src` 重新 enable reference channel。
- `mpll_start()` 才會 enable main PLL 的 reference/output channel。
- `spll_check_lock(0)` 只有在 sequencing state 到 `SEQ_READY` 時才回報 lock。

這表示若 Slave 尚未完成 parent/servo 啟動流程，`RCER=0` 會使 raw event 停在 valid-tag 之前。

## 實驗指令與檔案

pain 先 fetch 並 checkout 明確 commit：

```text
git fetch origin exp/master-9f-observability
git checkout --detach fa96357
```

執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 10 1000
```

原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SPLL-CHANNEL-ENABLE-READONLY-20260818/runtime_channel_enable_10s.log
```

原始 log SHA-256：

```text
8e0179489d95351409256e7d0b57a6be6124d8c5bb2a6f909e37891bcd0fb691
```

## pain terminal 原始結果摘要

Quartus STP 回報：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

### Master（DE5 [1-11.1]）

- `MODE=2` 連續 10/10。
- marker `B004`、CPU fault `0`、`im_valid=1` 連續存在。
- `OCER` 的低位可見 output channel 已有活動；`TAG/TAG_VALID/TRR_WRITE/IRQ` 都持續增加。
- `PTP` 在 `1` 與 `3` 間變化，`PTP_RX=0x2D`、`PTP_TX=0x78` 在這個 diagnostic mailbox 取樣中沒有增加。

這次只支持 Master role 仍是 `MODE=2`，不支持已完整重現歷史 `PTP=6` baseline。

### Slave（DE5 [1-11.2]）

10 次讀值共同呈現：

```text
MODE=3
RCER=00000000
PTP_RX=00000000
PTP_TX=00000000
TAG_SOURCE：持續增加
TAG=00000000
TAG_VALID=00000000
TRR_WRITE=00000000
IRQ=00000000
SSTAT=00000000
```

`PSTAT` 在 `0` 與 `1` 間變化，`PTP` 主要為 `1`，偶爾為 `3`；這仍不是 parent 已成立或 SoftPLL 已 lock 的證據。

## Observation

1. Slave 的 raw DDMTD source activity 確實存在。
2. Slave `RCER=0` 連續 10 次，與 `TAG_VALID/TRR_WRITE/IRQ` 全零同時出現；這是目前最直接的硬體/韌體邊界證據。
3. Master 的 output/tag pipeline 有活動，但目前 diagnostic mailbox 仍沒有提供歷史 `PTP=6` 的長時間證據。
4. 目前不能把問題說成「DDMTD 沒有輸出」，也不能說成「Slave SoftPLL 已經收到有效 tag」；兩者之間的 enable/grant 階段才是現在可觀察到的缺口。

## Conclusion

證據支持：

- `TAG_SOURCE` 增加不等於有效 tag。
- Slave 目前沒有證據顯示 reference channel 已 enable；`RCER=0` 是最強的直接觀測結果。
- 問題仍位於 PTP parent/SoftPLL 啟動之前或其交界處，尚不能宣稱根因已完全確定。
- 不需要、也不應該重新發明 Master role 切換方式；Master 仍沿用 `9f848ec` 的角色設定。

證據不支持：

- 兩片 DE5a 已完成 White Rabbit 同步。
- Master 已完整恢復歷史 `MODE=2 / PTP=6 / status=FF / PTP RX-TX activity` 五項 baseline。
- 只靠 `RCER=0` 就能排除 PTP parent acquisition 或 firmware startup 問題。

## Next Step

只改 Slave firmware startup command 一個變因：移除阻塞過的 startup `sfp match`，保留 `vlan off;ptp stop;mode slave;ptp start`。先 build firmware 與 Quartus compile；只有 compile 成功後才燒錄。燒錄後立即建立獨立實驗紀錄，再讀取：

```text
MODE、PTP、PTP_RX/TX、RCER、TAG_SOURCE、TAG_VALID、TRR_WRITE、IRQ、SSTAT、PSTAT
```

若 `RCER` 從 0 變成 1 且 `TAG_VALID/TRR/IRQ` 開始增加，才能把 `sfp match` 視為支持性證據；若仍為 0，下一步回到 PTP parent/firmware state，不改 Master。

# EXP-WRPC-HELPER-SATURATION-OBS-20260817：Slave SoftPLL helper 飽和唯讀觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-HELPER-SATURATION-OBS-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：唯讀 JTAG runtime 觀測；本輪沒有 compile、沒有燒錄 FPGA。

## 這次想驗證什麼

確認 Slave 的 SoftPLL 是否完全沒有收到 tag，或是已收到 tag 但 phase error/lock detector 卡在飽和值。這一步用現有 bitstream 讀取 raw register 與累積計數器，不寫入 `WDIAGS_CTRL.DATA_SNAPSHOT`，也不修改 PHY、PTP、servo、SoftPLL generic 或 SI5340 控制。

## Git、分支與工具

- 本機研究分支：`exp/jtag-runtime-observability`
- 本機 HEAD：`5322c1af22153138032700d142836d56636f8edb`
- pain checkout：detached HEAD，明確固定於 `5322c1af22153138032700d142836d56636f8edb`
- Quartus：17.0.0 Build 595（Standard Edition）
- 觀測腳本：`scripts/jtag/read_spll_diag_raw.tcl`
- 觀測腳本 SHA-256：`a1c107ba1d870bb94174834a08e0dd030a3059c25829f2d3ec69ba7b9b9c2ae5`

## 相較 baseline 唯一修改了什麼

沒有修改硬體或軟體。唯一操作變因是：在同一 JTAG session 中，對兩張板各讀取 BEGIN 與 1000 ms 後的 END raw register，觀察累積欄位是否增加。

## MIF / SOF / 燒錄結果

- 本輪沒有重新 compile，因此沒有新的 MIF。
- 本輪沒有燒錄，因此沒有新的 SOF、checksum 或 programmer 結果。
- 板上 bitstream 沿用前一輪已燒錄 image；本次不把它當成新的 image provenance。

## 執行方式與原始結果

```text
cd /home/b10504072/04_WR
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_spll_diag_raw.tcl 1000
```

原始輸出保存於 pain：

```text
build/artifacts/EXP-WRPC-HELPER-LOCK-OBS-20260817/raw_observation.log
```

原始輸出 SHA-256：

```text
97bfad2ade8e48526f417b5e135d877221291eadd0cf71500b3d906b21005c7d
```

Quartus SignalTap 腳本執行結果：`Evaluation of Tcl script successful`、`0 errors`、`0 warnings`。

### Master：`DE5 [1-11.1]`

```text
BEGIN status=F11E924127D082FF
BEGIN CTRL=00000001 SSTAT=00000000 PSTAT=00000001 PPS_ESCR=0000080C
BEGIN HELPER=00020100 ERROR=FFFDB610 OUTPUT=0000FFFB
BEGIN TAG_VALID=0103C2EE TRR_WRITE=0103C31B TAG_SOURCE=0266C172 REF=010C3CE7 FEEDBACK=015C0DF5
END   status=311E9243275082FF
END   CTRL=00000001 SSTAT=00000000 PSTAT=00000001 PPS_ESCR=0000080C
END   HELPER=00020100 ERROR=FFFDB610 OUTPUT=0000FFFB
END   TAG_VALID=0103E771 TRR_WRITE=0103E7A5 TAG_SOURCE=0267099F REF=010C6088 FEEDBACK=015C3288
```

### Slave：`DE5 [1-11.2]`

```text
BEGIN status=D31E02C1275082CF
BEGIN CTRL=00000001 SSTAT=00000001 PSTAT=00000001 PPS_ESCR=00000800
BEGIN HELPER=00020000 ERROR=000249F0 OUTPUT=00000005
BEGIN TAG_VALID=01531B86 TRR_WRITE=01121AE0 TAG_SOURCE=07D33451 REF=03E875AA FEEDBACK=042A909E
END   status=931E026137BC82CF
END   CTRL=00000001 SSTAT=00000001 PSTAT=00000001 PPS_ESCR=00000800
END   HELPER=00020000 ERROR=000249F0 OUTPUT=00000005
END   TAG_VALID=0153653E TRR_WRITE=01121A6A TAG_SOURCE=07D37E0A REF=03E89B00 FEEDBACK=042AB505
```

## Observation

1. 兩片的 raw tag、TRR write、tag source、reference 與 feedback counters 在 1 秒內增加；因此本次證據不支持「tagger 完全沒有 activity」。
2. Slave `HELPER_ERROR=0x000249F0`，解讀為 `+150000`；`HELPER_OUTPUT=5`。Master `HELPER_ERROR=0xFFFDB610`，解讀為 `-150000`；`HELPER_OUTPUT=0xFFFB`。兩端都在 helper error/output 的邊界，沒有進入 lock detector 所需的穩定小誤差區間。
3. Slave `PSTAT=0x00000001`：link bit 為 1，但 SoftPLL lock bit 為 0；`SSTAT=0x00000001`，仍未到 `TRACK_PHASE`。Slave status 的低位仍為 `0xCF`，所以不能宣稱 `time_valid=1`。
4. Master 仍為 `PSTAT=0x00000001`、status low byte `0xFF`；這表示目前這次讀值也沒有提供 Master SoftPLL lock 的證據。
5. 本輪只讀取兩個時間點，不能由此單獨證明錯誤的唯一根因；但已排除「完全沒有 raw tag 活動」這個較窄的說法。

## Register mapping 交叉核對

現行 `si5340a_controller_dco.v` runtime 序列是：先寫 page 0，再寫 `0x39`，最後寫 `0x1D`。本地 static table 則把 `REG_0339` 以 page 3 的設定寫入。

Si5340 Rev D Family Reference Manual 明確列出：

- page 0 的 `0x001D` 是 FINC/FDEC。
- page 3 的 `0x0339` 是 N divider FINC/FDEC mask。
- `0x0339[0]`、`0x0339[1]` 分別選擇 N0、N1。

因此目前 runtime 寫入 `page 0 + address 0x39` 並不是對 `0x0339` 的寫入。這是下一個值得做硬體 A/B 的具體嫌疑，但仍屬於「已確認 register map 不一致、尚未由燒錄實驗證明會造成同步失敗」。

## Conclusion

本實驗支持：

> 現有 Slave 已有 raw tag/feedback 活動，但 helper phase error 飽和，SoftPLL 尚未 lock；問題優先落在 SoftPLL lock feedback、DMTD phase/error 或 DCO/clock-actuator 路徑，而不是基本 PHY link 或「完全沒有 tag」。

本實驗不支持：

> 不能宣稱兩台 DE5a 已完成 White Rabbit 時間同步，也不能只靠這一秒的計數器判定 SI5340 DCO register mapping 已是唯一根因。

## Next Step

建立下一個單一硬體變因：只修正 SI5340 runtime page/register 序列，保持 PHY、clock mapping、SoftPLL generic、firmware 與其他 RTL 不變。預期若 DCO actuator 原先沒有真正選到 N0/N1，修正後應看到 helper error 不再長時間飽和、`HELPER_OUTPUT` 開始收斂、Slave `PSTAT.bit1` 可能轉為 1，並進一步觀察 `SSTAT=4/5` 與 `time_valid`。若 compile 成功但 runtime 證據沒有改善，再另開下一個 commit 處理 load pulse CDC，不把兩個變因混在同一個實驗。

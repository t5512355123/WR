# EXP-WRPC-CONTROL-A-20260824

## 實驗設定

- 實驗名稱：`Phase A：exact 7dd298bb fresh control regression`
- 日期：2026-08-24
- 工作 branch：`exp/step4-softpll-enable`
- Control source：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- 目前文件提交：待本次紀錄更新
- 實驗類型：Step 2 / Step 3 control revalidation

## 目的

確認歷史上通過 Step 2 / Step 3 的 exact `7dd298bb`，在目前 pain、目前兩張 DE5a、目前 JTAG/光纖環境中，重新執行 fresh firmware build、Quartus clean compile、雙板 program 後是否仍然通過。

本輪 A 不加入目前 branch 的任何 post-7dd diagnostics、DMTD debug port、Wishbone alias mapping 或 TRR POP export。這是 control，不是 Step 4 變更。

## Acceptance gate

只有以下條件全部成立，才可建立 Phase B：

```text
Master：20/20 accepted samples，MODE=2，PTP=6，RXERR stable，Step2 PASS
Slave ：20/20 accepted samples，MODE=3，PTP=9，Foreign/parent valid，
        SLAVE_PRESENT / LOCK / LOCK_ENABLE valid，RXERR stable，
        Step2 PASS，Step3 PASS
```

若 A 失敗或 invalid，停止 source isolation，不建立 B，也不進入 Step 4。

## 執行狀態

本檔案先記錄實驗設計。fresh build、program、JTAG raw output、hash、結果與結論會在本次實驗完成後補上。

## Fresh build / program provenance

- pain checkout source：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- Quartus Prime：17.0.0 Build 595 / Standard Edition
- Master MIF SHA256：`a96c40101a7617d99c50eefe8104e5c0bc6d1e1745145ff0e09583a199cb1eac`
- Slave MIF SHA256：`e5f0f1265f114bdd3d2339d50367510a3b0b102b17c217af6d43a32fc3ffba25`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`6839e02662e1511e94e8aa3f0697d709ccc3c35cdd24c642168eb8cbb636c77e`
- Slave SOF SHA256：`a7d00f4d0e3804909de92270a66b3b5702189376fce6419b86102aa69a5ecd05`
- Master programmer checksum：`0x30AA3EE5`
- Slave programmer checksum：`0x30B06A0E`
- Master / Slave Quartus compile：成功，`timing_closed=NO`

### 燒錄結果

Master 使用 `DE5 [1-11.1]`，Slave 使用 `DE5 [1-11.2]`。兩片均回報：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## Step 2 / Step 3 focused regression

燒錄後等待 60 秒，執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### Master

```text
valid_samples=20
invalid_samples=0
counter_decreased=0
PTP_TX_DELTA=65
STEP2_REGRESSION=PASS
```

Master 全部 accepted samples 維持 `MODE=2`、`PTP=6`、正確 MAC、MiniNIC/PTP counter 有活動、RXERR=0。

### Slave

```text
valid_samples=20
invalid_samples=0
counter_decreased=0
PTP_TX_DELTA=6
STEP2_REGRESSION=PASS
STEP3_REGRESSION=PASS
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 全部 accepted samples 維持：

- `MODE=3`
- `PTP=9 SLAVE`
- `FOREIGN=1/0`
- parent flags=`1/0/1`
- RX WR message=`0x1001 LOCK`
- TX WR message=`0x1000 SLAVE_PRESENT`
- `LOCK_ENABLE=4`
- `RCER=0x00000001`
- `RXERR=0`

所有 Slave sample 的 current state 仍多為 `WRS_IDLE`，focused script 因此保留 `POST_STEP3_LOCK_STAGE=TIMEOUT / STATE_EVIDENCE=READ_INCONSISTENT`。這不影響本輪既定的 Foreign、parent、WR message 與 LOCK enable acceptance gate，也不把單一 state 證據擴大解讀成 Step 2/3 failure。

## Control A 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_MEASURED
```

這是目前環境中 exact `7dd298bb` 的 fresh control 證據，不是沿用歷史 SOF。A 只證明 Step 2 / Step 3 control 可重現；本輪尚未開始 Step 4，也沒有修改任何 SoftPLL functional behavior。

## 原始證據

所有 raw build、program、hash、MIF/SOF provenance 與 focused output 均保存在：

```text
docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-CONTROL-A-20260824-*
```

## Next Step

建立 Phase B：從 exact `7dd298bb` 只加入最小 firmware-side `wrpc_spll_trr_pop_count`，在成功執行 `SPLL->TRR_R0` 後遞增，並透過一個 dedicated read-only export 暴露。不得帶入其他 post-7dd DMTD、deglitch、WB alias 或額外 diagnostics mapping；B fresh build/program 後只重跑相同 Step 2/3 gate，先停下來 review，再決定是否進 Step 4。

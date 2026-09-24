# EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829

## 實驗目的與唯一變更

修正上一輪已由 source audit 確認的 read-only reader 語意問題，並重新以
fresh JTAG image 驗證 Step4B：

- `SPLL_STATE` 保持十六進位文字後再取欄位，避免 Tcl decimal/hex 雙重解析。
- `OCER` 只判定 source-defined `OCER[7:0]`；上半部的 live diagnostic alias
  不再被誤當成必須為零，也不再要求 full-word stable-read。
- focused Step2 regression 對 `PTP` 比較 source-defined low byte。

本輪未修改 SoftPLL、DMTD、WR signaling、PTP、PHY、SI5340、reset tree 或
任何 functional RTL。工作 branch 為 `exp/step4b-slave-softpll-startup`。

## Provenance

- pain source commit：`1199676b2e0cad953b88df302564e12b238abe6c`
- Quartus：17.0.0 Build 595 / Standard Edition
- Master/Slave full compile：successful；timing closed：`NO`
- Master worst setup slack：`-0.177 ns`
- Slave worst setup slack：`-0.272 ns`
- Master MIF SHA256：`07cb35aa0a437e5f5eaf759d564c6b48ddd45c4ff2cba48dc39bef5e471dc47a`
- Slave MIF SHA256：`75227de265c1996e83e8762f585103ccbb5305aff30c2122c2c9a6a40e3ac9ec`
- Master SOF SHA256：`68cddbde9573382631083dff6094e9daaf3ac1bfa4a40b76cb27df9359c7c997`
- Slave SOF SHA256：`1984eb9c843d501ad80e443ea861d291a6dc133c2c376ec151114efc401a1140`
- 兩張 DE5a 均以 JTAG ID `0x02E660DD` program 成功，0 errors / 0 warnings。
- Master checksum：`0x30B00EC4`；Slave checksum：`0x30B7AD8B`。

完整 build/program provenance 在本實驗 raw 目錄。

## Regression gate

`read_step23_register_reliability.tcl 20 500 step2 25 --raw` 結果：

```text
STEP2_INDEPENDENT board=DE5 [1-11.1] result=PASS
STEP2_INDEPENDENT board=DE5 [1-11.2] result=PASS
```

兩板 endpoint/MAC、PTP mode/state、PTP activity、MiniNIC activity 均有效，
RXERR 維持 0。

## 最終 dashboard 結果

```text
Master Step1 = PASS
Master Step2 = PASS
Master Step4A = PASS

Slave Step1 = PASS
Slave Step2 = PASS
Slave Step3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

Master 的 Step4A 也維持 PASS，沒有因為 reader 修正而退化。

## Slave Step4B acceptance evidence

同一個 before/after fixed observation window：

### Startup

```text
LOCK_ENABLE_COUNT = 4
SPLL_MODE = 3 (SPLL_MODE_SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
SPLL_ALIGN_STATE = 0
SPLL_STATE_VISIT_MASK = 0x00000618
SPLL_INIT_COUNT = 4
SPLL_STATE_TRANSITIONS = 0x00000003
SPLL_LAST_STATE = 4 (SEQ_WAIT_HELPER)
RCER = 0x00000001
OCER = 0x1E9EF801  (functional OCER[7:0] = 0x01)
```

這直接證明 Slave 已經由 WR lock handoff 進入 `locking_enable()`、
`spll_init(SPLL_MODE_SLAVE, ...)`，並且 sequencer 已離開 disabled/reset。

### Event processing

```text
ΔDMTD_ACCEPT = 43567
ΔTAG_VALID = 43568
ΔTRR_WRITE = 43567
ΔTRR_POP = 40280
ΔIRQ = 39549
ΔHELPER_UPDATE = 20280
```

六個 downstream event counter 全部為正，第一個 inactive boundary 為
`ACTIVE`。

### Reset/re-entry guard

```text
ΔBOOT_GENERATION = 0
ΔCPU_RESET_COUNT = 0
ΔWR_CORE_RESET_COUNT = 0
ΔSI_CONFIG_DROP_COUNT = 0
```

沒有觀察到 reset/re-entry。

## Step 4B 判定

本輪正式判定：

```text
STEP4B_SLAVE_SOFTPLL_STARTUP = PASS
```

這個 PASS 僅涵蓋 Step4B 所定義的 upstream、SoftPLL startup 與 event
processing；不要求 `PSTAT.locked`、helper/main lock 或 frequency/phase
convergence。dashboard 顯示的 Step5 `PSTAT.locked=0` 是下一階段 Step5，
不會否定 Step4B。

## Raw evidence

- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/dashboard-raw.log`
- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/step23-jtag-step2-raw.log`
- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/program-jtag-master.log`
- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/program-jtag-slave.log`
- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/build_info_jtag_master.txt`
- `raw/EXP-WRPC-STEP4B-READER-SEMANTICS-FIX-20260829/build_info_jtag_slave.txt`

本輪結果已足以詢問分支4是否同意將 `exp/step4b-slave-softpll-startup`
merge 到 `main`；在取得明確同意前不合併。

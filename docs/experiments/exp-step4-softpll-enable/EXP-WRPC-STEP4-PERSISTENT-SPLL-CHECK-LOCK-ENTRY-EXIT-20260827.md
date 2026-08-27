# EXP-WRPC-STEP4-PERSISTENT-SPLL-CHECK-LOCK-ENTRY-EXIT-20260827

## 結論

本輪依分支 2 指定的單一步驟，加入 `spll_check_lock(0)` 的唯讀持久化 boundary marker，完成 Master/Slave 新版建置與燒錄，並執行一次 Master `mode master` 注入、110 筆取樣（約 35 秒）及 post-capture 讀取。

本輪未達到可判讀 `spll_check_lock()` 的 transition 條件：Master 在燒錄後仍停留於 boot-init command index 2（`ptp stop`），`MODE_MASTER_CALL_COUNT=0`、`MODE_MASTER_RETURN_COUNT=0`。唯一一次 `mode master` 的 12 bytes 確實送入 JTAG VUART，但 Master 未進入可觀察的 mode-master stage。

因此本輪的正式分類為：

```text
ROOT_CAUSE=NOT_PROVEN
EXPERIMENT_VALID_FOR_SPLL_CHECK_LOCK_FORENSICS=NO
```

這不是 `spll_check_lock()` 未被呼叫的證明，而是前置條件未成立；新 marker 全程為零，與未進入 persistent mode-master stage 一致。

## 觀測設計

本輪只在 `spll_check_lock()` 加入讀取邊界的唯讀診斷呼叫，未修改其功能結果、SoftPLL 演算法、timer、timeout、IRQ/fault、DMTD、DCO、reset、PTP 或 PHY 行為。

marker 定義如下：

| 值 | 邊界 |
|---:|---|
| 0 | 未進入 |
| 1 | 呼叫前 |
| 2 | 函式已進入 |
| 3 | 讀取 `seq_state` 後 |
| 4 | return 前 |
| 5 | 已返回、caller 恢復 |

持久化 mirror 放在直接唯讀 WDIAGS offsets `0x190..0x19c`，對應 CPU addresses `0x00100B90..0x00100B9C`：

```text
0x190 PERSIST_SPLL_CHECK_LOCK_STAGE
0x194 PERSIST_SPLL_CHECK_LOCK_CHANNEL
0x198 PERSIST_SPLL_CHECK_LOCK_STATE
0x19c PERSIST_SPLL_CHECK_LOCK_BOOT_GENERATION
```

marker 只在 persistent mode-master stage 4 且 generation 仍相符時更新，避免 re-entry 後被後續呼叫覆寫。

## 實驗結果

### Master（DE5 [1-11.1]）

- 新版程式燒錄成功；programmer checksum `0x30B37E9B`，JTAG ID `0x02E660DD`。
- 基線及 post-capture boot-init 均為 `PTP_STATE=3`、`BOOT_INIT_COMMAND_INDEX=2`、`MODE_MASTER_CALL_COUNT=0`、`MODE_MASTER_RETURN_COUNT=0`。
- sample 005 注入一次 `mode master\n`；12 bytes 皆有 Wishbone 完成回覆，最後一個 byte 的 `WB_RESULT=00000100`。
- sample 001、005、006、110 均為 `BOOT_GENERATION=00000002`。
- 110 筆樣本中 `PERSIST_MODE_MASTER_STAGE=0`、`PERSIST_LOCK_WAIT_SUBSTAGE=0`，新 marker 的 stage/channel/state/boot-generation 也全為 0。
- `PERSIST_MAGIC=504D5354` 保持有效；沒有留下可用的 `spll_check_lock()` boundary evidence。

### Slave（DE5 [1-11.2]）

- 新版程式燒錄成功；programmer checksum `0x30B4455C`，JTAG ID `0x02E660DD`。
- 本輪未注入命令。
- 110 筆樣本的 `BOOT_GENERATION=00000002`，persistent mode stage、lock-wait substage 及新 marker 均保持 0。

### 建置與時序

Master 與 Slave full Quartus build 均成功，但 timing closure 仍為 `NO`：

```text
Master setup=-0.383  hold=+0.038
Slave  setup=-0.307  hold=+0.038
```

本輪 source/repo HEAD：`07ceff8e4f7a2660496ffeea2b4fafc765b0e1f6`。

## 判讀與下一步邊界

這次資料先排除了「已進入 persistent mode-master stage，但 `spll_check_lock()` boundary 沒留下 marker」的判讀，因為 boot-init sticky trace 同時顯示 Master 尚未呼叫 `mode master` setter。它不能排除更早的 boot-init `ptp stop` 問題，也不能判定 `spll_check_lock()` 的函式內部原因。

依實驗規則，本輪在報告與 raw 完成後停止，不再加入第二個功能變因。

## Raw evidence

完整 raw logs、baseline/post capture、artifact hashes、timing summary 與檔案 inventory 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PERSISTENT-SPLL-CHECK-LOCK-ENTRY-EXIT-20260827/`


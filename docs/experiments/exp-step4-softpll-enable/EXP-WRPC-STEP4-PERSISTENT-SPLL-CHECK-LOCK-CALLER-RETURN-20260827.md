# EXP-WRPC-STEP4-PERSISTENT-SPLL-CHECK-LOCK-CALLER-RETURN-20260827

## 結論

本輪依分支 2 最新指示，在已證明 C9 的 command path 上，將 `spll_check_lock()` 的 S5 marker 嚴格放到 caller 的 `last_lock_result = spll_check_lock(0)` 之後，完成 Master/Slave 新版建置與燒錄，執行一次 Master `mode master\n` 注入、110 筆取樣（約 27 秒），並完成 post-capture 讀取。

本輪證明：

- command path 仍完整到達 C9（`wrc_ptp_set_mode(MASTER)` 已進入）。
- `spll_check_lock(0)` 已完成 S1→S4；S3 的 lock/sequence state read 已完成，S4 的 before-return marker 已寫入。
- 嚴格定義的 S5（caller regain control）沒有出現；lock-wait persistent substage 也停在 1，沒有到達 after-lock-check 的 substage 2。

因此本輪分類為：

```text
MANUAL_MODE_MASTER_PRECONDITION=PROVEN
SPLL_CHECK_LOCK_ENTRY_TO_BEFORE_RETURN=PROVEN
SPLL_CHECK_LOCK_CALLER_REGAINED=S5_NOT_REACHED
BOUNDARY=SPLL_CHECK_LOCK_RETURN_PATH_OR_CALLER_HANDOFF
ROOT_CAUSE=NOT_PROVEN
```

這不是 `spll_check_lock()` 內部 lock-state read 失敗的證明；目前最窄的未跨越 boundary 是 S4 之後到 caller-side S5／lock-wait substage 2 之間。

## 觀測設計

本輪只調整 persistent/read-only observability：

- `spll_check_lock()` 內保留 S1、S2、S3、S4。
- S5 移到 `wrpc_spll_check_lock_with_timeout()` 中，緊接 `last_lock_result = spll_check_lock(0)` 之後，代表 caller 已取得控制。
- persistent marker 以單調 S1→S5 claim 更新，不再以 boot-generation 相等作為 gate，避免 re-entry 將 boundary evidence 擋掉。
- S5 不覆寫 S4 已保存的 lock/sequence state value。

未修改 VUART、shell parser、`wrc_ptp_set_mode()`、`spll_check_lock()` 的功能判定、SoftPLL algorithm、`spll_update()`、timer/timeout、IRQ/fault、DMTD、DCO、reset、PTP 或 PHY 行為。

marker 定義如下：

| 值 | 邊界 |
|---:|---|
| S0 / 0 | 未進入 |
| S1 / 1 | caller 即將呼叫 `spll_check_lock(0)` |
| S2 / 2 | `spll_check_lock()` 已進入 |
| S3 / 3 | lock/`seq_state` read 已完成 |
| S4 / 4 | 函式內即將 return |
| S5 / 5 | caller 已取得 return control |

## 實驗結果

### Master（DE5 [1-11.1]）

- 新版程式燒錄成功；programmer checksum `0x30B37E9B`，JTAG ID `0x02E660DD`。
- baseline 仍顯示 `BOOT_INIT_COMMAND_INDEX=2`、`MODE_MASTER_CALL_COUNT=0`；這是既有 boot-init 背景問題，未在本輪修改。
- sample 005 唯一注入一次 `mode master\n`；12 bytes 皆有 Wishbone completion，newline 的 `WB_RESULT=00000100`。
- sample 006 已有完整 command evidence：

```text
BOOT_GENERATION=00000003
PERSIST_CMD_STAGE=00000009
PERSIST_CMD_RX_BYTE_COUNT=0000000C
PERSIST_MODE_MASTER_STAGE=00000004
PERSIST_LOCK_WAIT_SUBSTAGE=00000001
```

- sample 009 起 persistent SPLL evidence 為：

```text
BOOT_GENERATION=00000003
PERSIST_SPLL_CHECK_LOCK_STAGE=00000004
PERSIST_SPLL_CHECK_LOCK_CHANNEL=00000000
PERSIST_SPLL_CHECK_LOCK_STATE=00000000
PERSIST_SPLL_CHECK_LOCK_BOOT_GENERATION=00000003
PERSIST_LOCK_WAIT_SUBSTAGE=00000001
```

- 110 筆樣本中未出現 `PERSIST_SPLL_CHECK_LOCK_STAGE=00000005`；因此不能宣告 caller-side S5 已完成。
- `PERSIST_MODE_MASTER_STAGE=4` 的 generation-at-stage 為 2，而 SPLL S4 的 generation 為 3，表示 command/mode trace 之後確實發生 generation transition；這與 re-entry 發生在 mode-master 路徑附近一致，但仍不足以判定 root cause。
- command RX count 在 sample 009 後變為 13；不影響 12-byte command 已完成 C9 的判定。

### Slave（DE5 [1-11.2]）

- 新版程式燒錄成功；programmer checksum `0x30B4455C`，JTAG ID `0x02E660DD`。
- 本輪未注入 command；command 與 SPLL persistent markers 全程沒有形成 Master 以外的有效 trace。

### 建置與時序

Master 與 Slave full Quartus build 均成功，但 timing closure 仍為 `NO`：

```text
Master setup=-0.383  hold=+0.038
Slave  setup=-0.307  hold=+0.038
```

capture source/repo HEAD：`0379513`。

## 判讀與下一步邊界

本輪已排除「command 沒有到達 mode setter」與「`spll_check_lock()` 尚未開始讀 lock/sequence state」這兩種判讀：C9、S1、S2、S3、S4 都有 persistent evidence。

目前不能把 S5 缺失單獨解讀成 `spll_check_lock()` 功能錯誤。它只表示從 S4 marker 寫入後，到 caller-side S5／lock-wait substage 2 之間沒有留下後續 evidence；下一步應由分支 2 決定是否繼續縮小這個 return/caller handoff，或檢查 re-entry trigger。`ROOT_CAUSE` 維持 `NOT_PROVEN`。

## Raw evidence

完整 raw logs、baseline/post capture、artifact hashes、programmer summary、timing summary 與檔案 inventory 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PERSISTENT-SPLL-CHECK-LOCK-CALLER-RETURN-20260827/`

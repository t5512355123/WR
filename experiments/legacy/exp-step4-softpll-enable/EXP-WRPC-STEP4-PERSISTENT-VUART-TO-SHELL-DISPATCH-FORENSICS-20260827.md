# EXP-WRPC-STEP4-PERSISTENT-VUART-TO-SHELL-DISPATCH-FORENSICS-20260827

## 結論

本輪依分支 2 指定的單一步驟，加入 VUART 接收與 shell dispatch 的持久化 C0–C9 boundary marker，完成 Master/Slave 新版建置與燒錄，執行一次 Master `mode master\n` 注入、110 筆取樣（約 27 秒），並完成 post-capture 讀取。

本輪正式證明手動 `mode master` 的 dispatch 前置條件：Master 的 12 bytes 由 JTAG VUART 送入後，持久化 marker 從 C1 依序進展至 C9；C9 代表 `wrc_ptp_set_mode(MASTER)` 已進入。因此後續才允許進行 `spll_check_lock()` boundary forensics。

本輪分類：

```text
MANUAL_MODE_MASTER_PRECONDITION=PROVEN
PERSISTENT_VUART_TO_SHELL_DISPATCH=PROVEN
ROOT_CAUSE=NOT_PROVEN
```

`ROOT_CAUSE` 仍未判定；本輪只證明 command dispatch 已到達 mode setter，不對 SoftPLL、lock wait 或 timing failure 做因果結論。

## 觀測設計

本輪只加入非功能性、持久化的接收與 dispatch marker，未修改 VUART 功能語意、shell parser 語意、`wrc_ptp_set_mode()`、SoftPLL、`spll_check_lock()`、timeout/timer、IRQ/fault、DMTD、DCO、reset、PTP 或 PHY 行為。

marker 定義如下：

| 值 | 邊界 |
|---:|---|
| C0 / 0 | 沒有 command evidence |
| C1 / 1 | 韌體收到 VUART 第一個 byte |
| C2 / 2 | 收到完整 12 bytes |
| C3 / 3 | 收到 newline |
| C4 / 4 | shell line ready |
| C5 / 5 | command lookup 命中 `mode` |
| C6 / 6 | mode handler 進入 |
| C7 / 7 | 解析到 `master` argument |
| C8 / 8 | 即將呼叫 `wrc_ptp_set_mode(MASTER)` |
| C9 / 9 | `wrc_ptp_set_mode(MASTER)` 已進入 |

持久化 WDIAGS mirror 位於 `0x1a0..0x1b4`，CPU readback 位址為 `0x00100BA0..0x00100BB4`：

```text
0x1a0 PERSIST_CMD_STAGE
0x1a4 PERSIST_CMD_RX_BYTE_COUNT
0x1a8 PERSIST_CMD_LAST_BYTE
0x1ac PERSIST_CMD_LENGTH
0x1b0 PERSIST_CMD_HASH
0x1b4 PERSIST_CMD_BOOT_GENERATION
```

## 實驗結果

### Master（DE5 [1-11.1]）

- 新版程式燒錄成功；programmer checksum `0x30B37E9B`，JTAG ID `0x02E660DD`。
- baseline 與 post-capture 的 boot-init 都顯示 `BOOT_INIT_COMMAND_INDEX=2`、`MODE_MASTER_CALL_COUNT=0`；這個 boot-init 狀態仍是未解決的背景問題。
- sample 005 唯一注入一次 `mode master\n`；12 bytes 皆有 Wishbone completion，最後一個 newline 的 `WB_RESULT=00000100`。
- sample 006 已讀到：

```text
BOOT_GENERATION=00000003
PERSIST_CMD_STAGE=00000009
PERSIST_CMD_RX_BYTE_COUNT=0000000C
PERSIST_CMD_LAST_BYTE=0000000A
PERSIST_CMD_LENGTH=0000000C
PERSIST_CMD_HASH=27C748C2
PERSIST_CMD_BOOT_GENERATION=00000002
```

- C9 是單調、連續 C0–C9 trace 的最後一階段，因此 C1–C8 也已依序通過。同期 persistent mode trace 為 stage 4，history 為 `1,2,3,4`，lock-wait substage 為 1。
- 後續樣本仍保持 `PERSIST_CMD_STAGE=9`。sample 009 之後 RX count 變為 13，代表在原本 12-byte command 後還有一個額外接收 byte；不影響 C9 已成立的判定。
- current `BOOT_GENERATION` 從 command trace 的 2 進入 3，但 command marker 保留 generation 2；這與 marker 在 re-entry 後仍可讀取的設計一致。

### Slave（DE5 [1-11.2]）

- 新版程式燒錄成功；programmer checksum `0x30B4455C`，JTAG ID `0x02E660DD`。
- 本輪未注入 command；Slave 的 command marker 全程為 0。

### 建置與時序

Master 與 Slave full Quartus build 均成功，但 timing closure 仍為 `NO`：

```text
Master setup=-0.383  hold=+0.038
Slave  setup=-0.307  hold=+0.038
```

source/repo HEAD：`f0e5cb3662d470dfd497b650ef64c9b9be94fab6`。

## 判讀與下一步邊界

本輪已滿足分支 2 設定的 gate：手動 `mode master` 的 firmware VUART RX、newline、shell line ready、command lookup、handler、argument parse、setter call boundary 均有持久化 evidence，並以 C9 證明 `wrc_ptp_set_mode(MASTER)` 已進入。

因此下一輪可依分支 2 指示進行 `spll_check_lock()` 的單一 boundary experiment；本輪不自行加入第二個功能變因，也不把目前資料解讀成 SoftPLL root cause。

## Raw evidence

完整 raw logs、baseline/post capture、artifact hashes、programmer summary、timing summary 與檔案 inventory 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PERSISTENT-VUART-TO-SHELL-DISPATCH-FORENSICS-20260827/`

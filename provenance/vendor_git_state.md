# Vendored dependency provenance（外部依賴來源追溯）

本文件記錄遷移期間在 `pain` 找到的 dependency 狀態。工作 tree 複製進本 repository 時未包含內層 `.git` 資料夾，讓最上層 repository 管理這份實驗 snapshot。

## `vendor/wr-cores`

- 原始路徑：`/home/b10504072/04_White_Rabbit/week02/v01/vendor/wr-cores`
- Remote：`https://gitlab.com/ohwr/project/wr-cores.git`
- HEAD：`0f8fbced87988254f5c9ca55c0e04585b29b485c`
- Inventory 時的狀態：detached HEAD，`ep_tx_framer.vhd` 與 `wrc_urv_wrapper.vhd` 有修改

## `vendor/wrpc-sw`

- 原始路徑：`/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw`
- Remote：`https://gitlab.com/ohwr/project/wrpc-sw.git`
- HEAD：`4528c0faa64138a6c97f15f7df373ff`
- Inventory 時的狀態：detached HEAD，Makefile 與 `dev/pps_gen.c` 有修改，另包含既有的 `ppsi` submodule 狀態與本機建置/設定檔

## `vendor/wrpc-sw_nosfpmatch_diag`

- 原始路徑：`/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw_nosfpmatch_diag`
- HEAD：`4528c0faa64138a6c97f15e6b911090f7df373ff`
- 保留為歷史除錯 snapshot，不是正式 build input。

修改過的 vendor 內容是刻意保留的。遷移期間不清理或 reset，因為它們可能是歷史 bitstream provenance 的一部分。

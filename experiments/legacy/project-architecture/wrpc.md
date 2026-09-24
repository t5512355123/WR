# WRPC 與韌體

嵌入式 WRPC 韌體以 vendored 的 `vendor/wrpc-sw` 原始碼建置，DE5a Master 與 Slave 設定位於 `firmware/configs/`。產生的 MIF 屬於建置產物，會在 Quartus 編譯前暫存於 `build/firmware/`。

基準版本的 Master 與 Slave MIF 保留在 pain 的 `/home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/`；對應的 SHA256 值記錄在實驗 metadata 中。這些大型建置產物不放在 GitHub 原始碼 repository。

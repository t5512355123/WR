# DE5a Bring-up

請先使用已知的基準版本產物。依照實驗 metadata 所記錄的精確 SOF，分別燒錄 Master 與 Slave；等待設定完成後，再讀取 status probe。不能只因為 `link_ok` 為 1，就宣稱 WR 時間同步成功。

# 問題排查

1. 先確認 cable 與裝置燒錄狀態。
2. 記錄精確的 SOF checksum 與 Git commit。
3. 使用 `probe_bits.md` 解碼 status vector。
4. 將 link 證據與 WRPC 執行期證據分開判讀。
5. 重新建置前先檢查 MIF、QSF 與 SDC hash。
6. 修改除錯變數前，先保留完整 log 與 artifact set。

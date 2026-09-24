# JTAG

JTAG 燒錄使用兩條 DE5 cable：

- Master: `DE5 [1-11.1]`
- Slave: `DE5 [1-11.2]`

JTAG Wishbone mailbox script 僅屬於特定除錯版本；使用前必須先確認目前燒錄的 bitstream 內含相容的 instance。RS422 基準版本不包含 mailbox instance。

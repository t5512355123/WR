# JTAG Wishbone Mailbox

mailbox 是實驗專用的除錯 bridge。`scripts/jtag/read_wb.tcl` 從相容的除錯來源複製而來，只有在確認已燒錄的 SOF 包含相同 source/probe instance 後才能執行。

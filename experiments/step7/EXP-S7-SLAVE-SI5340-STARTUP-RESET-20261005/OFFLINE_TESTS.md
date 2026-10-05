# 離線測試

Laptop：2026-10-05，Python bundled runtime。

執行 `python -m unittest scripts.tests.test_step7_startup_reset scripts.tests.test_editable_current_workflow scripts.tests.test_step6_helper_passive`：20 tests，18.716 秒，全部 OK。

- startup timing reference model：reset 邊界、釋放順序、飽和停止、板上 reset 後重新執行。
- source/wiring guards：獨立 50 MHz、FPGA 初始值、Slave SI5340 pin/controller 正確接線；Master 與 3388/64 參數不變。
- editable 四步流程與無 SHA acceptance gate；Step7 log 分類、非法分類拒絕。
- passive Helper observer 保留單字與多字一致性區別。

此結果是 reference-model/structural/wrapper tests，不是假稱 HDL waveform simulation。本機與 Pain PATH 無 ghdl/iverilog；實際 VHDL integration 由下一步 fresh Quartus compilation 確認。

`git diff --check` 通過。唯讀 milestone 與 archive 未修改。

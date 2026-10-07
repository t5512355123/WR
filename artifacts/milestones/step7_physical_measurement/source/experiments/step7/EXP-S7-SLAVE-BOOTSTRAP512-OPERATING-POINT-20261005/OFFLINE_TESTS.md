# Candidate 離線核查

`python -m unittest scripts.tests.test_step7_startup_reset scripts.tests.test_editable_current_workflow scripts.tests.test_step6_helper_passive`：20 tests，全數 OK。

舊 reset timing reference model 僅驗證已歸檔 diagnostic，active Slave 已確認不包含此 entity、RSTb/controller reset 均回 CPU_RESET_n。Active coarse=512、code-per-step=64；Master startup 未改。

相對 `origin/main`，production diff 僅 Slave coarse-step generic 與其註解。QSF、firmware、Master、SI5340 controller RTL 未改。

wrapper / Step7 log group / 非法 group 拒絕 / passive reader tests 通過，`git diff --check` 通過。並非 HDL simulation。

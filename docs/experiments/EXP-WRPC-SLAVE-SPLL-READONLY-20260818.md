# 實驗紀錄：Slave SoftPLL 與 DCO 唯讀診斷

## 實驗資訊

- Experiment ID：`EXP-WRPC-SLAVE-SPLL-READONLY-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only read-only runtime observation
- Git branch：`exp/master-9f-observability`
- 實驗前紀錄 commit：`c67c69b`
- Quartus：Quartus Prime 17.0 Build 595

## 這次想驗證什麼

上一輪已證明 Slave 收到 Master `LOCK` 並進入 `WRS_S_LOCK`，但 `PSTAT.locked=0`、`time_valid=0`。本輪不改硬體與 firmware，只確認：

1. SoftPLL state、servo counter、CKO/SETP 是否持續更新。
2. DMTD tag/TRR raw counter 是否持續更新。
3. DCO transaction 是否有完成步數、busy/error 或 load activity。
4. helper error 是否與 DCO step 或 SoftPLL activity 有可觀察關聯。

## 相較 baseline 的唯一變因

- 沒有燒錄、沒有修改 source、沒有修改 Master/Slave role、PHY、PPS、DCO 或 SoftPLL 控制設定。
- 只增加唯讀觀測腳本的執行，不寫入 `WDIAGS_CTRL.DATA_SNAPSHOT` 或任何控制 register。

## 使用中的硬體產物

- Master：歷史 `9f848ec` frozen SOF；SHA-256 `383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Slave：歷史 lock-path SOF；SHA-256 `6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- Slave MIF：SHA-256 `9c68ac6938dcfc4cd269b3df514b04e1b8edd66fde4f7eddbc8a3e1031e59572`

## 預定觀測

- `read_spll_diag_raw.tcl 1000`
- `read_dco_state.tcl 1000`
- `read_dco_activity.tcl 1000`
- `read_hpll_helper_correlation.tcl 10 1000`

所有 raw output 與 SHA-256 於執行後補入；本紀錄只會把「觀察到的活動」與「真正的 lock evidence」分開描述。

## 燒錄結果

本輪沒有燒錄，因此沒有新的 SOF checksum 或 programmer result。

## JTAG/runtime 原始結果

待唯讀診斷完成後補入。

## Observation

待唯讀診斷完成後補入。

## Conclusion

在唯讀診斷完成前，不對 SoftPLL 根因下結論，也不宣稱同步成功。

## Next Step

依 raw counters 與 lock detector 的證據，只選一個後續變因；Master 維持 frozen，不重新設計 Master role。

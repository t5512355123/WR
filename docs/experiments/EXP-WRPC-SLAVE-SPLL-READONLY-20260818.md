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

- 執行時間：2026-08-18 04:38:40 至 04:38:41（Asia/Taipei）
- `read_spll_diag_raw.tcl 1000`：exit 0；raw log SHA-256 `4e7e4b3041db0890b0953169afcc57296979dd1c576e604200b835885d5e5f6b`
- `read_dco_state.tcl 1000`：exit 0，但兩張板都回報 `No In-System Sources and Probes instance was found`；raw log SHA-256 `c16b8ffd367600648cab6956afec3149620c9314aa38e0382480abb19abfdfd0`
- `read_dco_activity.tcl 1000`：exit 0，但兩張板都回報 `No In-System Sources and Probes instance was found`；raw log SHA-256 `3c9e21ebe72ab9a89e45ffa0c02e00c25cb836848e66adfe88ff816579cb9514`
- `read_hpll_helper_correlation.tcl 10 1000`：exit 0，但兩張板都回報 `No In-System Sources and Probes instance was found`；raw log SHA-256 `b4b69fc6579e15adb7fb425f69a70c66baab7558d08862dcab24ea2c75b13f70`
- 以上 raw log 位於 `/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-SPLL-READONLY-20260818/`

### `read_spll_diag_raw.tcl` 的主要讀值

第一組為 Master、第二組為 Slave；本輪重點是 Slave 的 raw lock/feedback counters：

```text
Slave RAW_CORE:    SSTAT=00000001 PSTAT=00000001 PPS_ESCR=04423400
Slave RAW_LOCK:    RESULT=00000001 UNLOCKED=000D7BF0 HELPER=00000000 MAIN=00000000
Slave RAW_HW:      RCER=00000001 OCER=001CE001 TRR_CSR=001EE244
Slave RAW_COUNTER: TAG_VALID=005FE2A2 TRR_WRITE=005FE2FE TAG_SOURCE=0743E193 REF=03EE2BFE FEEDBACK=039F861F
Slave SHADOW:       REF=002ADE25 TAG=0029CADF TAG_VALID=005FC957 TRR_WRITE=005FC957
Slave RAW_STATE:    VISIT=00000618 TRANSITIONS=00000003 LAST_STATE=00000004
```

對照兩次讀取，Slave 的 `TAG_VALID/TRR_WRITE/TAG_SOURCE/REF/FEEDBACK` 都有變化，代表 runtime feedback path 仍有活動；但 `PSTAT=1` 的 raw locked bit 並未變成已鎖定證據，且上一輪已確認 `spll_locked=0`。

DCO/HPLL 三個腳本的原始錯誤：

```text
error: ERROR: No In-System Sources and Probes instance was found.
```

因此本輪不能從 DCO probe 判斷 SI5340 transaction 是否完成；只能確認這些探針不存在於目前歷史 Slave SOF。

## Observation

1. Slave 的 raw DMTD/tag/TRR、reference 與 feedback counters 持續增加，支持 SoftPLL runtime 有資料流與計算活動。
2. `WR_LOCK RESULT=1` 代表 lock routine 已被啟用/走過，不等同 `spll_locked=1`；`UNLOCKED=0x000D7BF0` 與上一輪的 `polls=883696` 一致支持 lock detector 長時間未接受鎖定。
3. 目前沒有足夠證據判斷是 SI5340 DCO 沒有動、DMTD feedback 數值不合格、lock threshold 不合適，或是恢復的舊 SOF 根本沒有 DCO/JTAG observability；不能把其中任何一項寫成已證明根因。
4. DCO/HPLL scripts 的 exit 0 只是 Tcl 外層成功處理錯誤，不代表取得有效資料；實際結果是兩張板都缺少該 probe instance。

## Conclusion

本輪沒有改變硬體，也沒有完成同步。證據支持的結論是：Slave 已進入 lock path，且 DMTD/feedback 相關 counters 有活動，但 lock detector 長時間仍未鎖定；目前仍缺少可直接觀察 DCO transaction 的硬體探針，因此 SoftPLL 到 clock actuator 的最後一段尚不能分辨。

## Next Step

1. Master 維持 `9f848ec` frozen，不重新設計 Master role。
2. 先做 source-level audit，對照歷史 lock-path image 與目前 branch 的 DCO/SoftPLL runtime wiring、instance index 與 MIF 內容，確認是否能在不改功能的前提下建立一個包含必要 DCO probe 的 Slave diagnostic image。
3. 若需要重新編譯，只能改 Slave 且只增加一組 DCO observability；先 compile、保存 provenance，再決定是否燒錄。燒錄前建立新的 Experiment ID，燒錄後立即補 checksum/programmer log。
4. 在新的 diagnostic image 上，重跑本紀錄的唯讀腳本；只要看到 `spll_locked=1`、`time_valid=1`、`pps_valid=1`，再進行長時間兩板同步驗證。

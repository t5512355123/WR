# 實驗紀錄：Step 4 tags_p / tags_req 事件鏈診斷

## 1. 實驗基本資料

- **Experiment ID**：EXP-WRPC-STEP4-TAG-GATE-20260820
- **日期**：2026-08-20（Asia/Taipei）
- **Git branch**：`exp/step4-softpll-enable`
- **Git HEAD**：`5400074928104205d857e196dfbb221723592670`
- **Git commit**：`5400074 診斷：加入 tags_p 與 tags_req 同週期觀測`
- **實驗名稱**：Step 4 SoftPLL Enable：tags_p、RCER/OCER 與 tags_req 同週期事件鏈診斷

## 2. 這次想驗證什麼

本次實驗要確認 Slave 已進入 `WRS_S_LOCK` 後，SoftPLL enable 路徑是否真的把
DDMTD tag 事件送入 tagger，並進一步形成 TRR 寫入、helper 更新與主迴路修正。

觀測鏈為：

```text
locking_enable()
    -> SoftPLL slave channel enabled
    -> tags_p 與 RCER/OCER 同週期成立
    -> tags_req 設定
    -> TAG_VALID / TRR_WRITE
    -> helper update
    -> main correction / DCO request
```

本階段不以 `PSTAT.locked=1` 作為 gate；SoftPLL lock 與閉迴路收斂屬於 Step 5。

## 3. 相較 baseline 唯一修改

本次只加入唯讀診斷，不改變 White Rabbit functional behavior：

- 在 `wr_softpll_ng.vhd` 增加 `tags_p` 與 `RCER/OCER` 同一 `clk_sys` 週期的事件計數器。
- 增加 ref/feedback 事件計數與最後事件 tick。
- 在 `spll_wb_slave.vhd` 與 `spll_wbgen2_pkg.vhd` 增加唯讀 Wishbone register。
- 更新 `read_step4_event_chain.tcl` 與 `read_hpll_helper_correlation.tcl` 顯示欄位。

本次沒有修改 DDMTD polarity、SoftPLL PI gain、lock threshold、DCO gain、SI5340 DCO
control algorithm、PHY、PTP、WR signaling 或 `locking_enable()` 控制流程。

新增診斷位址：

| 位址 | 說明 |
|---|---|
| `0x001002E0` | ref `tags_p & RCER` 事件數 |
| `0x001002E4` | feedback `tags_p & OCER` 事件數 |
| `0x001002E8` | ref req-set 事件數 |
| `0x001002EC` | feedback req-set 事件數 |
| `0x001002F0` | ref 事件最後 tick |
| `0x001002F4` | feedback 事件最後 tick |
| `0x001002F8` | ref req-set 最後 tick |
| `0x001002FC` | feedback req-set 最後 tick |

## 4. Build provenance

所有檔案均由上述 exact HEAD 在 pain 重新產生；本次驗證沒有使用 historical SOF。

| 項目 | Master SHA256 | Slave SHA256 |
|---|---|---|
| Firmware MIF | `c6b312581d662dfd9861d7c71d7215f9d6c27b17915f2d461c1b04f425280312` | `557bfd5564777a610b62f47d3583958f199026da944e0b5a462d75587d48f39f` |
| QSF | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF | `d7da711bf5d302bc55df92941281450842ce39858a1150041856da9ba90b379c` | `4bdb11f19815cf4d99b4f7f04242ca3f977b57dc6325ed1e10c07b21e0e0f7ec` |

- **Quartus**：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- **Build 方法**：firmware build 後執行 `quartus_sh --clean`，再做 Master/Slave fresh compile。
- **Master compile**：Full Compilation successful，0 errors，270 warnings。
- **Slave compile**：Full Compilation successful，0 errors，271 warnings。
- **Timing 狀態**：TimeQuest 報告 `Critical Warning (332148): Timing requirements not met`，build script 的 `timing_closed=NO`；因此不能宣稱 timing closure。

## 5. 燒錄結果

第一次 programmer 嘗試因 shell quoting 使 `-o p;/path` 被錯誤拆開，沒有完成設定。
修正 quoting 後重新燒錄：

### Master：DE5 [1-11.1]

- Programming checksum：`0x30A0C7B1`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors，0 warnings
- 時間：2026-08-20 05:15:58 至 05:16:17
- 原始 log：`program_master_step4_gate_20260820.log`

### Slave：DE5 [1-11.2]

- Programming checksum：`0x30A27099`
- `Configuration succeeded -- 1 device(s) configured`
- 0 errors，0 warnings
- 時間：2026-08-20 05:16:17 至 05:16:36
- 原始 log：`program_slave_step4_gate_20260820.log`

本次沒有發生 stall、斷線或需要重開機。

## 6. 原始 log 與 SHA256

| 檔案 | SHA256 |
|---|---|
| `program_master_step4_gate_20260820.log` | `2c811e0defcd98ae849da7d5608f83c3a3a7924b39b123c68e2a2a0c4cf5e9f3` |
| `program_slave_step4_gate_20260820.log` | `840fd895f463226a8d3cb54667c54c8d60ca76cd87f350b67f17ebc9cf4d017d` |
| `quartus_jtag_master_compile.log` | pain build log，完整檔案已保存 |
| `quartus_jtag_slave_compile.log` | pain build log，完整檔案已保存 |
| `jtag_runtime_step4_gate_20260820.log` | `2e99f4fb7a43cf73ef09d34650c95452bf468d863c7bf0b0a968ae028974e34e` |
| `jtag_event_chain_step4_gate_20260820.log` | `384d74229456febdbe1ed84d5a1bfb61b851b6ea36d08fad6a7322d3f4b4bde1` |
| `jtag_hpll_correlation_step4_gate_20260820.log` | `aa02777b1a1930a41e7be1c323d3c859b11c303ed90024e34d51685dc1b1b772` |
| `jtag_context_step4_gate_20260820.log` | `2d3d503507e33fd6b2c5f21790202713203e62383d3e1014d1ae5e8425a70c02` |

## 7. JTAG 實測摘要

### Master：DE5 [1-11.1]

- `PTP=00000006`，符合 PPS master。
- `SPLL_STATE=00020009`。
- `RCER=0`、`TAG_VALID=0`、`TRR_WRITE=0`、`HELPER_UPDATE=0`。
- 新增 ref/feedback gate counter 與 last tick 全為 0。

### Slave：DE5 [1-11.2]

- `PTP=00000009`，符合 PPS slave。
- 多數 runtime sample：`FOREIGN_META=03000001`。
- `LOCK_ENABLE=4`，表示 enable path 已到達可觀測的 enable 狀態。
- `SPLL_STATE=00030009`，依目前 decode 為 Slave 的 `SEQ_WAIT_MAIN`。
- `RCER=1`，但新增的 `tags_p & RCER` gate counter 仍為 0。
- `TAG_VALID=0`、`TRR_WRITE=0`、`HELPER_UPDATE=0`。
- gate counter、req-set counter、last tick 沒有形成持續增加。
- DMTD ref/feedback `seen=1` 且 event counter 非零，但不等同 tagger 已產生有效 tag。

HPLL correlation log 有少數非零或不連續的暫態欄位，但沒有單調增加的 event chain；
因此不把孤立讀值當作 SoftPLL 已運作的證據。

## 8. Acceptance table

| Gate | 結果 | 證據 |
|---|---|---|
| Fresh HEAD build | PASS | Master/Slave compile 均 0 errors |
| Fresh SOF program | PASS | 兩板 configuration succeeded |
| QSFP / Native PHY | PASS（沿用 Step 1 evidence） | status probe / runtime healthy |
| Endpoint / MiniNIC / PTP path | PASS（沿用 Step 2 evidence） | PTP role、packet counters、foreign master |
| Slave parent discovery | PASS（目前樣本） | `PTP=9`、`FOREIGN_META=03000001` 多數樣本 |
| `locking_enable()` / enable state | PARTIAL | `LOCK_ENABLE=4`、`RCER=1` |
| tagger event gate | FAIL | gate counters 與 last ticks 全為 0 |
| TAG_VALID / TRR_WRITE | FAIL | 沒有持續活動 |
| helper update / main correction | FAIL | `HELPER_UPDATE=0`，未見可靠 correction/DCO request activity |
| Step 4 SoftPLL Enable | **NOT PASS** | 尚未形成完整事件鏈 |

## 9. Observation

本次 fresh HEAD 已證明新增的唯讀計數器能被 compile、program 與 JTAG script 讀取；
也再次看到 Slave 的 `LOCK_ENABLE=4` 與 `RCER=1`。但是在同一 image 上，
`tags_p` 與 `RCER/OCER` 沒有形成事件，後續 `tags_req`、`TAG_VALID`、`TRR_WRITE`
與 helper update 也沒有持續活動。

目前能確定的最早無活動節點是：

```text
RCER/OCER + tags_p 同週期 gate
        ↓
tags_req / TAG_VALID / TRR_WRITE
```

這把問題優先收斂到 SoftPLL enable 後的 tag 事件產生或其條件鏈，但尚未足以判定
根因是 DDMTD、tagger、IRQ、Wishbone snapshot 或其他 gating。部分 JTAG 讀值具有
非單調/瞬間改變現象，因此孤立的非零欄位不採納為成功證據。

## 10. Conclusion

1. `5400074` 的 fresh firmware、fresh clean Quartus compile 與雙板 fresh SOF program 均成功。
2. Step 1～Step 3 的既有條件在本次多數 runtime sample 仍存在：Master `PTP=6`、Slave `PTP=9`、Slave 多數樣本 `FOREIGN_META=03000001`。
3. Slave 已有 `LOCK_ENABLE=4` 與 `RCER=1` 的 enable 相關證據。
4. 尚未證明 SoftPLL 已持續處理 tag、TRR、helper 或 main correction，因此 **Step 4 尚未通過**。
5. 本次沒有修改 SoftPLL 控制演算法，也沒有改變 DDMTD polarity、PI gain、lock threshold、DCO gain 或 SI5340 行為。

## 11. Next Step

下一步仍先做 read-only source/runtime audit：

1. 逐一核對 `locking_enable()` 後的 channel enable、RCER enable、tagger enable、IRQ enable 與 `p_latch_tags` 條件。
2. 將 `tags_p`、RCER/OCER、`tags_req` pending、TRR write request 與 IRQ source 的 source-level 條件對照到同一組 register/clock domain。
3. 只有在同一 image 重新看到 gate counter 單調增加後，才進行 helper arithmetic correlation。
4. 不修改 DDMTD polarity、PI gain、lock threshold、DCO gain 或 SI5340 演算法。
5. 下一次若需要燒錄，必須先以獨立 commit 保存修改，再重新建立完整 provenance，並立即新增新的實驗紀錄。

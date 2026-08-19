# EXP-WRPC-STEP4-TICS-20260820

## 實驗基本資料

- 實驗日期：2026-08-20
- 實驗分支：`exp/step4-softpll-enable`
- 燒錄來源 commit：`29539314c9ffaeff40e05bdcdda966da4b9ddfbb`
- 實驗名稱：Step 4 SoftPLL event source last-event tick discriminator
- 實驗性質：唯讀觀測；沒有修改 SoftPLL 控制行為、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 演算法

## 想驗證什麼

上一輪的 `TAG_PENDING_COUNT=0`、`TAG_GRANT_COUNT=0` 尚不能區分兩種情況：

1. 上游沒有新的 DDMTD/tag event；或
2. 上游有 event，但 request/grant path 沒有往下走。

本次加入 `clk_sys` 診斷 tick、各事件的 last-event tick，以及 request reference/feedback cycle counters，直接比較 `CURRENT_TICS - LAST_EVENT_TICS`。

## 相較 baseline 唯一修改

只增加唯讀 shadow registers，分段觀察：

```text
DDMTD event -> tags_p -> tags_req -> tags_grant_p -> tag_valid -> TRR write
```

新增欄位不接回任何 SoftPLL FSM、servo、DAC 或 SI5340 控制。

## Build 與 provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`815e36e5d40430acafe45a7436c8e53d91c6f8515e0e4455415fc4e05cd6afd1`
- Slave MIF SHA256：`241219dbcffbfb838b1886428c76ef959ef5da3c0fd47606d9e0599ac9a3770b`
- Master SOF SHA256：`20fe92793b1a3b53e82bc2839d7bd30f01b81be6cf3bb0138ab10ee14a43b004`
- Slave SOF SHA256：`b64c9f7b2225c11efe8bb16e7495f87482d5986bd6c286a8e96a42dec9f6c52b`
- Master timing：compile successful，`TIMING_CLOSED=NO`，worst setup slack `-0.399 ns`
- Slave timing：compile successful，`TIMING_CLOSED=NO`，worst setup slack `-0.186 ns`

完整 build、hash 與 compile 輸出保存在本資料夾的對應檔案。

## 燒錄結果

### Master

- JTAG cable：`DE5 [1-11.1]`
- Programmer checksum：`0x30A2E2F5`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

### Slave

- JTAG cable：`DE5 [1-11.2]`
- Programmer checksum：`0x30A5398A`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

原始燒錄輸出為 `program_jtag_master_tics_20260820.log` 與 `program_jtag_slave_tics_20260820.log`。

## JTAG 原始結果

完整輸出保存在：

- `jtag_step4_tics_20260820.log`
- `jtag_step4_tics_timeseries_20260820.log`
- `jtag_runtime_tics_20260820.log`

單次 event-chain 讀值的重點如下：

| 觀測項目 | Master | Slave |
|---|---:|---:|
| `CURRENT_TICS` BEGIN -> END | `0x3A56E4B1` -> `0x3EFE7C3D` | `0xB43C4C10` -> `0xB8E24A3A` |
| DMTD last-event tick | `REF=0x048A9AB7`、`FB=0x048A9ABC` | `REF=0x2DD03F83`、`FB=0x2DD03F81` |
| `tags_p` last-event tick | `REF=0x048A9AB8`、`FB=0x048A9ABD` | `REF=0x2DD03F84`、`FB=0x2DD03F82` |
| request ref/fb count | `0 / 0` | `0 / 0` |
| request/grant/valid/TRR last tick | 全部 `0` | 全部 `0` |

完整 runtime snapshot：

- Master：CPU `reset=0/fault=0/im_valid=1`、marker `B004`、`PTP=6`、`MODE=2`、PTP RX/TX `0x55/0xB7`。
- Slave：CPU `reset=0/fault=0/im_valid=1`、marker `B004`、`PTP=8`、`MODE=3`、PTP RX/TX `0xB8/0x40`、`FOREIGN_META=03000001`。

## Observation

1. `CURRENT_TICS` 在約 1 秒的 BEGIN/END 間隔持續增加。
2. DMTD ref/fb last-event tick 與 `tags_p` ref/fb last-event tick 在 BEGIN 到 END 之間完全不變。
3. request ref/fb counters、request last tick、grant last tick、tag-valid last tick、TRR last tick 全部維持 0。
4. 這表示兩片 FPGA 都曾在啟動早期看到 DDMTD/tag event，但在本次 runtime 觀測窗口內沒有新的 upstream event；因此不能把停點推論為 arbiter grant failure。
5. Master role 本次已恢復為 `MODE=2`、`PTP=6`；Slave 仍讀到 `MODE=3`、`FOREIGN_META=03000001`，但 PTP state 是 `8`，尚未重現歷史 `PPS_SLAVE=9` 的完整 baseline。

## Conclusion

- Compile：PASS。
- 雙板 programming：PASS。
- 新增 last-event/tick JTAG observation：PASS。
- Step 4 SoftPLL Enable：**NOT PASS**。
- 第一個已由本次證據支持的 blocker 是：SoftPLL event source 在 startup 後停止或被 qualification/reset 條件停止；目前沒有證據支持「request 已形成但 grant 被 arbiter 阻擋」。
- 本次仍沒有證據證明 SoftPLL 已 enable 到 helper/main correction、已 lock，或已完成 WR time synchronization。

## Next Step

下一步仍維持唯讀 source/runtime audit，追查 DDMTD sampler/deglitcher 的 event qualification、reset 與 clock-domain 條件，並保留現有 last-event tick 作為判定依據。若之後要做單一 functional A/B，必須另開明確實驗、先 commit、重新 clean build/program，且不能把 A/B 結果直接標成 Step 4 PASS。

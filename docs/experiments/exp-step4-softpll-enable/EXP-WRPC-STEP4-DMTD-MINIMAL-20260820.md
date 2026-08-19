# 實驗紀錄：Step 4 DMTD event 極簡唯讀 confirmation

## 1. 實驗基本資料

- **Experiment ID**：`EXP-WRPC-STEP4-DMTD-MINIMAL-20260820`
- **日期**：2026-08-20（Asia/Taipei）
- **Git branch**：`exp/step4-softpll-enable`
- **JTAG 腳本 commit**：`adf70a7 診斷：加入 DMTD 極簡唯讀確認`
- **實際硬體 image source commit**：`5400074928104205d857e196dfbb221723592670`
- **實驗類型**：read-only JTAG runtime confirmation
- **是否重新 compile**：否
- **是否重新燒錄**：否

本次使用 10 個 sample、每秒一次，只讀取目前 tick、DMTD ref/feedback event
counter、兩個 last-event tick、DMTD state/reset、RCER/OCER 與 ref/feedback tag
counter。腳本不讀 `TRR_R0`，也沒有寫入任何設定。

## 2. 這次想驗證什麼

上一個 20 秒 boundary audit 已顯示 DMTD event counter 沒有 delta，但同時讀取的
欄位較多，少數 JTAG mailbox 讀值有跳變。本次縮小讀取集合，確認：

```text
CURRENT_TICS              持續增加
DMTD_REF_EVENTS           是否增加
DMTD_FB_EVENTS            是否增加
REF/FB_LAST_EVENT_TICS    是否更新
DMTD_STATE/reset          目前狀態
TAG_REF/TAG_FB            下游是否跟著增加
```

## 3. 硬體 provenance

本次仍沿用上一輪由 `5400074` fresh build 產生並已燒錄的 image，沒有重新 program：

| 項目 | Master | Slave |
|---|---|---|
| SOF SHA256 | `d7da711bf5d302bc55df92941281450842ce39858a1150041856da9ba90b379c` | `4bdb11f19815cf4d99b4f7f04242ca3f977b57dc6325ed1e10c07b21e0e0f7ec` |
| Programmer checksum | `0x30A0C7B1` | `0x30A27099` |

- **Quartus**：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- **本輪 programming log**：無；沿用 `EXP-WRPC-STEP4-TAG-GATE-20260820` 的燒錄 provenance

## 4. 原始結果

完整 raw log：`jtag_dmtd_minimal_step4_20260820.log`

SHA256：

```text
25903CF584C1F64E62EDB09E40CCBB515907BD637880603FF03F70FC45AC8010
```

### Master：DE5 [1-11.1]

- `NOW` 從約 `B513AEF3` 增加到 `D8A7AF73`，runtime tick 持續前進。
- `REF_EVENTS=001C9545`、`FB_EVENTS=009E92A6` 在 10 個 sample 中維持固定。
- `REF_LAST`、`FB_LAST` 主要 sample 維持約 `048A9AB6`、`048A9ABC`，沒有新的單調更新。
- DMTD state 主要是 `RAW=0000000A`：`REF_STATE=2`、`FB_STATE=2`，reset bits 為 0。
- `RCER=0`、`OCER=1` 主要 sample 成立；tag counter 沒有跟著增加。

### Slave：DE5 [1-11.2]

- `NOW` 從約 `93D30370` 增加到 `B769FF3C`，runtime tick 持續前進。
- `REF_EVENTS=05CC8C7F`、`FB_EVENTS=0651CA7F` 在 10 個 sample 中維持固定。
- `REF_LAST=2E0A832D`、`FB_LAST=2E0A832C` 主要 sample 維持固定，沒有新的單調更新。
- DMTD state 主要是 `RAW=00000008`：`REF_STATE=0`（`WAIT_STABLE_0`）、
  `FB_STATE=2`（`GOT_EDGE`），reset bits 為 0。
- `RCER=1`、`OCER=1` 主要 sample 成立；tag counter 沒有跟著增加。

## 5. Observation

這次最小欄位讀取仍重現：

```text
runtime tick                 有增加
DMTD event counter           沒有增加
DMTD last-event tick         沒有更新
TAG_REF / TAG_FB             沒有持續增加
reset bits                   主要 sample 為 0
```

因此目前 Step 4 的第一個可觀察 blocker 可寫成：

```text
clock / DMTD input
        ↓
dmtd_with_deglitcher
        ↓
dmtd_event_sys 沒有新的持續 event
        ↓
tags_p / tags_req / grant / TRR / helper 尚未形成活動
```

## 6. JTAG 讀值限制

極簡腳本仍出現少數單筆欄位跳變，例如某一 sample 的 `TAG_REF` 或 `RCER` 不符合
鄰近 sample。這些現象視為 mailbox readout/snapshot noise 或非原子讀取限制，不能
作為 functional 結論。相對地，兩個 event counter 在整個 sample window 固定，以及
runtime tick 持續增加，是本次採納的主要證據。

## 7. Conclusion

1. 極簡 read-only confirmation 支持 `STEP4_A1_CURRENT_BLOCKER = no sustained DMTD/deglitcher event generation`。
2. 這比「request/grant arbiter 故障」更早，因為上游 DMTD event counter 已沒有 delta。
3. Slave reference path 長期位於 `WAIT_STABLE_0` 是重要線索，但不是根因證明。
4. 目前仍不能宣稱 DDMTD polarity、clock source、deglitch threshold 或 reset/qualification 哪一項是根因。
5. Step 4 SoftPLL Enable 仍為 **NOT PASS**，也沒有進入 helper arithmetic correlation。

## 8. Next Step

下一步仍維持唯讀：檢查 source 中 Slave reference DMTD 的 recovered-clock、sampled-clock、
deglitcher state transition、resync/reset 與 `new_edge_p_sysclk` 的連接和條件。未經明確
核准，不修改 DDMTD polarity、PI gain、lock threshold、DCO gain 或 SI5340 演算法。

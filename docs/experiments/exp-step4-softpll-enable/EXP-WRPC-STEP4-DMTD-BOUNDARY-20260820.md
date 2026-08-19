# 實驗紀錄：Step 4 DMTD 到 tags_p 邊界唯讀 audit

## 1. 實驗基本資料

- **Experiment ID**：`EXP-WRPC-STEP4-DMTD-BOUNDARY-20260820`
- **日期**：2026-08-20（Asia/Taipei）
- **Git branch**：`exp/step4-softpll-enable`
- **JTAG 腳本 commit**：`8e652d9 診斷：加入 DMTD 到 tags 邊界唯讀觀測`
- **實際硬體 image source commit**：`5400074928104205d857e196dfbb221723592670`
- **實驗類型**：read-only JTAG runtime audit
- **是否重新 compile**：否
- **是否重新燒錄**：否

本次只使用上一個實驗已燒錄的 fresh image，新增的 Tcl 腳本只讀取 register，沒有
修改 FPGA、firmware、PHY、PTP、WR signaling 或 SoftPLL 控制行為。

## 2. 這次想驗證什麼

前一輪已看到 `TAG_VALID`、`TRR_WRITE`、helper update 與 gate counter 沒有持續活動，
但尚未能區分：

```text
DMTD/deglitcher 沒有產生新的 event
        或
DMTD event 有產生，但沒有形成 tags_p / tags_req
```

本次以 20 個 sample、每秒一次觀察 DMTD state/reset、deglitch threshold、RCER/OCER、
DMTD event counter、tag counter、last tick、pending/grant 與 output counter。
腳本刻意不讀 `TRR_R0`，避免消費 tag FIFO。

## 3. 相較 baseline 唯一修改

只新增：

```text
scripts/jtag/read_step4_dmtd_boundary.tcl
```

此腳本是唯讀觀測工具，不是 functional RTL 修改，也沒有重新產生 SOF。

## 4. 硬體 provenance

本次沿用 `5400074` 實驗已燒錄的 image：

| 項目 | Master | Slave |
|---|---|---|
| SOF SHA256 | `d7da711bf5d302bc55df92941281450842ce39858a1150041856da9ba90b379c` | `4bdb11f19815cf4d99b4f7f04242ca3f977b57dc6325ed1e10c07b21e0e0f7ec` |
| Programmer checksum | `0x30A0C7B1` | `0x30A27099` |

- **Quartus**：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- **前一輪 programming log**：同 branch 的 `EXP-WRPC-STEP4-TAG-GATE-20260820` 紀錄
- **本輪 programming**：無

## 5. 原始結果

完整 raw log：

```text
jtag_dmtd_boundary_step4_20260820.log
```

SHA256：

```text
7217CB8E02F15A07D4EBA2E4C1ED0094F6BAA0D78C099F2340BE6AA3A69E1CD2
```

### Master：DE5 [1-11.1]

在觀察窗中可重複看到：

- `DMTD event counter` 約為 `REF=001C9545`、`FB=009E92A6`，跨 sample 沒有單調增加。
- `REF_LAST=048A9AB6`、`FB_LAST=048A9ABC` 固定不變。
- `TAG_VALID=0`、`TRR_WRITE=0`。
- ref/feedback gate counter 與 req-set counter 全為 0。
- 多數 sample 的 DMTD state 是 `RAW=0000000A`：`REF_STATE=2`、`FB_STATE=2`，reset flag 為 0。
- `RCER=0`、`OCER=1`，符合 Master 目前不啟用 reference tagger 的觀測狀態。

### Slave：DE5 [1-11.2]

在觀察窗中可重複看到：

- `DMTD event counter` 約為 `REF=05CC8C7F`、`FB=0651CA7F`，跨 sample 沒有單調增加。
- `REF_LAST=2E0A832D`、`FB_LAST=2E0A832C` 固定不變。
- `TAG_VALID=0`、`TRR_WRITE=0`。
- ref/feedback gate counter 與 req-set counter 全為 0。
- 多數 sample 的 DMTD state 是 `RAW=00000008`：`REF_STATE=0`（`WAIT_STABLE_0`）、
  `FB_STATE=2`（`GOT_EDGE`），reset flag 為 0。
- `RCER=1`、`OCER=1` 多數 sample 成立；這表示 enable register 曾被設定，
  但沒有證明當下有新的 `tags_p` pulse。

## 6. Observation

這一輪新增的資訊是：

```text
DMTD event counter      沒有持續增加
DMTD last-event tick    沒有更新
tags / gate / TRR       沒有持續增加
reset flag              觀察到為 0
```

因此在目前的 20 秒 observation window 中，最早可以由計數器 delta 支持的無活動
位置，應由前一輪的：

```text
tags_p / RCER(OCER) -> tags_req
```

往前收斂到：

```text
DMTD/deglitcher event -> tags_p
```

特別是 Slave reference path 多數時間停在 `WAIT_STABLE_0`，這與「沒有形成新的
reference tag event」一致；但它仍不能單獨證明是 recovered clock、sampled clock、
deglitch qualification 或其他上游條件造成。

JTAG mailbox 的少數非關鍵欄位有偶發跳變，例如 `EIC_*`、`STAT_CR` 或 `SEEN` 欄位
在個別 sample 不一致。因此本紀錄只採納長時間重複且互相一致的 counter/last-tick
趨勢，不把孤立跳變當成 functional 證據。

## 7. Conclusion

1. 本次沒有 compile 或燒錄，不能把本輪稱為新的硬體 image 驗證。
2. 在沿用的 `5400074` fresh SOF 上，20 秒唯讀觀察沒有看到 DMTD event counter 或
   last-event tick 持續增加。
3. 這使「目前 observation window 沒有新的 DMTD/deglitcher event」成為比
   「arbiter、TRR 或 helper 故障」更早、且有 counter delta 支持的 blocker 假說。
4. 這仍不是 DDMTD polarity、clock source、deglitch threshold 或其他硬體根因的定論。
5. Step 4 SoftPLL Enable 仍是 **NOT PASS**；目前尚未證明 tag、TRR、helper 或 correction
   路徑持續工作。

## 8. Next Step

在不改變 functional behavior 的前提下，下一步先做更窄的 read-only confirmation：

1. 只讀少量欄位，降低 JTAG mailbox 讀取量造成的 snapshot 干擾。
2. 重複確認 `DMTD event counter`、`DMTD state`、`RCER/OCER`、`TAG_VALID` 與
   gate counter 的 delta。
3. 若 DMTD counter 仍不動，再檢查 source-level 的 recovered-clock、sampled-clock、
   deglitcher state 與 reset/qualification 連接；仍不修改 polarity、PI、lock threshold、
   DCO gain 或 SI5340 演算法。
4. 只有在同一份 image 看到 tag/TRR/helper 持續活動後，才進入 helper arithmetic correlation。

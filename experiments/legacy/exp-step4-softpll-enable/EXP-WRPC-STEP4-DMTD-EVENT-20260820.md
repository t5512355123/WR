# EXP-WRPC-STEP4-DMTD-EVENT-20260820

## 實驗摘要

- Experiment ID：`EXP-WRPC-STEP4-DMTD-EVENT-20260820`
- 日期：2026-08-20
- Branch：`exp/step4-softpll-enable`
- Git commit：`b9bf6f5916d0df898691f130685b1b588b04e8c0`
- 實驗名稱：**Step 4 DDMTD/deglitcher event 唯讀觀測**
- 實驗狀態：**編譯 PASS、雙板燒錄 PASS、Step 4 NOT PASS；已找到比 helper 更早的 event-chain 停點**

## 這次想驗證什麼

前一輪 fresh SOF 長時間停在 `SEQ_CLEAR_DACS`，而 `TAG_VALID`、`TRR_WRITE`、`IRQ`
與 helper counter 沒有穩定活動。本輪要區分：

1. DDMTD/deglitcher 的 event 根本沒有產生；或
2. DDMTD event 已產生，但沒有通過 SoftPLL tag request/grant/valid/TRR 路徑。

## 相較 baseline 唯一修改

只新增唯讀 observability，不改變 White Rabbit 功能控制：

- 在 `dmtd_with_deglitcher` 導出已同步到 `clk_sys`、尚未進入 tag arbitration 的 event pulse。
- 在 `wr_softpll_ng` 累加 reference/feedback event count 與 sticky seen bit。
- 在 SoftPLL Wishbone slave 增加唯讀 register：`0x00100298..0x001002A4`。
- 更新 `read_step4_event_chain.tcl` 與 JTAG register map。

本輪沒有修改 PHY、`g_softpll_reverse_dmtds`、PI gain、lock threshold、DDMTD
polarity、DCO gain、SI5340 控制、TRR FIFO 讀取或 SoftPLL sequencing 行為。

## 建置與 provenance

- Quartus：`17.0.0 Build 595`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`8d6e78fb3891333e92763bfd41997ead9ab561caddd8eb28a70b22902088a14b`
- Slave MIF SHA256：`f93f961ecc424cb7a85ac923aa8fbfa2750fc57a582ae1d08873918bdcd76161`
- Master SOF SHA256：`755053963503f2978b2215f54054b1e8840c4d2b361979e50cf91792d2d6f031`
- Slave SOF SHA256：`7bd30f612d3c14cf8872fb7311f60bf792acda1afe77e8288a6bca3e43167784`
- Master Fitter：`Successful`；`TIMING_CLOSED=NO`；worst setup slack `-0.197 ns`
- Slave Fitter：`Successful`；`TIMING_CLOSED=NO`；worst setup slack `-0.393 ns`

完整 build log、hash 與 SOF 保存在同資料夾；SOF 只作 provenance 保存，不作為 Git source。

## 燒錄結果

使用 exact commit 產生的 fresh SOF：

- Master programmer：`Configuration succeeded -- 1 device(s) configured`
- Master programmer checksum：`0x30A112B9`
- Slave programmer：`Configuration succeeded -- 1 device(s) configured`
- Slave programmer checksum：`0x309F0446`
- Quartus Programmer：17.0 Build 595，兩片均 `0 errors, 0 warnings`

原始輸出：

- `program_jtag_master_dmtd_event_20260820.log`
- `program_jtag_slave_dmtd_event_20260820.log`

## JTAG / runtime 原始結果

燒錄後等待 30 秒，再執行 `read_step4_event_chain.tcl 1000` 與
`read_wb_runtime.tcl`。完整原始輸出：

- `jtag_step4_dmtd_event_20260820.log`
- `jtag_step4_dmtd_event_timeseries_20260820.log`
- `jtag_runtime_dmtd_event_20260820.log`

10 次 event-chain series 的穩定觀測摘要：

| 欄位 | Master | Slave |
|---|---:|---:|
| `DMTD_REF_EVENTS` | `0x001C88AB` | `0x05B9E04A` |
| `DMTD_FB_EVENTS` | `0x009E32B4` | `0x0637B164` |
| `DMTD_REF_SEEN` | `1` | `1` |
| `DMTD_FB_SEEN` | `1` | `1` |
| `SPLL_STATE` | `0x00020009` | `0x00030009` |
| `LOCK_ENABLE` | `0` | `4` |
| RCER / OCER | `0 / 1` | `1 / 1` |

新增 event count 與既有 `REF` / `FEEDBACK` tag-source counter 在本輪相符，表示
DDMTD/deglitcher event 與 `tags_p` 曾經抵達 SoftPLL tag input。可是多數樣本的
`TAG_VALID`、`TRR_WRITE`、`IRQ`、`HELPER_UPDATE_COUNT` 仍為 0；在某些 JTAG
mailbox sample 出現不一致的 stale/tear 欄位，因此只把穩定重現的零值當作負面
證據，不把偶發的非零值當成通過條件。

`read_wb_runtime.tcl` 仍確認：

- Master：`MODE=2`、`PTP=6`、`B004 seen=1`、PTP RX/TX 有活動。
- Slave：`MODE=3`、`PTP=9`、`FOREIGN_META=03000001`、`B004 seen=1`、PTP RX/TX 有活動。
- Step 1～3 沒有因本輪 observability 修改而退化。

## Observation

這次已排除「所有 DDMTD source event 都不存在」這個最早假設。兩邊都有
`REF_SEEN=1`、`FB_SEEN=1`，而且 counters 有歷史活動；但是 event 沒有穩定形成
可推動 sequencer 的 `TAG_VALID/TRR_WRITE/IRQ` 活動。Slave 仍停在
`SEQ_CLEAR_DACS`，Master 停在 `SEQ_CLEAR_DACS` 對應的 master context。

## Conclusion

證據支持以下保守結論：

> 本輪 fresh HEAD 已證明 DDMTD/deglitcher 與 `tags_p` 邊界曾有 event；目前第一個
> 尚未被證明為 active 的區段，位於 `tags_req/tags_grant/tag_valid/TRR write`
> 之間或其 runtime enable/context 附近。這不是 helper correction、DCO 或
> SI5340 的證據。

因此：

- Step 1～3：維持 PASS 證據。
- Step 4 SoftPLL Enable：**NOT PASS**。
- 不宣稱 SoftPLL 已 lock，也不宣稱 time synchronization 完成。
- 不因本輪結果修改 DDMTD polarity 或其他控制演算法。

## Next Step

下一輪仍只做 read-only observability：在 `tags_req`、`tags_grant_p`、`tag_valid`
與 TRR write 邊界增加 request/grant counters，確認是 channel enable、round-robin
grant，還是 tag-valid/TRR output 沒有形成。若要做 polarity A/B，必須另開單一變因
實驗並明確標示為 root-cause replication，不得把它寫成 Step 4 PASS。

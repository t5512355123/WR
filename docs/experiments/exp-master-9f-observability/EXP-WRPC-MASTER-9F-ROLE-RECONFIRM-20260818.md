# 實驗紀錄：Master 9f848ec role 重確認

- Experiment ID：`EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818`
- 日期：2026-08-18
- 實驗類型：已知成功 Master 映像重燒錄；本紀錄先保存燒錄證據，runtime 讀取將在同一輪後續補上
- Git branch：`exp/master-9f-observability`
- Git commit：`e0f478a`
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

重新載入歷史上已實際成功的 `9f848ec` Master role 對應的 diagnostic baseline，確認不要再發明新的 Master role 切換方法。後續成功判準固定為：

```text
marker = B004
WDIAGS_MODE = 2
WDIAGS_PTP = 6
link_up = 1
PTP RX/TX counter 持續增加
```

這些條件全部成立後，才把 Master role 固定，回到 Slave 研究。

## 相較 baseline 唯一修改

沒有修改 source、firmware、startup command、PHY、QSFP lane、clock、PTP、servo 或 role API。這次只重新燒錄已保存的 Master SOF。

## 映像與 hash

| 項目 | 值 |
|---|---|
| Master SOF | `quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof` |
| Master SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` |
| Master MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` |
| Master defconfig SHA-256 | `a50d6899e8e29055b8cf2e1926d422ac458a7c3b5ad7e504b04d31e697723556` |
| Master identity header SHA-256 | `c8c8fbaf4c1a7b99c4cad7491a9134e4e0d698ac068b894d5a0ee2d18c06f692` |

## 燒錄結果

使用 cable `DE5 [1-11.1]`。原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/program_master.log
```

原始 log SHA-256：`b4d6865035835e54d5da8d8e88f65ebdc5714dd124a4be36c925bf074b7e98e8`

Quartus Programmer 原始結果：

```text
Info (213011): Using programming file .../DE5a_wr_master_jtag.sof with checksum 0x30A46449
Info (213045): Using programming cable "DE5 [1-11.1]"
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## Runtime 原始結果

兩片板重新配置後，使用 Quartus 17.0 `read_wb_timeseries_session.tcl 10 1000 3`，再使用 `read_wb_runtime.tcl` 做 snapshot。原始檔案與 hash：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_timeseries.log
SHA-256: 5e407f9fec2f188e3361262b1e3707249865953f5b46b2a3b1aae378e19caf18

/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot.log
SHA-256: 2ad8d400a4c3c14f7ac450db9ee76603ddff2fa3621935f0049274817a7fe426

/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot_after30s.log
SHA-256: 6406b450b8f8bd2f86ce435a0378a1483a2880daa71db744884d28654b3c7f28

/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/runtime_snapshot_after90s.log
SHA-256: 398efc6baf85bf08b8439b952ee4e75de62c7e7cf30f1edfb30428f5f68a1c43

/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-ROLE-RECONFIRM-20260818/hpll_helper_correlation_60s.log
SHA-256: 86ef7bd1c5571c368fbfbc0976e5efe822c129a02092af013f41ec8f17704a08
```

Master 的唯讀 session 結果：

```text
marker=B004 seen=1
CPU fault=0, im_valid=1
MODE=2
status_low=FF（time_valid=1、pps_valid=1、link_up=1）
PTP RX/TX：由 0x1C/0x46 增加至約 0x23/0x5E
```

10-sample session 的 Master sample 全部 accepted；早期有效列曾出現 `WDIAGS_PTP=6`。但是 30 秒與 90 秒 snapshot 都是：

```text
WDIAGS_MODE=2
WDIAGS_PTP=1
WDIAGS_PTP_RX=0x2D
WDIAGS_PTP_TX=0x78
status_low=FF
```

因此本輪沒有把 `WDIAGS_PTP=6` 寫成長時間穩定結果。

## Observation

歷史 Master role 的核心行為成功重現：`marker=B004`、`MODE=2`、`status_low=FF`、`link_up=1`，且 PTP counter 有活動。`WDIAGS_PTP=6` 只在部分早期有效 sample 出現，等待 30/90 秒後回到 `1`；因此 role 已固定，但五項嚴格 diagnostic baseline 尚未全部以穩定時間序列通過。

## Conclusion

證據支持：這次沒有發明新的 Master role 切換方法，已知的 `9f848ec` Master role 仍可在同一 SOF 上重現 `MODE=2/status=FF`，Master 不應再被修改。

證據不支持：目前已完成 White Rabbit 端到端同步，也不支持宣稱 `WDIAGS_PTP=6` 已長時間穩定。Slave 仍是 `MODE=3、time_valid=0、spll_locked=0`，因此本輪不能宣稱雙板同步成功。

## Next Step

固定 Master 映像與 role，不再做 role 切換實驗。下一步仍只研究 Slave 的 `TAG/TRR/IRQ/SoftPLL/Helper` input path；先用唯讀證據區分「沒有 tag」、「IRQ 沒有服務」與「helper source gating」，不要反轉 FINC/FDEC、不要新增會改變 timing 的 RTL observer。

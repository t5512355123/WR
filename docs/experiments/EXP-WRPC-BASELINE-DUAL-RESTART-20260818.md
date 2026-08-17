# EXP-WRPC-BASELINE-DUAL-RESTART

## 實驗資訊

- Experiment ID：`EXP-WRPC-BASELINE-DUAL-RESTART-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`d0077d3`（燒錄前最新紀錄 checkout）
- 實驗類型：雙板 exact baseline runtime restart
- Quartus：Quartus Prime 17.0 Build 595
- compile：未執行；使用既有已保存 SOF
- 目的：以明確順序重新載入兩片已知 baseline，排除只有單片重燒或 runtime startup 順序造成的狀態差異

## 為了驗證什麼

前一輪恢復 Slave `aa0825a` readback SOF 後，30 秒與 120 秒都沒有重現早期 log 中的 PTP/parent/tag activity。這次不修改 source 或 firmware，只重新載入：

```text
Master：歷史 9f848ec exact SOF
Slave ：aa0825a readback exact SOF
```

燒錄順序固定為 Master → Slave，之後才做同一份 JTAG runtime time-series。

## 相較 baseline 唯一修改了什麼

沒有修改任何 source、firmware、RTL、MIF、QSF、SDC、PHY、PTP、SoftPLL 或 Master role。唯一操作變因是：

```text
兩片 exact baseline 重新載入，並固定燒錄順序
```

這不是新的 Master role switching 方法。

## Bitstream provenance

| 項目 | Master | Slave |
|---|---|---|
| role/source | `9f848ec` historical Master | `aa0825a` readback baseline |
| SOF | `quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof` | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| SOF SHA-256 | `1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db` | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| MIF SHA-256 | `b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0` | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |

## 燒錄結果

### Master

- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-BASELINE-DUAL-RESTART-20260818/program_master.log`
- log SHA-256：`0b82adbb4dda59e2bca975f290950e02047457934550abf089252b4dbbe6dad2`
- Programmer checksum：`0x30A46449`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded`、`Successfully performed operation(s)`、0 errors / 0 warnings

### Slave

- 原始 log：`/home/b10504072/04_WR/artifacts/EXP-WRPC-BASELINE-DUAL-RESTART-20260818/program_slave.log`
- log SHA-256：`ec45fecd74564961ed2ed311bd4f1a9f3ef1b2cdcf0d2891aad08e4ffa8b896a`
- Programmer checksum：`0x309FA629`
- JTAG ID：`0x02E660DD`
- 結果：`Configuration succeeded`、`Successfully performed operation(s)`、0 errors / 0 warnings

一度曾啟動重複的遠端 shell command；在發現兩個 programmer session 可能重疊後立即停止第二個 session。最終保存的兩份 log 均為完整成功操作，且兩個 cable 的實際 programming output 均顯示成功；本段只記錄操作狀況，不把它解讀成 WR 功能證據。

## Runtime 結果

本 commit 只完成燒錄紀錄。後續 JTAG time-series 必須另存原始 log 與 SHA-256，並追加到本文件；在 runtime 完成前，不宣稱兩片同步成功。

## Observation

目前可確認：兩片 FPGA 都成功載入與既有 baseline 完全相同的 SOF。尚未確認 Slave parent acquisition 或 servo lock。

## Conclusion

> 雙板 exact baseline restart 的燒錄階段成功；本實驗尚未提供 White Rabbit 時間同步成功證據。

## Next Step

使用同一 JTAG session 讀取：

```text
MODE、status、PTP state、PTP RX/TX、foreign/parent flags、WR state、
SPLL sequence、RCER、TAG_VALID、TRR_WRITE、IRQ、PSTAT、SSTAT、time_valid、pps_valid
```

只有當 Slave 出現穩定 `parent_is_wr=1`、`parent_calibrated=1`、`spll_locked=1`、`time_valid=1`、`pps_valid=1`，且兩端在同一觀測窗保持一致，才可宣稱同步完成。

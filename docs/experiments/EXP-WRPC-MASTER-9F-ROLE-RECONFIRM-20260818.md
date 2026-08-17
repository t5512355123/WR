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

本檔在 Master 燒錄完成後立即建立；為避免在 Slave 燒錄前混合兩張板的狀態，Master runtime 將在同一輪兩板重新載入後，以固定唯讀 JTAG script 讀取並補入本紀錄。

## Observation

目前只有燒錄證據，尚未以本輪 runtime 讀值宣稱 Master role 成功。

## Conclusion

目前證據只支持：已知 Master SOF 已成功配置到 DE5a。尚未支持 `MODE=2/PTP=6/status=FF`，因為 runtime 讀值尚待完成。

## Next Step

在不改任何 Master role 的前提下，燒錄已保存的 Slave readback baseline；兩片板都配置完成後，使用同一個唯讀 JTAG session 讀取 Master 五項判準與 Slave parent/servo/SoftPLL 欄位。

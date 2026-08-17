# 實驗紀錄：Slave readback baseline 重確認

- Experiment ID：`EXP-WRPC-SLAVE-BASELINE-RECONFIRM-20260818`
- 日期：2026-08-18
- 實驗類型：已知穩定 Slave readback 映像重燒錄；本紀錄先保存燒錄證據，雙板 runtime 讀取另行補入
- Git branch：`exp/master-9f-observability`
- Git commit：`182411f`
- Quartus：17.0.0 Build 595 SJ Standard Edition

## 想驗證什麼

在 Master 已重新載入歷史成功 `9f848ec` role 後，重新載入已保存的 Slave readback baseline，建立可比較的雙板起點。Slave 不能只以 `link_up` 或 `pps_valid` 判定成功；後續需觀察 parent/servo/SoftPLL，並以 `time_valid=1`、SoftPLL lock 與穩定有效 frame 作為同步成功判準。

## 相較 baseline 唯一修改

沒有修改 source、firmware、startup command、PHY、QSFP lane、clock、PTP、servo 或 role API。這次只重新燒錄已保存的 Slave SOF。

## 映像與 hash

| 項目 | 值 |
|---|---|
| Slave SOF | `artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof` |
| Slave SOF SHA-256 | `079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13` |
| Slave MIF SHA-256 | `f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4` |
| Slave defconfig SHA-256 | `a8d3a90fa2b724a6f3f01a93e887364b12b140a8837f35882e7c6aa73386c212` |
| Slave identity header SHA-256 | `33ded2dc62811525a395d12a5a396dda1553339119eba2f37c86cf8cf4639d55` |

## 燒錄結果

使用 cable `DE5 [1-11.2]`。原始 log：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-BASELINE-RECONFIRM-20260818/program_slave.log
```

原始 log SHA-256：`1e528b2c7fd328338a29374e0fbc03ca5251a84b0d714b8c4a85df6507b81a4a`

Quartus Programmer 原始結果：

```text
Info (213011): Using programming file .../DE5a_wr_slave_jtag.sof with checksum 0x309FA629
Info (213045): Using programming cable "DE5 [1-11.2]"
Info (209017): Device 1 contains JTAG ID code 0x02E660DD
Info (209007): Configuration succeeded -- 1 device(s) configured
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

## Runtime 原始結果

本檔在 Slave 燒錄完成後立即建立；雙板重新配置完成後，使用固定唯讀 JTAG script 讀取 Master role 五項判準與 Slave parent/servo/SoftPLL 欄位，再把原始 log、hash 與解碼結果補入本紀錄。

## Observation

目前只有燒錄證據，尚未以本輪 runtime 讀值宣稱 Slave 進入同步。

## Conclusion

目前證據只支持：已知穩定 Slave SOF 已成功配置到 DE5a。尚未支持 Slave `time_valid=1` 或 SoftPLL lock。

## Next Step

使用同一個唯讀 JTAG session 讀取兩片板：Master 的 `marker、MODE、PTP、link_up、PTP RX/TX`，以及 Slave 的 `SSTAT、PSTAT、parent flags、UCNT、DCO/HPLL/helper`。不修改任何 role 或控制參數。

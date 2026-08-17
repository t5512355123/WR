# EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-READBACK-PROBE-RESTORE-20260818`
- 日期：2026-08-18
- 實驗類型：Slave-only historical probe-bearing image restore、燒錄後唯讀 runtime 觀測
- Git branch：`exp/master-9f-observability`
- Git commit：`a5a2773`（本輪燒錄前的 source/docs provenance）
- Quartus：Quartus Prime 17.0 Build 595 Standard Edition

## 這次想驗證什麼

上一輪把歷史 positive-control Slave SOF 燒錄成功，但該 image 沒有目前診斷腳本需要的 Sources and Probes，因此無法判斷 runtime。這一輪恢復 repository 中已確認含有 probe、且曾經成功讀出 Slave readback/parent/SoftPLL 欄位的 `079fade...` image，重新建立可觀測的 Slave baseline。

本輪不重新編譯、不修改 Master role、不修改 PHY、PTP、SoftPLL、DMTD、SI5340 或 firmware。Master 完全維持歷史成功的 `9f848ec` image。

## 相較上一輪唯一修改了什麼

只替換 Slave FPGA configuration image：

- 上一輪無 probe restore image：`6a4357519c2c7996d28bbc2ade098ba8ab58b1f336c48953737932cf168bb225`
- 本輪 probe-bearing readback image：`079fade250475a6d8d9e9995f8bf4fbebe7fa122ff1972738641a0bb64b2aa13`
- Slave SOF：`artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- 歷史 Programmer checksum：`0x309FA629`
- Slave cable：`DE5 [1-11.2]`

Master 維持：

- historical source baseline：`9f848ec`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`
- Master Programmer checksum：`0x30A46449`
- 角色判準：`status=0xFF、WDIAGS_MODE=2、WDIAGS_PTP=6`

## 成功判準

第一層只確認 image/probe 對應成功：

```text
quartus_stp 可以找到 Sources and Probes
status / marker / mailbox 可讀
Slave probe instance 0、1、7、8、10 可正常讀取
```

第二層觀察，不把它預先當成同步成功：

```text
Master：marker=B004、MODE=2、PTP=6、status=FF、PTP RX/TX 有活動
Slave ：marker=B004、MODE=3、link_up=1、parent metadata 可讀
       SSTAT/PSTAT/UCNT、DCO readback 可讀
```

只有同一觀測窗得到 Slave `PSTAT.locked=1、time_valid=1、pps_valid=1`，才可宣稱完成 White Rabbit synchronization。

## 燒錄 command

```text
quartus_pgm -c "DE5 [1-11.2]" -m jtag -o p;/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-SI5340-READBACK-20260817/DE5a_wr_slave_jtag.sof
```

## MIF / SOF / 燒錄結果

本節於燒錄後立即補入：

- Programmer start/end time
- JTAG ID
- Programmer checksum
- configuration result
- raw programmer log 路徑與 SHA-256

## JTAG/runtime 原始結果

本節於燒錄後補入：

- `status_probe`
- `cpu_marker`
- `WDIAGS_MODE/PTP/PTP_RX/PTP_TX`
- `WDIAGS_SSTAT/PSTAT/UCNT`
- `WDIAGS_FOREIGN_META/PARSE_META`
- DCO state/readback
- correlation raw log 路徑與 SHA-256

## Observation

本節只記錄原始輸出支持的現象，區分「probe 可讀」與「WR synchronization 已完成」。

## Conclusion

本節不可因為 Programmer 成功或 `link_up=1` 就宣稱時間同步完成；必須依照同一觀測窗的 `PSTAT.locked、time_valid、pps_valid` 證據下結論。

## Next Step

若 probe 恢復但 Slave 仍停在 `time_valid=0`，不改 Master role；下一輪只依有效 correlation 結果選擇 Slave 的單一變因。若仍找不到 probe，停止功能判讀，先核對 image 與 JTAG script provenance。

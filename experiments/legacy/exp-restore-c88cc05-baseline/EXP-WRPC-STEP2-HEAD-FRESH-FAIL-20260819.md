# EXP-WRPC-STEP2-HEAD-FRESH-FAIL-20260819

## 實驗識別

- 實驗名稱：`Step 2 fresh HEAD 重現測試（失敗）`
- 日期：2026-08-19
- Branch：`exp/restore-c88cc05-baseline`
- Git HEAD：`2311b4f7cfa683898b3afd913815deff2c9377f2`
- 參考 baseline：`c88cc05712549e49019d189961d3b8beb3b6fd77`
- 實驗目的：確認目前 branch 的最新 HEAD 是否能從 clean checkout、fresh firmware、fresh Quartus compile 產生新的 Master/Slave SOF，並在兩張 DE5a 上重現 Step 2 Endpoint / MiniNIC / PTP packet path。

## 本次相較 baseline 的唯一判斷範圍

本次沒有在實驗前修改 functional code；使用當時 branch HEAD 直接建立 fresh firmware 與 fresh Quartus SOF。相對歷史 `c88cc05` 的差異先分為：

- 文件與 JTAG observability：新增 register/packet/WR runtime 讀值與說明。
- build/reproducibility：build script 保留 `quartus_sh --clean`，並在 compile 前切到 Quartus project 目錄。
- firmware startup：Master/Slave `CONFIG_INIT_COMMAND` 移除阻塞的 `sfp match`，保留 `mode master` / `mode slave`。
- RTL functional delta：加入 625 MHz WR system clock、SI config 後 reset release、`g_softpll_reverse_dmtds => true`，以及相關 clock/reset wiring；這些仍需後續以單一變因方式確認，不能由本次結果直接判定為根因。

本次沒有修改 WR signaling、SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity 或 SI5340 DCO 控制策略。

## Fresh firmware provenance

所有檔案由 pain 上的 clean worktree `/home/b10504072/04_WR_step2_head`、上述 exact HEAD 建立。

### Master

- MIF：`40235dd7a230044d450021bdf171be70d07644bbd9035573643c8158eb09c20a`
- ELF：`dbfd246818fae126c6a5621f0f50d465193519104a40e3edaf9aba74c08eb2e6`
- BIN：`84339a159499c65cde9bc8e46243139ae4b9c7c942c4413b93d007a92a202e79`
- defconfig：`a50d6899e8e29055b8cf2e1926d422ac458a7c3b5ad7e504b04d31e697723556`
- identity header：`c8c8fbaf4c1a7b99c4cad7491a9134e4e0d698ac068b894d5a0ee2d18c06f692`
- startup command：`vlan off;ptp stop;mode master;ptp start`

### Slave

- MIF：`92fffa85260d3afddf2c6542a2fdf6e03965c5cee9399e3eafb39620fa93f7d7`
- ELF：`dd005fc399fc884dd0ade6fbebfe9c9b5fd2d7d242680492dd9e69e5f36ad36d`
- BIN：`b066b08c28d44743800b45afd37b2fbe1baa23a29db73b37700c09d4c9a71d26`
- defconfig：`13c25f47bc00fe2fa2dc1f03c3c5d0262a6b5246fb4d30a34c8135c1d5ae5d81`
- identity header：`33ded2dc62811525a395d12a5a396dda1553339119eba2f37c86cf8cf4639d55`
- startup command：`vlan off;ptp stop;mode slave;ptp start`

## Fresh Quartus build

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Slave QSF：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC（兩者相同）：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF：`4d3b42a3adea67aa38a67986d800d26f2a686cd518674d3e669b08f989166a74`
- Slave SOF：`e6d95f539e5eb8c5896a4f21bc7e81bdae6de25f96f1fe92b8df2ad4afa73bdc`
- Compile：Master/Slave 均 `Full Compilation was successful`
- Timing：兩者 `TIMING_CLOSED=NO`，並有未滿足 timing requirement 的 Critical Warning；這是 build 證據的一部分，不能省略。
- Compile log：
  - `/home/b10504072/04_WR_step2_head/build/quartus_jtag_master_compile.log`
  - `/home/b10504072/04_WR_step2_head/build/quartus_jtag_slave_compile.log`

## 燒錄結果

本次使用的是 exact HEAD fresh build 產生的 SOF，不是 historical `c88cc05` SOF。

- Master cable：`DE5 [1-11.1]`
- Master programmer checksum：`0x30A2F696`
- Master 結果：`Configuration succeeded`，0 errors，0 warnings
- Slave cable：`DE5 [1-11.2]`
- Slave programmer checksum：`0x30A22D41`
- Slave 結果：`Configuration succeeded`，0 errors，0 warnings
- programmer 原始輸出：
  - `/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819/program_master.log`
  - `/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819/program_slave.log`

## JTAG runtime 原始證據

- 單次 snapshot：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819/runtime_snapshot.log`
- 30 秒 session：`/home/b10504072/04_WR_step2_head/build/artifacts/EXP-WRPC-STEP2-MILESTONE-20260819/runtime_timeseries_30s.log`
- JTAG script：`scripts/jtag/read_wb_runtime.tcl` 與 `scripts/jtag/read_wb_timeseries_session.tcl`
- Quartus SignalTap/JTAG script 結果：兩次均 `Evaluation ... was successful`，0 errors，0 warnings。

### Master（DE5 [1-11.1]）

- MAC：`02:00:22:33:44:01`，通過 unique identity gate。
- CPU：reset=0、fault=0、im_valid=1、PC 有活動、marker=`0xB004` 且 seen=1。
- PHY/link：link_up=1、link_ok=1、RX/TX ready 為 1；Endpoint 可運作。
- MiniNIC：`WDIAGS_TX=0x0000009A`、`WDIAGS_RX=0x00000095`，有 frame activity。
- PTP packet：`WDIAGS_PTP_RX=0x52`、`WDIAGS_PTP_TX=0x2D`，有封包活動。
- 失敗：`WDIAGS_MODE=3`、`WDIAGS_PTP=4`（LISTENING），不是要求的 `MODE=2`、`PPS_MASTER=6`。
- 失敗：`WDIAGS_FOREIGN_META=0x0000FF00`，沒有建立可用的 foreign master。

### Slave（DE5 [1-11.2]）

- MAC：`02:00:22:33:44:02`，通過 unique identity gate。
- CPU：reset=0、fault=0、im_valid=1、PC 有活動、marker=`0xB004` 且 seen=1。
- PHY/link：link_up=1、link_ok=1、RX/TX ready 為 1；Endpoint 可運作。
- MiniNIC：`WDIAGS_TX=0x000000A0`、`WDIAGS_RX=0x0000006A`，有 frame activity。
- PTP packet：`WDIAGS_PTP_RX=0x2A`、`WDIAGS_PTP_TX=0x4B`，有封包活動。
- PTP role：`WDIAGS_MODE=3`、`WDIAGS_PTP=9`（PPS_SLAVE），符合 Slave gate。
- Foreign：曾觀察到 `WDIAGS_FOREIGN_META=0x00000001`，代表 foreign count=1、best index=0；但本次 session 中也出現 `0x0000FF00/0x0000FF01`，且 `PARSE_META` 的 parent WR 欄位未形成 `0x03000001`。因此不能把它寫成完整 WR parent success。

## Acceptance table

| Gate | Master | Slave | 判定 |
|---|---|---|---|
| CPU / firmware | PASS | PASS | 兩板 reset=0、fault=0、im_valid=1、marker B004 |
| PHY / Endpoint | PASS | PASS | link/ready healthy |
| Unique MAC | PASS | PASS | `.01` / `.02` |
| MiniNIC activity | PASS | PASS | WDIAGS_TX/RX 有活動 |
| PPSI/PTP activity | PASS | PASS | PTP RX/TX 有活動 |
| PTP role | FAIL | PASS | Master 是 MODE=3/PTP=4，不是 MODE=2/PTP=6 |
| Foreign master | FAIL | PARTIAL | Master 未提供 foreign；Slave 曾看到 count=1，但 parent metadata 不完整且不穩定 |
| Step 2 overall | **FAIL** | **FAIL** | 最新 HEAD 尚未重現 Step 2 |

## Observation

這次證明了：

1. exact HEAD 可以完成 firmware build、clean Quartus compile、雙板 fresh SOF 產生與成功燒錄。
2. fresh HEAD 的 Endpoint、MiniNIC 與 PTP packet path 有實際活動。
3. 但 Master 沒有進入 `PPS_MASTER`，所以 Slave 也無法穩定建立完整 parent/foreign metadata。
4. MIF 內容已確認包含 Master 的 `mode master` startup command；因此目前不能再把問題簡化成「Master MIF 沒更新」。
5. 本紀錄不把 625 MHz/reset wiring、DDMTD reverse option、SI5340 controller 或任何單一差異直接宣稱為根因，需下一輪單一變因實驗確認。

## Conclusion

證據只支持以下結論：

> `exp/restore-c88cc05-baseline` 的 HEAD fresh build/program 流程成功，但 Step 2 acceptance 尚未通過。Master role regression 是目前最直接的阻塞點；Slave 的 PTP packet receive 與 foreign discovery 有部分活動，但不能取代 Master=PPS_MASTER 的必要條件。

本次不標示 `READY_TO_MERGE`，也不允許 merge 到 `main`。

## Next Step

1. 保留本次 SOF、programmer log、snapshot 與 30 秒 time-series。
2. 以 `c88cc05` 及已知 `9f848ec` role 行為作為 reference，逐項比對 Master startup command 是否實際執行，以及 current HEAD 的 clock/reset functional delta。
3. 每次只修改一個 role/initialization 變因，重新產生 fresh MIF/SOF 並重新燒錄。
4. 下一次燒錄前先 commit；燒錄後立即新增成功或失敗的實驗紀錄。

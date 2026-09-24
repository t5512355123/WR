# EXP-S5-WR-SLOCK-TRACE-39B6D2A-20260913

## 結論

`STEP5 = NOT COMPLETE`。

這次使用完整韌體重建後的 `39b6d2a8017cfb40f2fd060856fdf16a05697a79` 映像，在 Pain 上完成 Master/Slave full compile、燒錄與約 600 秒觀測。Slave 的 WR extension 於 `208752 ms` 首次進入 failure，原因欄位為 `WR_S_LOCK_TIMEOUT`；雖然之後 SoftPLL 在 `575023 ms` 達到 `SEQ_READY`、Main frequency/phase/overall lock 全為 1，且 `PSTAT_LOCKED=1`，WR extension 已經停在 `PPSI_PDSTATE=FAILURE` / `PPSI_EXTSTATE=PTP`，因此不能算 Step5 closed-loop lock。

## 實驗身分

- Branch: `exp/step5-softpll-lock`
- Source commit: `39b6d2a8017cfb40f2fd060856fdf16a05697a79`
- Board: `DE5 [1-11.2]`，Slave
- Trial: `EXP-S5-WR-SLOCK-TRACE-39B6D2A-20260913`
- Observer exit: `0`
- Observer duration: `601592 ms`
- Samples: `280`
- Sample errors: `0`
- Cold power-cycle: 本輪沿用已完成的實體重開基線；本輪燒錄後未再重啟

## Build / program gate

- Master firmware 與 Slave firmware 均重新建立。
- Master/Slave Quartus full compilation 均成功。
- Master/Slave programming 均成功，均為 `0 errors, 0 warnings`。
- Master MIF SHA256: `d991cc412c759e8da29d4181cf442e7135ffb0b04e77483ea43ab975b8361b06`
- Slave MIF SHA256: `32363acb1271fd339f72121b3f5ed627efa556f0649e40a87b55c00f3d526556`
- Master SOF SHA256: `afb57863f98166cfcb43f69a5b330f62e7b513a906905043f6f90311c7fea8f9`
- Slave SOF SHA256: `08474ee89313e340a1bd3d2cb56e0c44612aa59306aec49857a9ff7ae292b1eb`
- Timing closed: `NO`; Master WNS `-0.058 ns`、Slave WNS `+0.015 ns`

## 可靠硬體證據

### Upstream / Step4B

- First core link: `498 ms`
- First DMTD accepted activity: `498 ms`
- First TAG/TRR write/TRR pop/IRQ/Helper update: `498 ms`
- `RXERR_COUNT=0`，觀測期間沒有因 CPU、WR core 或 SI configuration 造成的新增 reset/drop。

### WR extension failure

- `208752 ms`: `PPSI_PDSTATE=FAILURE`、`PPSI_EXTSTATE=PTP`、`WR_STATE=WRS_IDLE`
- `WR_FAILURE=02020001`
- `WR_LOCK_RESULT=... fail_reason=3(WR_S_LOCK_TIMEOUT)`
- 後續仍保持 `WR_STATE=WRS_IDLE`；因此後段 SoftPLL lock 不等於 WR extension 成功。

### SoftPLL 後段

- Helper first locked: `47965 ms`，期間可反覆掉鎖。
- Main enabled: `45730 ms`
- Main phase first locked: `54663 ms`
- SoftPLL `SEQ_READY`: `575023 ms`
- Main frequency / phase / overall lock: `575023 ms`
- `PSTAT_LOCKED`: `575023 ms`
- 但上述成立時 WR extension 已早在 `208752 ms` 失敗，故不能判定 Step5 PASS。

## 本輪診斷資料的有效性

本輪新增的 `SLOCK_TRACE_*` 不可用於定位 S_LOCK 內部邊界，原因已由 source audit 確認：

1. 韌體 `BASE_WDIAGS_PRIV = DEV_BASE + 0xa00 = 0x00100a00`；offset `0x158..0x16c` 的正確 CPU 位址是 `0x00100b58..0x00100b6c`。
2. 本輪 observer 卻讀取 `0x00100158..0x0010016c`，讀錯了 MMIO 位址；因此輸出的 `C80001AC` / `UNKNOWN` 不能視為 S_LOCK stage。
3. 即使修正位址，`0x158..0x1dc` 仍是 legacy lock-wait、Main frequency 與 Helper PI overlay 共用區。Main frequency trace 啟動後會覆寫同一區域，因此需要另外設計不重疊的 S_LOCK record，不能直接沿用目前六個獨立欄位。

所以本輪的可信結論只有：`WR_S_LOCK_TIMEOUT` 仍可由既有 WR failure/result sticky 欄位確認；S_LOCK entry/retry/remaining/poll 的細節尚未取得可信證據。

## 下一步

下一輪只做 diagnostic correction，不修改 PI、SoftPLL、WR handshake、timer 或 arbiter：

- 修正 observer 讀址至 `0x00100b58..0x00100b6c`。
- 重新設計不會被 Main frequency/Helper PI overlay 覆寫的單一 S_LOCK sticky record，或明確停用衝突 overlay 後再測。
- 先用 60 秒 smoke 確認 record 的 magic、stage、generation 與 timestamp 可讀且不會漂移，再進 600 秒 first-loss 觀測。
- 在診斷證據可信前，不進行新的 timeout/PI sweep，也不修改 production control semantics。

## 原始檔案

- `raw/observer-39b6d2a.log`
- `raw/build_info_jtag_master.txt`
- `raw/build_info_jtag_slave.txt`
- `raw/build-jtag-master-39b6d2a.log`
- `raw/build-jtag-slave-39b6d2a.log`
- `raw/program-master-summary.log`
- `raw/program-slave-summary.log`
- `raw/checksums.sha256`

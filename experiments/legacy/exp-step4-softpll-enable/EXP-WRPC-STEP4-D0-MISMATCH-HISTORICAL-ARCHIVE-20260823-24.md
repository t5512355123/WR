# EXP-WRPC-STEP4-D0-MISMATCH-HISTORICAL-ARCHIVE-20260823-24

## 判定與範圍

本文件記錄從 Pain 的 `/home/b10504072/04_WR_untracked_backup/` 找回並整理的
Step4 D0 mismatch 歷史證據。這是資料保全／歸檔，不是新的 compile、program
或硬體觀測，也不新增任何 Step milestone PASS 判定。

```text
PRESERVATION_ONLY = YES
NEW_HARDWARE_RUN = NO
STEP4_MILESTONE_PASS = NOT_ESTABLISHED_BY_THIS_ARCHIVE
STEP4B_STEP5_STEP6_PASS = NOT_CLAIMED
```

## 保全與去重核對

Pain 備份原有 139 個檔案：99 個非 SOF/MIF 檔案與既存的
`exp-step4-softpll-enable/raw/` 檔案逐一 SHA-256 相同；0 個內容不同；36 個
非 SOF/MIF 檔案原先未在實驗資料夾中，已放回下列原始實驗路徑並逐檔驗證
SHA-256 相同。兩個 `.sof` 與兩個 `.mif` 為可重建的非 milestone 輸出，未複製
進 GitHub；原 SOF/MIF 雜湊及 build provenance 仍保存在原始 manifests 與本報告。

搬運用 archive SHA-256：

```text
5489f3362b856ab78079829229c623ea2f5f9b855813c9640167a9be416a539e
```

保留下來的原始資料：

- [`EXP-WRPC-STEP4-D0-MISMATCH-20260823`](raw/EXP-WRPC-STEP4-D0-MISMATCH-20260823/)
- [`EXP-WRPC-STEP4-D0-MISMATCH-FULL-20260824`](raw/EXP-WRPC-STEP4-D0-MISMATCH-FULL-20260824/)

## 來源與排除的中間映像

2026-08-23 mismatch run 的 build retry provenance 記錄：

```text
GIT_COMMIT = 2fc60f9955b4ded96d025eb663f348e980e3a926
```

2026-08-23 pre-build provenance 記錄的 source commit 為
`bfd9046ee4674346daaabc8f980c0c1bc5d2301b`。2026-08-24 full run 的 build
provenance 記錄：

```text
GIT_COMMIT = 2ecd38d4e6d980907f227492ea09bf38835714d4
QUARTUS = 17.0.0 Build 595
TIMING_CLOSED = NO
```

Full run 中未保留的 SOF/MIF 雜湊：

| Image | SHA-256 |
|---|---|
| Master SOF | `17057a4271a6f92db91b4dbb9a2c8ae59fc90a20e6890987df395bf738f2fc70` |
| Slave SOF | `390a3b2900d48a102deb1bfb1be0ba8e8ae45ab31808b1ea2edb7ac8e35d8ec9` |
| Master MIF | `b6f09e752738457e0f6321fc58754517733c289b1f161498ec4ee55574f6c04f` |
| Slave MIF | `450f64e4e3ecf67379738350895d43e5ac7e8dfcc11645da9b1f036a01d9adf1` |

這些是 D0 mismatch 診斷 run 的中間映像，並非已驗證的 Step4B、Step5 或 Step6
可重現 milestone，因此不保留 SOF/MIF 二進位檔。原始 `master_hashes.sha256`
與 `slave_hashes.sha256` 留在 full-run raw 資料夾，以保留當時記錄格式及
provenance。

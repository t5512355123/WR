# Merge Readiness Audit：`exp/restore-c88cc05-baseline`

最後整理：2026-08-19

## 結論

**NOT READY TO MERGE**

目前實機驗證的是 historical `c88cc05` clean SOF，不是目前 branch HEAD 的 fresh build。即使文件與 Git 狀態整理完成，在完成以下三件事以前仍不能 merge 到 `main`：

1. 以目前 branch HEAD 重新產生 Master/Slave firmware、MIF 與 SOF。
2. 實際燒錄 fresh HEAD SOF，保存 programmer 結果與 Master/Slave SOF SHA256。
3. 使用與該 fresh HEAD 對應的 `read_wb_runtime.tcl`，重現 JTAG runtime 結果，並與 historical c88cc05 baseline 做可追溯比較。

本次沒有 merge、squash、rebase 或修改 `main`。本次也沒有修改 functional RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control。

## Audit scope

- branch：`exp/restore-c88cc05-baseline`
- audit 前 HEAD：`0275c0a`（`補正c88cc05實驗來源追溯資訊`）
- remote：`origin/exp/restore-c88cc05-baseline`
- main baseline：`origin/main` / `191006c`
- historical reference：`c88cc05`
- 本次預計提交的文件：`STATUS.md`、`docs/debug/jtag_register_map.md`、`docs/MERGE_READINESS.md`

## 指定 Git 指令結果

以下是文件修改後、尚未提交文件時，在 audit 前 HEAD `0275c0a` 執行的原始結果。

### `git status`

```text
On branch exp/restore-c88cc05-baseline
Your branch is up to date with 'origin/exp/restore-c88cc05-baseline'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
	modified:   STATUS.md
	modified:   docs/debug/jtag_register_map.md

no changes added to commit (use "git add" and/or "git commit -a")
```

### `git log --oneline --decorate -20`

```text
0275c0a (HEAD -> exp/restore-c88cc05-baseline, origin/exp/restore-c88cc05-baseline) 補正c88cc05實驗來源追溯資訊
f276133 記錄c88cc05基準恢復燒錄與JTAG結果
cb49323 建立c88cc05基準恢復研究分支
d19e0a9 (origin/exp/master-9f-observability, exp/master-9f-observability) 整理分支實驗紀錄與建立規則
f17c4be 補記WR握手聚焦觀測結果
cb2c2ef 修正WR聚焦觀測狀態寬度
e1f953a 新增WR握手聚焦唯讀觀測
adda4e7 補記Slave lock correlation結果
c0d0621 補記Slave probe smoke測試結果
9116b61 記錄Slave probe基線燒錄成功
30a530e 建立Slave probe相容基線實驗
5ee0281 補記Slave可觀測基線執行結果
3a47686 記錄Slave可觀測基線燒錄成功
43a6c06 建立Slave可觀測基線恢復實驗
a5a2773 補記positive-control觀測介面缺失
a30abca 補記Slave positive control燒錄證據
184631d 建立Slave positive control恢復實驗紀錄
8ec9bcc 補記Slave伺服器關聯觀測證據
39d15d5 補強Servo與DCO唯讀關聯觀測
0b331a4 修正DCO唯讀腳本並補記握手實驗
```

### `git diff main...HEAD --stat`

```text
error: Could not read aef63f8916c94e088f9595741025009d7d38c622
error: could not parse commit aef63f8916c94e088f9595741025009d7d38c622
fatal: ambiguous argument 'main...HEAD': unknown revision or path not in the working tree.
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<path>...]'
```

### `git diff c88cc05...HEAD --stat`

```text
error: Could not read aef63f8916c94e088f9595741025009d7d38c622
error: could not parse commit aef63f8916c94e088f9595741025009d7d38c622
fatal: ambiguous argument 'c88cc05...HEAD': unknown revision or path not in the working tree.
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<path>...]'
```

## Audit interpretation

1. branch 與 remote ref 一致，且目前沒有功能性 source 修改被意外帶入；audit 時只有兩份文件待提交。
2. `git diff` 兩個指定比較都因本機 Git object database 缺少 `aef63f8916c94e088f9595741025009d7d38c622` 而無法產生統計。這是 repository history/object integrity 問題，不應用 `reset --hard`、rebase 或刪除 refs 來掩蓋。
3. 在 diff 統計可重建、fresh HEAD build/program/runtime reproduction 完成以前，merge readiness 必須保持 NOT READY TO MERGE。
4. historical c88cc05 的硬體證據仍保留在 `docs/experiments/exp-restore-c88cc05-baseline/` 與對應 artifact provenance；不能把那次 SOF 的成功結果當成 HEAD 已驗證。

## Merge gate checklist

- [ ] 補回或由 GitHub 來源確認缺少的 object，讓 `git diff main...HEAD --stat` 與 `git diff c88cc05...HEAD --stat` 正常完成。
- [ ] 以 HEAD fresh build 產生 Master/Slave MIF、firmware image 與 SOF。
- [ ] 保存 Quartus version、source commit、branch、MIF SHA256、SOF SHA256、programmer checksum。
- [ ] 燒錄 fresh HEAD SOF，保存 Master/Slave programmer raw log。
- [ ] 執行對應 decode script，保存完整 JTAG raw log 與 script commit/blob SHA256。
- [ ] 重新確認 `MODE`、`PTP`、PTP RX/TX、foreign/parent metadata、`PSTAT.locked`、`time_valid`。
- [ ] 確認此次結果與文件中的 historical c88cc05 結果沒有被混用。
- [ ] 由 reviewer 檢查後才建立 merge commit 或 pull request。

# EXP-WRPC-MASTER-SIGNAL-OBS-COMPILE-20260818

## 基本資訊

- 實驗名稱：Master `9f848ec` 加入 signaling observability 的 compile preflight
- Experiment ID：`EXP-WRPC-MASTER-SIGNAL-OBS-COMPILE-20260818`
- 日期：2026-08-18
- Git branch：`exp/master-9f-observability`
- Git commit：`d512add`
- Quartus：Quartus Prime 17.0 Build 595
- 結果：**compile preflight 失敗，沒有產生可宣稱的新 Full Compilation，也沒有燒錄**

## 這次想驗證什麼

在不改變 `9f848ec` Master role、startup command 或任何同步參數的前提下，重新建立包含最新 signaling observability 的 Master build，之後才進行 Master-only A/B。

## 唯一變因

本輪沒有修改 source 或硬體設定，只執行既有建置 wrapper。建置過程先產生了新的 firmware MIF，接著在 Quartus clean 階段失敗。

## 執行命令

```text
cd /home/b10504072/04_WR
./scripts/pain/pain_build_jtag_master.sh
```

保存的原始輸出：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/compile.log
/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-SIGNAL-OBS-20260818/quartus_compile.log
```

Quartus log SHA-256：

```text
b8fe59a200d02bc5a1358574f110a6aa23ff17ce4e2b5b67af4b5ffc849f1d77
```

## 原始錯誤

```text
Error: Cannot clean project /home/b10504072/04_WR/DE5a_wr_master_jtag: this project doesn't exist
Error (23031): Evaluation of Tcl script .../qsh_clean.tcl unsuccessful
Error: Quartus Prime Shell was unsuccessful. 2 errors, 0 warnings
```

原因是 `scripts/build/build_jtag_master.sh` 在 repository root 執行：

```bash
quartus_sh --clean "$PROJECT.qpf"
```

但 `DE5a_wr_master_jtag.qpf` 位於 `quartus/jtag_runtime_diag/`，因此 Quartus clean 階段找不到專案。這是建置 wrapper 的工作目錄錯誤，不是 FPGA role 或 WR runtime 證據。

## 產物判定

firmware build 已重新產生 MIF：

```text
MIF SHA-256: 87c1fcc2de6098333e0af5e43dd6b9a9210b360210f2a771c9412529ac3d7cd0
```

但 Quartus 沒有完成 clean/compile；artifact 目錄中同時存在的 SOF 是先前檔案，不能視為本輪產生，也不能燒錄使用。

## Conclusion

本輪只證明建置腳本在 Quartus clean 階段有路徑 bug；沒有新增可驗證的硬體結果，也沒有改變或驗證 Master role。

## Next Step

只修正 `build_jtag_master.sh` 的 Quartus project path，使 clean 與 compile 都在 `quartus/jtag_runtime_diag/` 執行；修正後重新 compile，保存新的 QSF/SDC/MIF/SOF/hash 與 timing 結果。compile 成功後才考慮 Master-only programming，且仍保留歷史 `9f848ec` SOF 作為 rollback/A-B 基準。


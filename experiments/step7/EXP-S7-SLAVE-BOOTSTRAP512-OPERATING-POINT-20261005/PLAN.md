# Step7 Slave 粗調工作點：512-step candidate

## 基線、唯一變因

Production baseline 是 `f3b2acb60a87018e62d264acc4125be06c13c57d`；先完整撤回上一輪未成功的 SI5340 reset intervention。

相對此基線，唯一 production 控制變因是 Slave `STEP5_BOOTSTRAP_STEPS: 3388 → 512`。Master、reset/PHY、Helper/Main PI、code-per-step=64、8 秒 guard、WR servo `/2+/12`、60/120 ps 不變。腳本僅保留 Step7 logs 分類，milestone/archive 唯讀。

## 為何選此工作點

原供電拓樸改變後的 3388 版本有 Slave frequency-error scalar +543..+577（中位約 +575）、DAC output=5、normal request/completion=0；現有 fine loop 無法向低於 5 的方向修正。實際 coarse counter 3388 是 FINC，不依歷史命名猜方向。

歷史 `EXP-WRPC-STEP5-HPLL-PLANT-ID-5632-20260909` 量到 FINC +886 /4096、FDEC −890 /4096，約 +0.216 error/FINC step。只把它當 provisional seed，不宣稱它是現在的實測 slope。

估算 512 的 initial error：`575 + (512−3388)*0.216 ≈ −46`。若舊 slope 仍適用，約 213 個正向 fine steps（code 約 13600）能回到 zero crossing，落在 5..65531 的可控制範圍；原 fine code range 約容納 1024 physical steps。

這是針對 rail/headroom 的單一工作點實驗，不是 gain sweep，也不宣稱移出 PCIe 已證明改變了 oscillator 頻率。外接供電電壓、溫度、實際 reference frequency 都未量測。

## 流程與停止

Laptop 修改/test/push → Pain pull exact source，既有 build/compile/program 四步 → 單 owner 只讀 preflight/Helper → TIME_VALID capture → raw/results 回 Laptop，REPORT/push。

先恢復 TX/RX/link；上游 gate 無效不進 300 秒。若 link 無法恢復、reset/generation 改變、transport 無效、或粗調已完成但持續 rail，保存 evidence，停止此候選，不靠延長觀測當 PASS。

最多 900 秒 acquisition。取得兩板 TIME_VALID 後既有 verifier 各觀測 303 秒、每筆 STATUS_TIME_VALID=1、span >=300000 ms、gap <=1000 ms、至少 301 samples 才 PASS。兩板 sequential，不宣稱 physical SMA skew 或 offset <60 ps。

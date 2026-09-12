# EXP-WRPC-STEP5-PROVENANCE-CORRECTION-KP-20260912

## 目的

本紀錄修正最近三輪 Step5 closed-loop 報告的 firmware provenance，避免把錯誤的 Helper PI 參數標籤當成 A/B 結論。

## 對帳結果

16b38ce 將 vendor/wrpc-sw/softpll/spll_helper.c 的 Node 端：

    s->pi.kp = -150;

改成：

    s->pi.kp = -125;

之後的 84b25fd、988e777、94f135d 只修改 Slave top-level 的 STEP5_NORMAL_HPLL_COOLDOWN_LOADS，沒有把 Helper Kp 恢復成 -150。因此在這三個 commit 產生的 bitstream 中，實際 firmware Helper Kp 應判定為 -125，不是報告標題及 observer metadata 所寫的 -150。

目前已由 source audit 確認：

    HEAD before correction = c5ad141
    HEAD source Helper Kp = -125
    Main Kp = +300
    Helper Ki = -1
    bootstrap = 3388
    code_per_physical_step = 64

## 受影響紀錄

以下紀錄的硬體結果仍然是真實觀測資料，但 Helper Kp=-150 標籤不可信，必須重新分類為 Helper Kp=-125 加上各自的 cooldown：

    84b25fd / cooldown64
    988e777 / cooldown16
    94f135d / cooldown8

所以它們不能用來宣稱「Kp=-150 的 cooldown scan 已完成」，也不能用來排除 Kp=-150 的 cooldown=0 baseline。

8e320e4 的 Kp=-125、cooldown=0 有效 recovery 觀測則維持有效，因為該 commit 的 source 與報告標籤一致。

## 修正動作

下一個硬體候選已修正為可信 baseline：

    experiment = EXP-WRPC-STEP5-TRUE-BASELINE-3388-MAIN-KP300-HELPER-KP-MINUS150-COOLDOWN0-20260912
    Helper Kp = -150
    Helper Ki = -1
    Main Kp = +300
    Main Ki = +1
    bootstrap = 3388
    reverse = 1
    code_per_physical_step = 64
    STEP5_NORMAL_HPLL_COOLDOWN_LOADS = 0

Observer metadata 也同步改成相同設定。此 correction 不改變 Step5 判定門檻，也不把任何短暫 lock 視為 PASS。

## 判定

在可信 baseline 重新完成 cold/recovery preflight 與 3600-snapshot coherent observer 之前：

    STEP5 = NOT VERIFIED
    MERGE_APPROVED = NO

本 correction report 是 provenance 修正，不是 Step5 PASS 報告。

# EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817

## 實驗名稱

固定 `9f848ec` Master role 的最新 observability diagnostic baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-DIAGNOSTIC-BASELINE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗類型：已知成功 Master 映像重燒錄與 runtime baseline

## 想驗證什麼

在不發明新的 Master role 切換方法的前提下，重新確認歷史成功 baseline 的五項證據：

1. CPU marker 為 `B004`；
2. `WDIAGS_MODE=2`；
3. `WDIAGS_PTP=6`；
4. link up 且 status low byte 為 `0xFF`；
5. PTP RX/TX counter 持續增加。

這五項只用來固定 Master diagnostic baseline，不等於宣稱兩張 DE5a 已完成 White Rabbit 時間同步。

## 相較 baseline 唯一修改

沒有修改。使用已知成功的 `9f848ec` Master role 與目前已驗證可工作的 observability SOF；本次唯一操作變因是重新燒錄同一個 Master SOF 並重新讀取 runtime。

## Git / bitstream provenance

- Branch：`exp/master-9f-observability`
- Git commit：`待燒錄完成後填入`
- Master role 基底：`9f848ec84b73328daca63b64d2725817e8802e60`
- Quartus：Quartus Prime 17.0 Build 595
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`1a3362b453b156bfb1b301870f2a0b3e3491f6cf41e9c40567ed6358dff402db`

## 燒錄結果

燒錄完成後立即填入：

```text
Programming cable:
JTAG ID:
Programmer checksum:
Configuration result:
Raw programmer log:
```

## JTAG/runtime 原始結果

燒錄完成後立即填入 marker、status、role、PTP counters 與觀測時間窗。

## Observation

待實驗完成後填入，不預先假設結果。

## Conclusion

待實驗完成後填入，只寫證據真正支持的內容。

## Next Step

若五項判準全部通過，保存此 Master image 並固定 Master；後續只研究 Slave parent/servo/SoftPLL 路徑。若任一項失敗，不修改 Slave，先回到 Master provenance 與 startup command 差異核對。

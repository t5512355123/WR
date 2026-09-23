# Programming record (operator summary)

The original Quartus Programmer console output was not saved as a standalone
raw log. These values are transcribed from the captured programming result;
the build identity and hashes are independently preserved in `../build/`.

```text
PROGRAM_ORDER = SLAVE THEN MASTER
SLAVE_CABLE = DE5 [1-11.2]
SLAVE_SOF_SHA256 = 4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca
SLAVE_PROGRAMMER_CHECKSUM = 0x30B1E229
SLAVE_RESULT = Configuration succeeded; 1 device configured; 0 errors

MASTER_CABLE = DE5 [1-11.1]
MASTER_SOF_SHA256 = 6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845
MASTER_PROGRAMMER_CHECKSUM = 0x30B18F28
MASTER_RESULT = Configuration succeeded; 1 device configured; 0 errors
```

Each board was programmed once. No retry or physical power cycle was used.

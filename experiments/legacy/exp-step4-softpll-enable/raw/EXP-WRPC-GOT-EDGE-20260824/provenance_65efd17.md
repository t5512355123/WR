# EXP-WRPC-GOT-EDGE-20260824 Provenance

## Build

- Branch：`exp/step4-softpll-enable`
- Git HEAD：`65efd17da85cdff92e438f44a5d8fb1b65563af2`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Master MIF SHA-256：`a3d6f9024ecc3ede7f002e1f5ab8322ebb2ae8c2cbc5e175b556156e6e1e4225`
- Slave MIF SHA-256：`a613655f723be9a850cd1a63b76fb93ea885c2b6dcf58e26a61d21323496dcb0`
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA-256：`f3dfed9f05f95f052ae2e6d6cd5f03d16148deda98470deb510c31fb393e4e51`
- Slave SOF SHA-256：`ad489069dac068d95f503902ff0f7010e2c525bede56eb563109b3d704ba9806`

兩片均以 `quartus_sh --clean` 後重新編譯；Master/Slave 均顯示 compilation 成功。兩個 compilation 的 timing closed 仍為 `NO`，這是本次 image 的既有 timing caveat，不是本次 runtime regression 的判定依據。

## Programming

- Master：JTAG ID `0x02E660DD`，programmer checksum `0x30B06E5A`，`configuration succeeded`，0 errors、0 warnings。
- Slave：JTAG ID `0x02E660DD`，programmer checksum `0x30B1E80D`，`configuration succeeded`，0 errors、0 warnings。
- 燒錄後等待約 60 秒才開始 read-only regression。

## Read-only logs

- `step23_got_edge_65efd17.log`：20 samples、500 ms interval。
- `step4_got_edge_65efd17.log`：10 samples、500 ms interval。

本機 log SHA-256：

- Step 2/3：`378F3BE9AFA1A1D04865CD01D2C5CC0AF2FDEC840AE1048759106273E30092DB`
- Step 4：`63A1456753C93ECE01E4DE783EC6800AB2815B4DF73DD9119CDD4291D6F4CF2E`

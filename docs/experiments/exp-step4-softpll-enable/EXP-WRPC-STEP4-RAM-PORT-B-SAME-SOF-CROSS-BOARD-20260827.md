# EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827

## 實驗目的

依分支 2 對 `04c3241` 的單一步驟建議，固定同一份已知會在 Master image 產生錯誤 q_b 的 SOF，分別 fresh-program 到兩片 DE5，再用相同的 first-load port-A/raw-q_b reader 觀察結果是否跟著 image 或 physical board 走。

本輪不修改 RTL、不重新編譯、不修改 RAM mode/latency/reset/read-during-write 設定，也不碰 parser 或 Step4。

## 固定 image

兩片都使用完全相同、byte-identical 的 Master SOF：

- image：`DE5a_wr_master_jtag.sof`
- SOF SHA-256：`d94cc19d0bd198b52b818e935df3b82e9df54de6583dc39de0eb39905f7b5102`
- SOF checksum：`0x30B32BFA`
- reader：`scripts/jtag/read_cpu_ram_port_a_activity_diag.tcl`

## Runtime evidence

| Physical board | Image | PORT_A_ADDR | PORT_A_WE | PORT_A_BWE | PORT_B_ADDR | PRIMITIVE_Q_B_AT_FIRST_LOAD | SAME_ADDR | INTERNAL_LOAD |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `DE5 [1-11.1]` | same Master SOF | `0x00000040` | `0` | `0xF` | `0x0001C304` | `0x00017956` | `0` | `1` |
| `DE5 [1-11.2]` | same Master SOF | `0x00000040` | `0` | `0xF` | `0x0001C304` | `0x00017956` | `0` | `1` |

兩片各自再讀取一次，repeat 結果完全相同。四次 reader 均為 `0 errors, 0 warnings`。

原始 reader 輸出：

- [`read_board1_master_image.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board1_master_image.log)
- [`read_board2_master_image.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board2_master_image.log)
- [`read_board1_master_image_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board1_master_image_repeat.log)
- [`read_board2_master_image_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board2_master_image_repeat.log)

## 判讀

1. 原本的 image/board 配對是 Master SOF → Board 1 → `0x17956`、Slave SOF → Board 2 → `0x17938`。
2. 將完全相同的 Master SOF 改燒到 Board 2 後，Board 2 也讀到 `0x17956`；Board 1 維持 `0x17956`。重讀仍一致。
3. 因此本實驗的錯值是跟著 **Master SOF image/fitted implementation** 走，而不是跟著這兩片 physical board 的 board identity 走。結合 `04c3241`，port-A 同址寫入碰撞仍沒有證據；結合 `03c5f90`，錯值仍直接存在於 raw primitive q_b。
4. fault boundary 現在應優先集中在 Master image 內的 fitted RAM implementation、primitive configuration、MIF/image-dependent implementation、netlist placement/routing 或其 image-specific elaboration；physical board-specific root cause 在本實驗中被大幅削弱，但不能宣稱所有硬體因素已完全排除。

## Provenance

- source branch：`exp/step4-softpll-enable`
- source/build commit：`0b3b012df2697e785431a43f8ca77cd5f0f94a14`
- Master SOF SHA-256：`d94cc19d0bd198b52b818e935df3b82e9df54de6583dc39de0eb39905f7b5102`
- Master SOF checksum on both boards：`0x30B32BFA`
- both JTAG IDs：`0x02E660DD`
- Board 1 programming：successful，0 errors/0 warnings
- Board 2 programming：successful，0 errors/0 warnings
- reader initial/repeat on both boards：successful，0 errors/0 warnings

燒錄與 reader 證據及雜湊見 [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/build_provenance.txt) 與 [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/artifact_sha256.txt)。

## 限制與後續

- 這是兩片 board、同一份 Master SOF 的 cross-board reproduction；它證明本次 observed divergence 跟著 image 走，但不等於已經定位到 primitive configuration、MIF、placement/routing 或某一條 physical net 的唯一 root cause。
- 本輪只重用既有 probes 23–25 與 reader，沒有重新編譯，因此沒有新增硬體觀測點。
- 下一步應交由分支 2 根據 image-following 結果選擇單一 image/fitted-primitive 差異診斷；在新建議前不要先修改 RAM mode 或加入 workaround。

## 原始證據

- [`artifact_sha256.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/artifact_sha256.txt)
- [`build_provenance.txt`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/build_provenance.txt)
- [`program_board1_master_sof.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/program_board1_master_sof.log)
- [`program_board2_master_sof.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/program_board2_master_sof.log)
- [`read_board1_master_image.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board1_master_image.log)
- [`read_board2_master_image.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board2_master_image.log)
- [`read_board1_master_image_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board1_master_image_repeat.log)
- [`read_board2_master_image_repeat.log`](raw/EXP-WRPC-STEP4-RAM-PORT-B-SAME-SOF-CROSS-BOARD-20260827/read_board2_master_image_repeat.log)

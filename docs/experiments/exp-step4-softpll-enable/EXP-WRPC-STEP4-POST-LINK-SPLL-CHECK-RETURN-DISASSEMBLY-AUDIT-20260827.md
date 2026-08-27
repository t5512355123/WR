# EXP-WRPC-STEP4-POST-LINK-SPLL-CHECK-RETURN-DISASSEMBLY-AUDIT-20260827

## 結論

本輪依分支 2 最新指示，對上一輪實際建置、燒錄與測試所使用的 exact Master `wrc.elf` 做 read-only post-link audit；沒有修改 RTL、韌體功能、診斷 marker，也沒有重新編譯。

最終 ELF 的 machine order 確實是：

```text
S4_STORE 0x4364
    -> ret 0x4400
    -> caller resume 0xE044
    -> S5_STORE 0xE050
    -> persistent publish 0xE060
    -> lock-wait substage-2 call 0xE078
```

因此：

```text
ACTUAL_MACHINE_ORDER=S4_STORE->RETURN->CALLER_RESUME->S5_STORE
MACHINE_RETURN_HANDOFF_BOUNDARY=SUPPORTED
ROOT_CAUSE=NOT_PROVEN
```

硬體實驗中觀察到 S4、沒有 S5，不能歸因於 compiler 把 S4/S5 重排或把 `spll_check_lock()` inline 掉；下一個若要繼續，才有理由在 machine-level return/caller handoff 附近查 persistent trap/fault PC。

## Artifact provenance

本 audit 使用與 `EXP-WRPC-STEP4-PERSISTENT-SPLL-CHECK-LOCK-CALLER-RETURN-20260827` 相同的 Master firmware provenance：

```text
source_commit=03795139d511d10cb9c5a43859ef6340b7421459
wrc.elf_sha256=258c614d321bbdec5348b54e0b2377cd19f13514512d5574a924050ebc6b0118
master_wrc.mif_sha256=c675d6046246d610bdc88a95b134eb7392316880ba58b1a624eba103f508d012
master_sof_sha256=c8bb92cdc531bc0e33fd152168c023f0befdfb536636180c6fea5becd8bfc8e9
```

Build artifact 沒有產生獨立 linker `.map` 檔；本輪以 exact ELF 的 symbol table、section headers、完整 objdump 與保存的 ELF binary 作為 provenance/evidence。

## Symbol resolution

Compiler/linker 將 `spll_check_lock()` 產出為 linked clone：

```text
000043a4  .hidden spll_check_lock.part.0       size=0x60
0000dfb4  wrpc_spll_check_lock_with_timeout    size=0x200
00004330  .hidden wdiags_write_spll_check_lock_debug.constprop.0
```

`spll_check_lock.part.0` 不是 inline 到 caller；caller 在 `0xE040` 有明確 `jal ra,43a4`。

## Machine-order evidence

### S4 inside `spll_check_lock.part.0`

在 `0x43E4` 設定 marker stage 4，並於 `0x43E8` 呼叫診斷 helper：

```text
43e0:  mv    a1,s0
43e4:  li    a0,4
43e8:  jal   ra,4330 <wdiags_write_spll_check_lock_debug.constprop.0>
```

helper 在 `0x4364` 將 stage value 寫入 `.debug_precrt` 的 SPLL stage word：

```text
4364:  sw    a0,0(a5)   # debug_precrt_persistent_spll_check_lock_stage
```

之後 `spll_check_lock.part.0` 進入真正的 epilogue，並在 `0x4400` 執行 `ret`：

```text
43ec:  lw    ra,12(sp)
43f0:  ...
43fc:  addi  sp,sp,16
4400:  ret
```

### Caller resume 與 S5

caller 的 call 位於 `0xE040`；return address 是 `0xE044`：

```text
e040:  jal   ra,43a4 <spll_check_lock.part.0>
e044:  lw    a5,80(s5)   # read persistent SPLL stage
e048:  mv    s3,a0        # consume function result
```

caller-side S5 body 被 compiler inline，但順序清楚可見：

```text
e04c:  bne   a5,s7,e064
e050:  sw    s8,80(s5)   # stage 5
e054:  sw    zero,84(s9) # channel 0
e058:  lw    a5,28(s10)  # current boot generation
e05c:  sw    a5,92(s11)  # stage generation
e060:  jal   ra,4200     # publish persistent record
e064:  ...
e074:  li    a0,2
e078:  jal   ra,5110     # lock-wait substage 2
```

這證明 S5 並不是函式內 return 前的另一個 source-level call；它位於 caller resume 之後、lock-wait substage 2 之前。

## 判讀

上一輪硬體觀測的 `S4=yes / S5=no / lock-wait substage=1` 與這個 machine order 相容：S4 store 已執行，而從真正 `ret` 到 caller-side S5 store 之間沒有形成持久化 S5 evidence。這支持把目前未跨越的 boundary 保留在 machine-level return/caller handoff；但僅憑這份靜態 audit，仍不能判定是 exception、fault、re-entry 或其他 CPU control-flow 事件。

依分支 2 指示，本輪在 report、disassembly excerpt、symbol/section evidence 與 provenance 完成後停止，不加入 trap/fault marker 或其他功能變因。

## Raw evidence

完整 exact ELF、完整與目標函式反組譯、symbol table、section headers、machine-order 摘要與 provenance 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-POST-LINK-SPLL-CHECK-RETURN-DISASSEMBLY-AUDIT-20260827/`

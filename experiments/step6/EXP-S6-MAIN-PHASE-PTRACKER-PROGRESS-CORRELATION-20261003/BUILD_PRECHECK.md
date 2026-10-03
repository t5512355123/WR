# Actual pre-compile gate

Laptop8 history (including actual whole Tcl observer) +14 TS4 +9 strict analyzer
tests PASS. Actual control/build source diff againstfbef3179 is empty for
wrh-servo.c, spll_main.c, firmware/configs, quartus and quartus_generated.

Pain source6b5be58627e3480d522c5e0e61ebdba3ed0fc8c9:
actual new history/ptracker512-average, original TS4,35 strict WR control and
fixed diagnostic native UBSan tests PASS. Initial harness include-path failure
and subsequent host/embedded assert collision preserved separately; corrected
on Laptop, pushed and pulled before successful rerun. No hardware programmed.

Fresh Master/Slave role firmware builds PASS, RAM footprint170724/170684 bytes
versus196608 available (stack/configuration unchanged).

- Master MIF8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5
- Slave MIF08ca140f1f569cefff5bbdcd1cbc932248a73383f8ea7a43a6119864d293b7ad

Returned hashes now pinned on Laptop before full Quartus compile. These are
actual artifacts, not hashes inferred from source/previous-round products.

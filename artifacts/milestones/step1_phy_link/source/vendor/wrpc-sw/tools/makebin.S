/*
 * "objcopy -O binary" they say...
 * how can I say "spit the default ELF object format"?
 */
	.section .rodata
	.global dump_wrpc_info_target_v42
dump_wrpc_info_target_v42:
.incbin "dump-info-host-v42.bin"

	.global dump_wrpc_info_target
dump_wrpc_info_target:
.incbin "dump-wrpc-info-host.bin"

	.global dump_ppsi_info_target
dump_ppsi_info_target:
.incbin "dump-ppsi-info-host.bin"


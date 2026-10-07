	.text
        # Init
	nop

        # Write one word
        csrr    t0, 0x7d0
        csrr    t1, 0x7d0
        sw      t1, 0(t0)

        # Jump to t0
        jalr    x0, t0, 0

        ebreak

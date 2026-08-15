	.text
        # Set dest address
	li	a0, 0
        # Read count (in bytes)
1:      csrr    t0, 0x7c0       # dbg status
        andi    t0, t0, 1
        beq     t0, zero, 1b
        csrr    a1, 0x7d0       # mbxi
        # Read data
1:      csrr    t0, 0x7c0       # dbg status
        andi    t0, t0, 1
        beq     t0, zero, 1b
        csrr    t1, 0x7d0       # mbxi
        sw      t1, 0(a0)
        addi    a0, a0, 4
        blt     a0, a1, 1b
        # Start at 0
done:   li      a0, 0
        jr      a0

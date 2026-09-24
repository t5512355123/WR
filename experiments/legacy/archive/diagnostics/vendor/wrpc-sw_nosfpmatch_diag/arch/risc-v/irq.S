/*
  RISC-V / RV32 interrupt support code
  Based on the RISC-V proxy kernel
*/

.section .text

.global trap_entry
trap_entry:
	/* Allocate a frame */
	addi	sp,sp,-68
	/* Save caller-saved registers */
	sw	ra,4(sp)
	sw	t0,8(sp)
	sw	t1,12(sp)
	sw	t2,16(sp)
	sw	a0,20(sp)
	sw	a1,24(sp)
	sw	a2,28(sp)
	sw	a3,32(sp)
	sw	a4,36(sp)
	sw	a5,40(sp)
	sw	a6,44(sp)
	sw	a7,48(sp)
	sw	t3,52(sp)
	sw	t4,56(sp)
	sw	t5,60(sp)
	sw	t6,64(sp)

	/* Handle irq cause (or fault) */
	csrr	ra,mepc
	csrr	t2,mcause
	csrr	t3,mbadaddr
	andi	t2,t2,0xff
	li	t0,11	/* Cause irq */
	bne	t0,t2, fault_handler
	jal	spll_irq_entry

	/* Restore registers */
	lw	ra,4(sp)
	lw	t0,8(sp)
	lw	t1,12(sp)
	lw	t2,16(sp)
	lw	a0,20(sp)
	lw	a1,24(sp)
	lw	a2,28(sp)
	lw	a3,32(sp)
	lw	a4,36(sp)
	lw	a5,40(sp)
	lw	a6,44(sp)
	lw	a7,48(sp)
	lw	t3,52(sp)
	lw	t4,56(sp)
	lw	t5,60(sp)
	lw	t6,64(sp)

	addi	sp,sp,68
	mret

fault_handler:
	j      fault_handler


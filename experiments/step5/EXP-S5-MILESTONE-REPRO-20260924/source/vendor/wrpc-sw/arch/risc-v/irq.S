/*
  RISC-V / RV32 interrupt support code
  Based on the RISC-V proxy kernel
*/

.section .text

.global trap_entry
.extern debug_precrt_persistent_fault_magic
.extern debug_precrt_persistent_fault_count
.extern debug_precrt_persistent_fault_mcause
.extern debug_precrt_persistent_fault_mepc
.extern debug_precrt_persistent_fault_mtval
.extern debug_precrt_persistent_fault_ra
.extern debug_precrt_persistent_fault_sp
.extern debug_precrt_persistent_fault_boot_generation
.extern debug_precrt_persistent_fault_last_mode_master_stage
.extern debug_precrt_persistent_fault_last_spll_check_lock_stage
.extern debug_precrt_boot_generation
.extern debug_precrt_persistent_mode_master_stage
.extern debug_precrt_persistent_spll_check_lock_stage
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
	andi	t0,t2,0xff
	li	t1,11	/* Cause irq */
	beq	t0,t1, trap_irq

	/* Capture synchronous-fault evidence before entering the existing
	 * permanent fault loop. The magic word is written last, so a partial
	 * record is not mistaken for a complete one after CPU-only re-entry. */
	la	t0,debug_precrt_persistent_fault_count
	lw	t1,0(t0)
	addi	t1,t1,1
	sw	t1,0(t0)
	la	t0,debug_precrt_persistent_fault_mcause
	sw	t2,0(t0)
	la	t0,debug_precrt_persistent_fault_mepc
	sw	ra,0(t0)
	la	t0,debug_precrt_persistent_fault_mtval
	sw	t3,0(t0)
	la	t0,debug_precrt_persistent_fault_ra
	lw	t1,4(sp)
	sw	t1,0(t0)
	la	t0,debug_precrt_persistent_fault_sp
	addi	t1,sp,68
	sw	t1,0(t0)
	la	t0,debug_precrt_persistent_fault_boot_generation
	la	t1,debug_precrt_boot_generation
	lw	t1,0(t1)
	sw	t1,0(t0)
	la	t0,debug_precrt_persistent_fault_last_mode_master_stage
	la	t1,debug_precrt_persistent_mode_master_stage
	lw	t1,0(t1)
	sw	t1,0(t0)
	la	t0,debug_precrt_persistent_fault_last_spll_check_lock_stage
	la	t1,debug_precrt_persistent_spll_check_lock_stage
	lw	t1,0(t1)
	sw	t1,0(t0)

	/* Commit the validity marker only after the CPU-local record is populated. */
	li	t1,0x4641554c
	la	t0,debug_precrt_persistent_fault_magic
	sw	t1,0(t0)
	j	fault_handler

trap_irq:
	andi	t2,t2,0xff
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


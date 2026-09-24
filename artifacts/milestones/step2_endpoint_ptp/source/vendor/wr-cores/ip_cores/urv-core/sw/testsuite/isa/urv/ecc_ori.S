# See LICENSE for license details.

#*****************************************************************************
# write_ecc.S
#-----------------------------------------------------------------------------
#
# Test write_ecc trap.
#

#include "riscv_test.h"
#include "test_macros.h"
#include "urv_asm.h"
	
RVTEST_RV32S
RVTEST_CODE_BEGIN
	li	a0, 0xff00ff00
	# Corrupt a0 (bank 1)
	li	t1, 1
	write_ecc a0, a0, t1
	nop
	nop
	nop

	# Test ori
	ori	a1, a0, 0xffffff0f

	# Check result
	li	a2, 0xffffff0f
	bne	a1, a2, fail

	# Check handler was called
	bne	t1, zero, fail


	li	a0, 0xff00ff00
	# Corrupt a0 (bank 2)
	li	t1, 2
	write_ecc a0, a0, t1
	nop
	nop
	nop

	# Test ori
	ori	a1, a0, 0xffffff0f

	# Check result
	li	a2, 0xffffff0f
	bne	a1, a2, fail

	# Check handler was not called
	beq	t1, zero, fail

	j	pass

	TEST_PASSFAIL

	.globl trap_entry
trap_entry:
	fix_ecc x0,x0,x0
	fix_ecc x1,x1,x1
	fix_ecc x2,x2,x2
	fix_ecc x3,x3,x3
	fix_ecc x4,x4,x4
	fix_ecc x5,x5,x5
	fix_ecc x6,x6,x6
	fix_ecc x7,x7,x7
	fix_ecc x8,x8,x8
	fix_ecc x9,x9,x9
	fix_ecc x10,x10,x10
	fix_ecc x11,x11,x11
	fix_ecc x12,x12,x12
	fix_ecc x13,x13,x13
	fix_ecc x14,x14,x14
	fix_ecc x15,x15,x15
	fix_ecc x16,x16,x16
	fix_ecc x17,x17,x17
	fix_ecc x18,x18,x18
	fix_ecc x19,x19,x19
	fix_ecc x20,x20,x20
	fix_ecc x21,x21,x21
	fix_ecc x22,x22,x22
	fix_ecc x23,x23,x23
	fix_ecc x24,x24,x24
	fix_ecc x25,x25,x25
	fix_ecc x26,x26,x26
	fix_ecc x27,x27,x27
	fix_ecc x28,x28,x28
	fix_ecc x29,x29,x29
	fix_ecc x30,x30,x30
	fix_ecc x31,x31,x31
	# Clear t1
	lui	t1,0
	mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

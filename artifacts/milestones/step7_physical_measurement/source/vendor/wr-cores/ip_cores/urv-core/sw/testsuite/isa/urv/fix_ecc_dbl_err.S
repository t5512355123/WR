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

	li TESTNUM, 2
	li	t2, 2
	li	t1, 3
	# Write bad ECC for t2
	write_ecc t2,t2,t1
	nop		# avoid bypass
	nop
	nop
	# Use t2
	add	t3,t1,t2
	j	fail	# Skipped by handler
	# Check t2 has not been modified
	add	t3,t1,t2
	j	fail	# Skipped by handler

	# Expect error from fix_ecc
	lui	t0, %hi(0x100008)
	sw	t0, %lo(0x100008)(t0)

	# Try to fix t2
	fix_ecc t2,t2,t2
	nop      # Handler not executed, so this is executed
	# Double error must have been detected
	j	fail

	TEST_PASSFAIL

	.globl trap_entry
trap_entry:
	# Destroy t1, t0
	li	t1, CAUSE_ECC_ERROR
	csrr	t0, mcause
	bne	t0, t1, fail
	# Inc address by 8
	csrr	t0, mepc
	addi	t0, t0, 8
	csrw	mepc, t0
	mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

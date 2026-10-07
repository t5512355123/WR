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
	li t2, 0
	# No bad ECC
	write_ecc t2,t2,t2
	nop		# avoid bypass
	nop
	nop
	# Use t2
	addi	t2,t2,1
	j	1f # Not skipped
	j	fail
	
1:	li	t2, 2
	li	t1, 1      #t1 is reg 6
	# Write bad ECC for t2
	write_ecc t2,t2,t1
	nop		# avoid bypass
	nop
	nop
	# Use t2
	addi	t2,t2,1
	j	fail	# Skipped by handler

	li	t1, 2
	li	t2, 3
	# Write bad ECC for t2
	write_ecc t2,t2,t1
	nop		# avoid bypass
	nop
	nop
	# Use t2
	add	t3,t1,t2
	j	fail	# Skipped by handler

	j pass


	TEST_PASSFAIL

	.globl trap_entry
trap_entry:
	# Destroy t1, t0
	li t1, CAUSE_ECC_ERROR
	csrr t0, mcause
	bne t0, t1, fail
	# Inc address by 8
	csrr t0, mepc
	addi t0, t0, 8
	csrw mepc, t0
	mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

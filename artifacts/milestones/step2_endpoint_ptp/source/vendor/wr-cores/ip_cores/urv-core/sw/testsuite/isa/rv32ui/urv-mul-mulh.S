#*****************************************************************************
# urv-mul-mulh.S
#-----------------------------------------------------------------------------
#
# Test mul/mulh stall condition (a.k.a. John's bug)
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

# before the multiply:
# a2 = 0x2833
# a3 = 0x3
# a5 = 0xcafebabe

    li a2, 0x2833
    li a3, 0x3
    li a5, 0xcafebabe

    mul	a5,a3,a5
	mulhu	a3,a3,a2

#after the multiply (correct case)
# a3 = 0x0
# a5 = 0x60fc303a

    li s0, 0x60fc303a
    bne a3, zero, fail
    bne a5, s0, fail

    j pass

    TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END

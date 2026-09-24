obj-$(CONFIG_ARCH_LM32) += \
	softpll/spll_common.o \
	softpll/spll_external.o \
	softpll/spll_helper.o \
	softpll/spll_main.o \
	softpll/spll_ptracker.o \
	softpll/softpll_ng.o

obj-$(CONFIG_ARCH_RISCV) += \
	softpll/spll_common.o \
	softpll/spll_external.o \
	softpll/spll_helper.o \
	softpll/spll_main.o \
	softpll/spll_ptracker.o \
	softpll/softpll_ng.o
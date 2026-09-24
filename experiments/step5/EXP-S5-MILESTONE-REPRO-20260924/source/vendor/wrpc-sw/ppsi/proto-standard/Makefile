# Hosted environment: build the final exectuable

# All files are under D: I'm lazy
D := $(PPSI)/proto-standard

OBJ-y += $D/fsm-table.o \
	$D/fsm-lib.o \
	$D/state-initializing.o \
	$D/state-faulty.o \
	$D/state-disabled.o \
	$D/state-listening.o \
	$D/state-master.o \
	$D/state-passive.o \
	$D/state-slave.o \
	$D/common-fun.o \
	$D/common-fun-p2p.o \
	$D/bmc_clock_quality.o \
	$D/bmc.o \
	$D/msg.o \
	$D/msg-p2p.o \
	$D/servo.o \
	$D/hooks.o \
	$D/open-close.o

OBJ-$(CONFIG_ABSCAL) += $D/state-abscal.o

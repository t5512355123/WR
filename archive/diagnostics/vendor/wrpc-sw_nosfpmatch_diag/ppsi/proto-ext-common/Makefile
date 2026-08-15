D := $(PPSI)/proto-ext-common

ifeq ($(CONFIG_HAS_EXT_WR),1)
INC_WRH_SERVO=y
endif
ifeq ($(CONFIG_HAS_EXT_L1SYNC),1)
INC_WRH_SERVO=y
endif

ifdef INC_WRH_SERVO
OBJ-y += $D/wrh-servo.o
endif


RISCV_PREFIX=riscv32-elf-
RISCV_GCC = $(RISCV_PREFIX)gcc

SW_DIR=../../sw

CFLAGS = -march=rv32im -mabi=ilp32 -O

all: app1.bin

app1: crt0.o app1.o
	$(RISCV_GCC) -o $@ $^ -nostdlib -T $(SW_DIR)/common/ram2.ld -Wl,-Map,$@.map

app1.bin: app1
	$(RISCV_PREFIX)objcopy -O binary $< $<.bin

crt0.o: $(SW_DIR)/crt0.S
	$(RISCV_GCC) -c $(CFLAGS) -o $@ $<

uart.o: $(SW_DIR)/common/uart.c
	$(RISCV_GCC) -c $(CFLAGS) -o $@ $<

app1.o: app1.c
	$(RISCV_GCC) -c $(CFLAGS) -o $@ $<

clean:
	$(RM) -f app1 *.o *.bin

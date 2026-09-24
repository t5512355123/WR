CFLAGS=-I../include -I../pp_printf -I../arch-unix/include \
 -DCONFIG_PRINT_BUFSIZE=1024
OBJS=test-time-arith.o time-arith.o vsprintf-full.o printf.o div64.o

all: check-time-arith


test-time-arith: $(OBJS)
	$(CC) -o $@ $(OBJS)

check-time-arith: test-time-arith test-time-arith.ref
	./test-time-arith | diff - test-time-arith.ref
	@echo "time-arith OK"

time-arith.o: ../lib/time-arith.c
	$(CC) -c -o $@ $(CFLAGS) $<

vsprintf-full.o: ../pp_printf/vsprintf-full.c
	$(CC) -c -o $@ $(CFLAGS) $<

printf.o: ../pp_printf/printf.c
	$(CC) -c -o $@ $(CFLAGS) $<

div64.o: ../lib/div64.c
	$(CC) -c -o $@ $(CFLAGS) $<

clean:
	$(RM) *.o
	$(RM) test-time-arith

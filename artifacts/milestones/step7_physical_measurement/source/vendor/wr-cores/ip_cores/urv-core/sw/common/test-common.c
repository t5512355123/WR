#include <stdint.h>

static const char hex[] = "0123456789abcdef";

static void uart_write_byte(int b)
{
  *(volatile int *)0x100000 = b;
}

int puts(const char *s)
{
  char c;
  while(c=*s++)
    uart_write_byte(c);
}

void rv_test_pass(int num)
{
    puts("Test passed\n");
}

void rv_test_fail(int num)
{
  puts ("Test 0x");
  uart_write_byte(hex[(num >> 4) & 0xf]);
  uart_write_byte(hex[(num >> 0) & 0xf]);
  puts (" failed\n");
}

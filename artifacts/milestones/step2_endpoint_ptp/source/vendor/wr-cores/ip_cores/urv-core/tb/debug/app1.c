static int cnt;
int puts(const char *s);

int putchar(int b)
{
    *(volatile int *)0x100000 = b;
    return 0;
}

int main(void)
{
  puts("Hello world\n");
  asm volatile("nop; nop; ebreak");
  while (1)
    {
      cnt++;
      putchar('0' + (cnt & 0x7));
      puts(" count\n");
    }
  return 0;
}

int puts(const char *s)
{
  char c;
  while (c = *s++)
    putchar (c);
}

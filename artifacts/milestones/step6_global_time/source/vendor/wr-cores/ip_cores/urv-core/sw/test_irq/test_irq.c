static const char *hello="Hello, world";
static const char *ptr;
static int irq_cnt = 0;

volatile int *TX_REG = (volatile int *)0x100000;
volatile int *IRQ_REG = (volatile int *)0x100004;

void
irq_handler(void)
{
  irq_cnt++;

  if (*ptr) {
    *TX_REG = *ptr++;
    if (irq_cnt < 2)
      *IRQ_REG = 100;
    else
      *IRQ_REG = 10;
  }
  else
    *IRQ_REG = 0;
}

void
main(void)
{
  unsigned t;

  ptr = hello;

  /* Enable irq: set mie.meie  */
  asm volatile ("csrrs %0, mie, %1" : "=r"(t) : "r"(1 << 11));

  /* Enable interrupts: set mstatus.mie  */
  asm volatile ("csrrsi %0, mstatus, %1" : "=r"(t) : "i"(1 << 3));

  /* Generate an interrupt after 10 cycles.  */
  *IRQ_REG = 10;

  for(;;);
}

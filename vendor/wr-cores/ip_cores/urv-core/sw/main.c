char dupa[64];

const char *hello="Hello, world";

volatile int *TX_REG = (volatile int *)0x100000;

void
main(void)
{
    const char *s = hello;
    while(*s) { *TX_REG = *s++; }
    for(;;);
}

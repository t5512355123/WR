/*
 * DSI Shield
 *
 * Copyright (C) 2013-2015 twl
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* main.c - main bootloader application */

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#ifndef CONFIG_TARGET_ERTM14
#error "The bootloader is made so far only for the eRTM14/15 boards. If you're building it for another board, comment out this error (but beware, here be dragons!)"
#endif

#define CONFIG_ERTM14_FLASH

#include "board.h"

#ifdef CONFIG_ERTM14_FLASH
    #include "dev/bb_spi.h"
    #include "dev/gpio.h"
    #include "dev/spi_flash.h"

    #define ERTM14_FLASH_PAGE_SIZE 65536
    #define ERTM14_FLASH_SIZE 16777216
    #define ERTM14_FIRMWARE_MAGIC 0xf1dee41a
#endif

#ifndef CONFIG_USER_START
    #define CONFIG_USER_START 0x0
#endif

#include "dev/syscon.h"
#include "dev/simple_uart.h"
#include "hw/wrc_syscon_regs.h"

#define CMD_INIT 1
#define CMD_ERASE_SECTOR 2
#define CMD_WRITE_PAGE 3
#define CMD_WRITE_RAM 4
#define CMD_GO 5
#define CMD_GET_FLASH_ID 6
#define CMD_EXIT 7

#define RSP_OK 1
#define RSP_HELLO 5
#define RSP_CRC_ERROR 2
#define RSP_VERIFY_ERROR 3
#define RSP_BAD_CRC 4

#define POLY 0x8408

#define RX_BUF_SIZE (256 + 16)

#define BOOT_TIMEOUT 500
#define UART_TIMEOUT 500

#define BOOT_BOARD_ID_LENGTH 8
static const char bootBoardId[BOOT_BOARD_ID_LENGTH] = "e14wrpc5";

uint8_t rxbuf[RX_BUF_SIZE];
int     boot_wait;

static uint32_t orig_reset_vector;
static uint32_t orig_reset_insn;

typedef void (*voidfunc_t)();
void start_user(void);

struct simple_uart_device dev_uart;

#ifdef CONFIG_ERTM14_FLASH

struct spi_bus spi_flash;
struct spi_flash_device dev_flash;

static void boot_sysc_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
}

static void boot_sysc_gpio_set_out(const struct gpio_pin *pin, int value)
{
	
    if(value)
		writel( ( 1<< pin->pin), (void*) ( (void*)BASE_SYSCON + SYSC_REG_GPSR) );
	else
		writel( ( 1<< pin->pin), (void *) ( (void*)BASE_SYSCON + SYSC_REG_GPCR) );
}

static int boot_sysc_gpio_read_pin(const struct gpio_pin *pin)
{
  return readl( (void*)BASE_SYSCON + SYSC_REG_GPSR) & (1<<pin->pin) ? 1 : 0;
}

static const struct gpio_device boot_syscon_gpio = {
	NULL,
	boot_sysc_gpio_set_dir,
	boot_sysc_gpio_set_out,
	boot_sysc_gpio_read_pin
};

static const struct gpio_pin boot_pin_sysc_spi_sclk = { &boot_syscon_gpio, 10 };
static const struct gpio_pin boot_pin_sysc_spi_ncs = { &boot_syscon_gpio, 11 };
static const struct gpio_pin boot_pin_sysc_spi_mosi = { &boot_syscon_gpio, 12 };
static const struct gpio_pin boot_pin_sysc_spi_miso = { &boot_syscon_gpio, 13 };

void  boot_flash_init()
{
    bb_spi_create( &spi_flash,
		&boot_pin_sysc_spi_ncs,
		&boot_pin_sysc_spi_mosi,
		&boot_pin_sysc_spi_miso,
		&boot_pin_sysc_spi_sclk, 0 );

    spi_flash_create( &dev_flash, &spi_flash, 16384, 0 );
}

#endif

uint16_t crc_xmodem_update(uint16_t crc, uint8_t data)
{
    int i;

    crc = crc ^ (((uint16_t)data) << 8);

    for (i = 0; i < 8; i++)
    {
        if (crc & 0x8000)
        {
            crc = (crc << 1) ^ 0x1021;
        } else {
            crc <<= 1;
        }
    }
    return crc;
}

uint16_t
crc16(unsigned char *buf, int len)
{
    int i;
    uint16_t cksum;

    cksum = 0;

    for (i = 0; i < len; i++) {
        cksum = crc_xmodem_update(cksum, buf[i]);
    }
    return cksum;
}

int timeout_hit = 0;


uint8_t suart_read_blocking()
{
    uint32_t t_end = timer_get_tics() + UART_TIMEOUT;

    while (timer_get_tics() < t_end)
        if (suart_poll(&dev_uart))
            return suart_read_byte(&dev_uart);

    timeout_hit = 1;

    return 0;
}

void uart_readm_blocking(uint8_t *buf, int count)
{
    int i;

    for (i = 0; i < count; i++)
    {
        buf[i] = suart_read_blocking();

        if (timeout_hit)
            return;
    }
}

void send_reply(uint8_t code, int length, const uint8_t *data)
{
    uint8_t  buf[32];
    uint16_t crc, i;

    buf[0] = 0x55;
    buf[1] = 0xaa;
    buf[2] = code;
    buf[3] = (length >> 8) & 0xff;
    buf[4] = (length & 0xff);

    if(length > 0)
        memcpy(buf+5, data, length);

    crc = crc16(buf, length+5);

    buf[length+5] = (crc >> 8);
    buf[length+6] = (crc & 0xff);

    for (i = 0; i < length+7; i++)
        suart_write_byte(&dev_uart, buf[i]);
}

void on_cmd_init()
{
    boot_wait = 0;
    send_reply(RSP_OK, 0, NULL);
}



uint32_t unpack_be32(uint8_t *p)
{
    uint32_t rv = 0;

    rv |= p[3];
    rv |= ((uint32_t)p[2]) << 8;
    rv |= ((uint32_t)p[1]) << 16;
    rv |= ((uint32_t)p[0]) << 24;
    return rv;
}

uint32_t unpack_le32(uint8_t *p)
{
    uint32_t rv = 0;

    rv |= p[0];
    rv |= ((uint32_t)p[1]) << 8;
    rv |= ((uint32_t)p[2]) << 16;
    rv |= ((uint32_t)p[3]) << 24;
    return rv;
}

void pack_be32(uint8_t *p, uint32_t val)
{
    uint32_t rv = 0;

    p[3] = val & 0xff;
    p[2] = (val >> 8)& 0xff;
    p[1] = (val >> 16)& 0xff;
    p[0] = (val >> 24)& 0xff;
}


#ifdef CONFIG_ERTM14_FLASH

void on_cmd_erase_sector(uint8_t *payload, int len)
{
    uint32_t base = unpack_be32(payload);

    spi_flash_erase_sector(&dev_flash, base);

    send_reply(RSP_OK, 0, NULL);
}

void on_cmd_write_page(uint8_t *payload, int len)
{
    uint32_t base = unpack_be32(payload);

    spi_flash_write(&dev_flash, base, payload + 4, len - 4);

    send_reply(RSP_OK, 0, NULL);
}

void on_cmd_get_flash_id(uint8_t *payload, int len)
{
    uint32_t id = spi_flash_read_id(&dev_flash);

    send_reply(RSP_OK, 4, (uint8_t*) &id);
}

#endif


static uint32_t decode_reset_jump_target( uint32_t pc, uint32_t insn )
{
#if defined(CONFIG_ARCH_RISCV)
    int32_t d_imm_j = 0;

    if( insn & ( 1<<31 ) )
        d_imm_j |= 0xfff00000; // sign-extend

    d_imm_j |= ((insn >> 12) & 0xff ) << 12;
    d_imm_j |= ((insn >> 20) & 0x1 ) << 11;
    d_imm_j |= ((insn >> 25) & 0x3f ) << 5;
    d_imm_j |= ((insn >> 21) & 0xf ) << 1;

    uint32_t addr = pc + d_imm_j;

    return addr;
#else
    #error UART bootloader can be only built for the RISC-V CPU target. 
#endif
}
                


void on_cmd_write_ram(uint8_t *payload, int len)
{
    int i;
    uint32_t base = unpack_be32(payload);

    for (i = 0; i < len - 4; i++)
    {
        if (base + i < 4)
        { // special case for the entry vector address
            switch(base + i)
            {
                case 0: orig_reset_insn = ((uint32_t)payload[i+4]); break;
                case 1: orig_reset_insn |= ((uint32_t)payload[i+4])<<8; break;
                case 2: orig_reset_insn |= ((uint32_t)payload[i+4])<<16; break;
                case 3: orig_reset_insn |= ((uint32_t)payload[i+4])<<24;
                        orig_reset_vector = decode_reset_jump_target( 0, orig_reset_insn );
                        break;
                break;
                default:
                    break;
            }
        }
        else
        {
            *(uint8_t *)(base + i) = payload[i + 4];
        }
    }

    uint8_t buf[16];

    pack_be32(buf, orig_reset_insn);
    pack_be32(buf+4, orig_reset_vector);
    pack_be32(buf+8, base);

    send_reply(RSP_OK, 12, buf);
}

void on_cmd_go(uint8_t *payload, int len)
{
    uint32_t base = unpack_be32(payload);

    voidfunc_t f = (voidfunc_t)orig_reset_vector;

    uint8_t buf[16];

    pack_be32(buf, orig_reset_insn);
    pack_be32(buf+4, orig_reset_vector);
    pack_be32(buf+8, base);

    send_reply(RSP_OK, 12, buf);

    f();
}

void boot_fsm()
{
    uint32_t t_exit = timer_get_tics() + BOOT_TIMEOUT;

    boot_wait = 1;

    send_reply(RSP_HELLO, BOOT_BOARD_ID_LENGTH, bootBoardId );

    for (;;)
    {
        int pos = 0, i;
        uint16_t crc;

        if (boot_wait && (timer_get_tics() > t_exit))
            return;

        timeout_hit = 0;

        int c = suart_read_blocking();

        if(timeout_hit && boot_wait)
            break;

        if (c != 0x55)
        {
            continue;
        }
        rxbuf[pos++] = c;

        c = suart_read_blocking();

        if ((c != 0xaa) || timeout_hit)
            continue;

        rxbuf[pos++] = c;

        uint8_t command = suart_read_blocking();

        rxbuf[pos++] = command;
        rxbuf[pos++] = suart_read_blocking();
        rxbuf[pos++] = suart_read_blocking();

        uint16_t len = (uint16_t)rxbuf[3] << 8 | rxbuf[4];

        if (timeout_hit)
            continue;

        for (i = 0; i < len; i++)
            rxbuf[pos++] = suart_read_blocking();

        crc  = (uint16_t)suart_read_blocking() << 8;
        crc |= (uint16_t)suart_read_blocking();

        if (timeout_hit)
            continue;

        if (crc != crc16(rxbuf, len + 5))
        {
            send_reply(RSP_BAD_CRC, 0, NULL);
        }


        switch (command)
        {
        case CMD_INIT:
            on_cmd_init(rxbuf + 5, len);
            break;

        case CMD_ERASE_SECTOR:
        #ifdef CONFIG_ERTM14_FLASH
            on_cmd_erase_sector(rxbuf + 5, len);
        #endif
            break;

        case CMD_WRITE_PAGE:
        #ifdef CONFIG_ERTM14_FLASH
            on_cmd_write_page(rxbuf + 5, len);
        #endif
            break;

        case CMD_WRITE_RAM:
            on_cmd_write_ram(rxbuf + 5, len);
            break;

        case CMD_GO:
            on_cmd_go(rxbuf + 5, len);
            break;
        
        case CMD_EXIT:
            return;

#ifdef CONFIG_ERTM14_FLASH
        case CMD_GET_FLASH_ID:
            on_cmd_get_flash_id(rxbuf + 5, len);
            break;
#endif

        default:
            break;
        }
    }
}

void try_flash_boot()
{
    uint8_t buf[512];
    uint32_t offset;

    for(offset = 0; offset < ERTM14_FLASH_SIZE; offset += ERTM14_FLASH_PAGE_SIZE)
    {
        uint32_t magic, size;
        spi_flash_read(&dev_flash, offset, buf, 16 );
        magic = unpack_be32( buf );
        size = unpack_be32( buf + 4 );

        if ( magic == ERTM14_FIRMWARE_MAGIC )
        {
            uint32_t insn = unpack_le32(buf + 8);
            orig_reset_vector = decode_reset_jump_target( 0, insn );
            spi_flash_read(&dev_flash, offset + 8 + 4, (void*)4, size); // keep the original bootloader reset vector
            start_user();
        }
    }
}


void start_user(void)
{
    voidfunc_t f = (voidfunc_t)orig_reset_vector;

    f();
}

void dev_dbg()
{
    /* stub to avoid linking errors */
}

int boot_main()
{
    orig_reset_vector = 0x0;

    suart_init_default_baudrate( &dev_uart, BASE_UART );

    timer_init(1);

    #ifdef CONFIG_ERTM14_FLASH
        boot_flash_init();
    #endif

	for(;;)
    {
        boot_fsm();

        #ifdef CONFIG_ERTM14_FLASH
            try_flash_boot();
        #endif
    }
    return 0;
}

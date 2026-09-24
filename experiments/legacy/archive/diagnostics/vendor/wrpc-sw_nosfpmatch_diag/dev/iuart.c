/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: John Gill <jgill@cern.ch>
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


#include <stdint.h>
#include <string.h>
#include "board.h"
#include "hw/rawmem.h"
#include "dev/iuart.h"

// bare-metal version with real HW iuart

#ifdef IUART_PLATFORM_BARE_METAL

#include <hw/wb_insn_uart.h>
#include <hw/wb_uart.h>

static void
iuart_writel(struct iuart_device *dev, uint32_t val, uint32_t reg)
{
    writel( val, (void*) (dev->base + reg) );
}

static uint32_t 
iuart_readl(struct iuart_device *dev, uint32_t reg)
{
    return readl( (void*) dev->base + reg );
}

void  
iuart_fifo_cnt(struct iuart_device *dev, uint16_t *rxcnt, uint16_t *txcnt)
{
    uint32_t rval = iuart_readl(dev, IUART_REG_FIFO);

    *txcnt = IUART_FIFO_TXCNT_R(rval);
    *rxcnt = IUART_FIFO_RXCNT_R(rval);
}

uint16_t
iuart_fifo_space(struct iuart_device *dev, uint16_t fifo_size, uint16_t fifo_cnt)
{
    return (fifo_size - fifo_cnt);
}

static void 
iuart_uart_en(struct iuart_device *dev, uint8_t val)
{
    iuart_writel(dev, val, IUART_REG_UART_EN);
}

int
iuart_read_byte(struct iuart_device *dev)
{
    if( !iuart_rx_ready( dev ))
        return -1;

    return iuart_readl(dev, IUART_REG_RX_FIFO_DATA);
}

void
iuart_write_byte(struct iuart_device *dev, uint8_t val)
{
    iuart_writel(dev, val, IUART_REG_TX_FIFO_DATA);
}

uint8_t
iuart_tx_busy(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    return (val & IUART_SR_TXBSY);
}

uint8_t
iuart_rx_ready(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    return (val & IUART_SR_RXRDY);
}

uint8_t
iuart_rx_err(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    return (val & IUART_SR_RXERR);
}

uint8_t
iuart_read_ctrl(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    val = (val & IUART_SR_GP_CTRL_MASK) >> IUART_SR_GP_CTRL_SHIFT;
    return (uint8_t)val;
}

uint8_t
iuart_txdata_valid(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    return (val & IUART_SR_TXDATA_VALID);
}

uint8_t
iuart_cpls_valid(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_SR);

    return (val & IUART_SR_CPLS_VALID);
}


uint32_t
iuart_rx_errcnt(struct iuart_device *dev)
{
    uint32_t val = iuart_readl(dev, IUART_REG_RX_DROPPED);

    return val;
}

int
iuart_init_bare(struct iuart_device *dev, uint32_t iuart_base_addr, uint32_t baud_rate)
{
    dev->base = iuart_base_addr + 0x40; // IUART regs shifted wrs to the 'master' UART

    suart_init( &dev->master_uart, iuart_base_addr, baud_rate );

    iuart_uart_en(dev, 0);

    iuart_writel(dev, ESC_CHAR_VAL,              IUART_REG_ESC_CHAR);
    iuart_writel(dev, START_INSN_CHAR_VAL,       IUART_REG_START_INSN_CHAR);
    iuart_writel(dev, START_WRITE_CHAR_VAL,      IUART_REG_START_WRITE_CHAR);
    iuart_writel(dev, START_READ_CHAR_VAL,       IUART_REG_START_READ_CHAR);
    iuart_writel(dev, START_CPL_CHAR_VAL,        IUART_REG_START_CPL_CHAR);
    iuart_writel(dev, END_CHAR_VAL,              IUART_REG_END_CHAR);
    iuart_writel(dev, START_WRITE_CTRL_CHAR_VAL, IUART_REG_WRITE_CTRL_CHAR);
    iuart_writel(dev, START_READ_CTRL_CHAR_VAL,  IUART_REG_READ_CTRL_CHAR);

    iuart_uart_en(dev, 1);
    return 0;
}

#endif

void
iuart_da_write_ctrl(struct iuart_device *dev, uint8_t val)
{
    uint32_t csum = ESC_CHAR_VAL + START_WRITE_CTRL_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL;

    csum = csum + val;
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_WRITE_CTRL_CHAR_VAL);
    if (val == ESC_CHAR_VAL) {
        iuart_write_byte(dev, ESC_CHAR_VAL);
        csum = csum + ESC_CHAR_VAL;
    }
    iuart_write_byte(dev, val);
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);
}

void
iuart_da_read_ctrl(struct iuart_device *dev)
{
    uint32_t csum = ESC_CHAR_VAL + START_READ_CTRL_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL;

    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_READ_CTRL_CHAR_VAL);
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);
}


void
iuart_da_write(struct iuart_device *dev, uint8_t *buf, uint32_t addr, uint32_t size)
{
    uint32_t csum = ESC_CHAR_VAL + START_WRITE_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL;
    uint8_t  val;
    int i;

    csum = csum + size;
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_WRITE_CHAR_VAL);
    iuart_write_byte(dev, size);
    for (i = 0; i < 4; i++)
    {
        val  = (uint8_t)(addr >> (i * 8));
        if (val == ESC_CHAR_VAL) {
            csum = csum + val;
            iuart_write_byte(dev, val);
        }
        csum = csum + val;
        iuart_write_byte(dev, val);
    }
    for (i = 0; i < size; i++)
    {
        val  = buf[i];
        if (val == ESC_CHAR_VAL) {
            csum = csum + val;
            iuart_write_byte(dev, val);
        }
        csum = csum + val;
        iuart_write_byte(dev, val);
    }
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);
}

void
iuart_da_read(struct iuart_device *dev, uint32_t addr, uint32_t size)
{
    uint32_t csum = ESC_CHAR_VAL + START_READ_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL;
    uint8_t  val;
    int i;

    csum = csum + size;
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_READ_CHAR_VAL);
    iuart_write_byte(dev, size);

    for (i = 0; i < 4; i++)
    {
        val  = (uint8_t)(addr >> (i * 8));
        if (val == ESC_CHAR_VAL) {
            csum = csum + val;
            iuart_write_byte(dev, val);
        }
        csum = csum + val;
        iuart_write_byte(dev, val);
    }

    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);
}

void
iuart_da_cpl(struct iuart_device *dev, uint32_t cpldata)
{
    uint32_t csum = ESC_CHAR_VAL + START_CPL_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL;
    uint8_t  size = 4;
    uint8_t  val;
    int i;

    csum = csum + size;
    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_READ_CHAR_VAL);
    iuart_write_byte(dev, size);

    for (i = 0; i < size; i++)
    {
        val  = (uint8_t)(cpldata >> (i * 8));
        if (val == ESC_CHAR_VAL) {
            csum = csum + val;
            iuart_write_byte(dev, val);
        }
        csum = csum + val;
        iuart_write_byte(dev, val);
    }

    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);
}



static unsigned
iuart_rxd_start(uint8_t rxbyte, uint8_t pchar)
{
    if (pchar != ESC_CHAR_VAL)
        return 0;

    if ((rxbyte & START_MASK_EN) == START_MASK_EN)
        return 1;

    return 0;
}


static unsigned
iuart_rxd_end(uint8_t rxbyte, uint8_t pchar)
{
    if (pchar != ESC_CHAR_VAL)
        return 0;

    if (rxbyte == END_CHAR_VAL)
        return 1;

    return 0;
}

#define MAX_SIZE (128)
uint8_t // returns non-zero, start char if a complete packet is received.
iuart_parse_raw_byte( uint8_t rxbyte, uint8_t *rxbuf, int *noc, int *csize)
{
    static unsigned ridx    = 0;
    static unsigned bidx    = 0;
    static unsigned end     = 0;
    static unsigned cmdsize = 0;
    static uint32_t csum    = 0;
    static uint8_t  pchar   = ~ESC_CHAR_VAL;
    static uint8_t  schar   = (uint8_t)~START_MASK_EN;
    static uint8_t  nesc    = 0;
    int    size_is_esc_char = 0;


    if (rxbyte == ESC_CHAR_VAL)
        nesc++;
    else
        nesc = 0;

    if (iuart_rxd_start(rxbyte, pchar))    // detect start 
    {
        ridx  = 2; // esc and then start
        bidx  = 0;
        end   = 0;
        schar = rxbyte;
        pchar = rxbyte;
        csum  = ESC_CHAR_VAL + rxbyte;
#ifdef IUART_PLATFORM_HOSTED
        //printf("rxs\n");
#endif

        return 0;
    } 
    else if (iuart_rxd_end(rxbyte, pchar)) // esc and then end
    { 
        ridx  = ridx + 1; 
        end   = 1;
        csum  = csum + rxbyte;
        pchar = rxbyte;
        return 0;
    } 
    else if (end) // infer csum after end.
    {     
        uint8_t rval = schar;

        end   = 0; 
        ridx  = 0; 
        pchar = ~ESC_CHAR_VAL; 
        schar = (uint8_t)~START_MASK_EN;

#ifdef IUART_PLATFORM_HOSTED
        //printf("rxb %x cs %x\n", rxbyte, (uint8_t) csum);
#endif

        if (rxbyte == (uint8_t)csum) {
            //pp_printf("got [%x]!\n", rval);
            csum = 0;
            *noc = bidx;
            return rval;
        }

        // fallthrough fail
        csum = 0;
        *noc = 0;
        return 0;
    }
        
    // strip esc chars from the stream
    if (nesc & 1) {
        pchar = rxbyte; 
        csum  = csum + rxbyte;
        ridx  = ridx + 1;
        return 0;
    }
    
    // Stash the advertised command size
    if (ridx == 2) 
        cmdsize = rxbyte;

    // special case when size = ESC_CHAR_VAL
    if ((ridx == 3) && nesc == 2)
        size_is_esc_char = 1;

    // rxbyte can no longer be an escape char...    
    if (ridx > (2 + size_is_esc_char)) { // payload
        rxbuf[bidx++] = rxbyte;
    }
    
    // Detect missing end or overflow
    if (bidx >= MAX_SIZE) {
        end   = 0; 
        ridx  = 0; 
        bidx  = 0;
        pchar = ~ESC_CHAR_VAL; 
        schar = (uint8_t)~START_MASK_EN;
        *noc  = 0;
        return 0;
    }
    
    csum   = csum + rxbyte;
    ridx   = ridx + 1;
    *csize = cmdsize;
    *noc   = bidx;
    if (rxbyte == ESC_CHAR_VAL) // this char was data !
        pchar = ~ESC_CHAR_VAL;

    return 0;
}

#if defined(IUART_PLATFORM_LINUX) || defined(IUART_PLATFORM_HOSTED)

int iuart_recv_message(struct iuart_device *dev)
{
    int rv = dev->recv_byte(dev);
    if( rv >= 0 )
    {
        //printf("Rx %x\n\r", rv );
        int start_cmd = iuart_parse_raw_byte( rv, dev->rx_buf, &dev->rx_noc, &dev->rx_csize );
        return start_cmd;
    }

    return -1;
}

static inline void iuart_send_escaped( struct iuart_device *dev, uint8_t ch, uint32_t *csum )
{
    if( ch == ESC_CHAR_VAL )
    {
        dev->send_byte(dev, ESC_CHAR_VAL);
        *csum += ESC_CHAR_VAL;
    }

    dev->send_byte(dev, ch);
    *csum += ch;
}

int iuart_send_message(struct iuart_device *dev, uint8_t *payload, int length )
{
    uint32_t csum = ESC_CHAR_VAL + START_INSN_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL + (uint8_t) length;
    int i;

    dev->send_byte(dev, ESC_CHAR_VAL);
    dev->send_byte(dev, START_INSN_CHAR_VAL);
    dev->send_byte(dev, length);

    for(i = 0; i < length ;i++)
        iuart_send_escaped( dev, payload[i], &csum );

    dev->send_byte(dev, ESC_CHAR_VAL);
    dev->send_byte(dev, END_CHAR_VAL);
    dev->send_byte(dev, (uint8_t)csum);

    return length;
}
#endif

#ifdef IUART_PLATFORM_BARE_METAL

int iuart_recv_message(struct iuart_device *dev)
{
    int rv = iuart_read_byte( dev );
    if( rv >= 0)
    {
        int start_cmd = iuart_parse_raw_byte( rv, dev->rx_buf, &dev->rx_noc, &dev->rx_csize );
        if(start_cmd > 0)
        //pp_printf("scmd %x\n", start_cmd);

        return start_cmd;
    }

    return -1;
}

static inline void iuart_send_escaped( struct iuart_device *dev, uint8_t ch, uint32_t *csum )
{
    if( ch == ESC_CHAR_VAL )
    {
        iuart_write_byte(dev, ESC_CHAR_VAL);
        *csum += ESC_CHAR_VAL;
    }

    iuart_write_byte(dev, ch);
    *csum += ch;
}

int iuart_send_message(struct iuart_device *dev, uint8_t *payload, int length )
{
    uint32_t csum = ESC_CHAR_VAL + START_INSN_CHAR_VAL + ESC_CHAR_VAL + END_CHAR_VAL + (uint8_t) length;
    int i;

    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, START_INSN_CHAR_VAL);
    iuart_write_byte(dev, length);
    
    for(i = 0; i < length ;i++)
        iuart_send_escaped( dev, payload[i], &csum );

    iuart_write_byte(dev, ESC_CHAR_VAL);
    iuart_write_byte(dev, END_CHAR_VAL);
    iuart_write_byte(dev, (uint8_t)csum);

    return length;
}

#endif

#ifdef IUART_PLATFORM_LINUX

int
iuart_read_byte(struct iuart_device *dev)
{
    int rval = dev->recv_byte( dev ); //iuart_readl(dev, IUART_REG_RX_FIFO_DATA);

if(rval )
    return rval;
}

void
iuart_write_byte(struct iuart_device *dev, uint8_t val)
{
    dev->send_byte(dev, val);
}


int iuart_da_wait_completion( struct iuart_device *dev, uint8_t* data, int size )
{
    int rv = iuart_read_byte( dev );

    if( rv < 0 )
        return 0;

    int start_cmd = iuart_parse_raw_byte( rv, dev->rx_buf, &dev->rx_noc, &dev->rx_csize );

    if( start_cmd == START_CPL_CHAR_VAL )
    {
        int tocopy = (size < dev->rx_csize ? size : dev->rx_csize );
        //printf("ToCopy %d\n", tocopy);
        memcpy( data, dev->rx_buf, tocopy );
        return tocopy;
    }

    return 0;
}

int iuart_da_read_blocking(struct iuart_device *dev, uint32_t addr, uint8_t *data, uint32_t size)
{
    int rv = 0;
    iuart_da_read(dev, addr, size);

    while(1)
    {
        rv = iuart_da_wait_completion( dev, data, size );
        if(rv < 0)
            return rv;
        if(rv > 0)
            break;
    }

    return rv;
}


#endif

#ifdef IUART_PLATFORM_HOSTED
int     iuart_init_hosted(struct iuart_device *dev)
{
    return 0;
}

#endif

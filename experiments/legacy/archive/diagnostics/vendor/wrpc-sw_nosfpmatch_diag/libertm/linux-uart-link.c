#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/errno.h>
#include <sys/time.h>
#include <termios.h>
#include <fcntl.h>

#include "board-state.h"
#include "common-uart-link.h"

#define CON_ESCAPE_CODE 0x1b
#define CON_SWITCH_BINARY_CODE 'B'
#define CON_SWITCH_TEXT_CODE 'T'

struct uart_link_priv
{
    int fd;
    int esc_pending;
};

int uart_link_send_byte_raw( struct uart_link* link, uint8_t b )
{
    struct uart_link_priv *priv = (struct uart_link_priv* ) link->priv;

    int rv = write( priv->fd, &b, 1);

    ulink_dbg("TxRaw %x r %d\n", b, rv);

    return rv == 1 ? 0 : -EBUSY;
}

int uart_link_send_byte( struct uart_link* link, uint8_t b )
{
    if( b == CON_ESCAPE_CODE )
    {
        if( uart_link_send_byte_raw( link, CON_ESCAPE_CODE ) < 0 )
            return -1;
    }

    return uart_link_send_byte_raw( link, b );
}

int uart_link_recv_byte_raw( struct uart_link* link )
{
    struct uart_link_priv *priv = (struct uart_link_priv* ) link->priv;
    uint8_t b;

    int rv = read( priv->fd, &b, 1);

    return rv == 1 ? b : -1;
}

int uart_link_recv_byte( struct uart_link* link )
{
    return uart_link_recv_byte_raw( link );
}


int uart_link_set_binary( struct uart_link* link )
{
    int retries;

    for( retries = 0; retries < 3; retries++ )
    {
        if( uart_link_send_byte_raw( link, CON_ESCAPE_CODE ) < 0 )
            return -1;

        if( uart_link_send_byte_raw( link, CON_SWITCH_BINARY_CODE ) < 0)
            return -1;
    }

    return 0;
}


uint32_t uart_link_get_ms_tics( struct uart_link *link )
{
    struct timezone tz = {0,0};
    struct timeval tv;

    gettimeofday(&tv, &tz);

    uint64_t tics = (uint64_t) tv.tv_sec * 1000ULL + tv.tv_usec / 1000;

    return (uint32_t) tics;
}

static int uart_link_poll( struct uart_link *link )
{
    struct uart_link_priv *priv = (struct uart_link_priv* ) link->priv;
    fd_set readfs;
    struct timeval tv = {0, 0};
    FD_ZERO(&readfs);
    FD_SET(priv->fd, &readfs);
    select(priv->fd+1, &readfs, NULL, NULL, &tv);
    if (FD_ISSET(priv->fd, &readfs))
        return 1;

    return 0;
}

int uart_link_create_linux( struct uart_link *link, const char* dev_name, int speed )
{
    struct uart_link_priv *priv = malloc( sizeof( struct uart_link_priv ));
    struct termios t;
    int fd;
    int spd;

    if(!priv)
        return -ENOMEM;

    switch(speed)
    {
        case 921600: spd=B921600; break;
        case 230400: spd=B230400; break;
        case 460800: spd=B460800; break;
        case 115200: spd=B115200; break;
        case 57600: spd=B57600; break;
        case 38400: spd=B38400; break;
        case 19200: spd=B19200; break;
        case 9600: spd=B9600; break;
        default: return -EINVAL;
    }

    fd = open (dev_name, O_RDWR | O_NONBLOCK | O_SYNC);

    if(fd<0)
        return fd;

    tcgetattr (fd, &t);
    t.c_iflag = IGNBRK | IGNPAR;
    t.c_oflag = t.c_lflag = t.c_line = 0;
    t.c_cflag = CSTOPB | CS8 | CREAD |  CLOCAL | HUPCL | spd;
    tcsetattr (fd, TCSAFLUSH, &t);

    priv->fd = fd;
    link->send_byte = uart_link_send_byte;
    link->recv_byte = uart_link_recv_byte;
    link->get_ms_tics = uart_link_get_ms_tics;
    link->poll = uart_link_poll;
    link->state = LINK_STATE_IDLE;
    link->priv = priv;
    link->rx_last_tics = 0;

    return uart_link_set_binary( link );
};

int uart_link_close_linux( struct uart_link *link )
{
    struct uart_link_priv *priv = (struct uart_link_priv* ) link->priv;
    close( priv->fd );
    return 0;
}

int toms_main()
{
    struct uart_link link;
    char ttyname[] = "/dev/ttyUSB2";
    int speed = 921600;

    if (uart_link_create_linux( &link, ttyname, speed) != 0) {
	fprintf(stderr, "cannot open uart %s at speed %d\n", ttyname, speed);
	exit(1);
    }

    for(;;)
    {
        fprintf(stderr,"Ping!\n");
        struct uart_packet pkt;
        pkt.ptype = ERTM14_UART_PTYPE_PING;
        pkt.length = 0;

        uart_link_send( &link, &pkt );

        struct uart_packet *rx_pkt;

        int stat = uart_link_recv( &link, &rx_pkt, 1000 );
        if( stat > 0)
        {
            fprintf(stderr,"Pong [%d]\n", rx_pkt->length);
        }
    }

    return 0;

}
void blink( int id )
{
    
}

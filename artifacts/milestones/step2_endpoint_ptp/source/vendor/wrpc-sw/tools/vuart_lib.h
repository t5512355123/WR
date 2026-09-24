/**
 * Author: Federico Vaga <federico.vaga@cern.ch>
 */

#ifndef __VUART_LIB_H_
#define __VUART_LIB_H_

#include <stddef.h>
#include <unistd.h>
#include <termios.h>

#include <libdevmap.h>

#define VUART_EOL 13
#define VUART_CMD_USLEEP 1000000
#define VUART_CMD_PROMPT "wrc#"

int wr_vuart_rx(struct mapping_desc *vuart);
void wr_vuart_tx(struct mapping_desc *vuart, char data);
size_t wr_vuart_read(struct mapping_desc *vuart, char *buf, size_t size);
void wr_vuart_flush(struct mapping_desc *vuart);
void wr_vuart_write(struct mapping_desc *vuart, char *buf, size_t size);
void wrpc_vuart_set_tty_raw(struct termios *old_termios);
void wrpc_vuart_restore_tty(struct termios *old_termios);

#endif /* __VUART_LIB_H_ */

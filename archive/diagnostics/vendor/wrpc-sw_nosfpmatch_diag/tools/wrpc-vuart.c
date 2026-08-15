/**
 * Author: Federico Vaga <federico.vaga@cern.ch>
 */


#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <termios.h>
#include <getopt.h>
#include <errno.h>

#include <libdevmap.h>

#include "vuart_lib.h"

static void wrpc_vuart_help(char *prog)
{
	const char *mapping_help_str;

	mapping_help_str = dev_mapping_help();
	fprintf(stderr, "%s [options]\n", prog);
	fprintf(stderr, "%s\n", mapping_help_str);
	fprintf(stderr, "for vuart, address offset should be 0x500\n");
	fprintf(stderr, "Vuart specific option: [-k(keep terminal)]\n");
}

static void wrpc_vuart_term(struct mapping_desc *vuart, int keep_term)
{
	struct termios oldkey;
	int need_exit = 0;
	fd_set fds;
	int ret;
	int rx, tx;

	fprintf(stderr, "[press C-a to exit]\n");

	if(!keep_term)
		wrpc_vuart_set_tty_raw(&oldkey);

	while(!need_exit) {
		struct timeval tv = {0, 10000};

		FD_ZERO(&fds);
		FD_SET(STDIN_FILENO, &fds);

		/*
		 * Check if the STDIN has characters to read
		 * (what the user writes)
		 */
		ret = select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv);
		switch (ret) {
		case -1:
			perror("select");
			break;
		case 0: /* timeout */
			break;
		default:
			if(!FD_ISSET(STDIN_FILENO, &fds))
				break;
			/* The user wrote something */
			do {
				ret = read(STDIN_FILENO, &tx, 1);
			} while (ret < 0 && errno == EINTR);
			if (ret != 1) {
				fprintf(stderr, "nothing to read. Port disconnected?\n");
				need_exit = 1; /* kill */
			}
			/* If the user character is C-a, then kill */
			if(tx == '\x01') {
				need_exit = 1;
				break;
			}

			wr_vuart_tx(vuart, tx);
			break;
		}

		/* Print all the incoming characters */
		while((rx = wr_vuart_rx(vuart)) > 0) {
			putchar(rx);
		}
		fflush(stdout);
	}

	if(!keep_term)
		wrpc_vuart_restore_tty(&oldkey);
}

static void wrpc_vuart_command(struct mapping_desc *vuart, char *command)
{
	//above is place for old and new port settings for keyboard teletype
	int cmd_len = 0;
	char *prompt = VUART_CMD_PROMPT;
	int i_prompt = 0;
	int i;
	int rx;

	/* Flush Vuart before sending command */
	wr_vuart_flush(vuart);
	/* Send command */
	cmd_len = strlen(command);
	wr_vuart_write(vuart, command, cmd_len);
	/* Flush command echo */
	wr_vuart_flush(vuart);
	/* Send end character */
	wr_vuart_tx(vuart, VUART_EOL);
	/* Wait for a while before reading command results */
	usleep(VUART_CMD_USLEEP);
	/* Discard characters until end of line control one */
	while((rx = wr_vuart_rx(vuart)) > 0) {
		if(rx == VUART_EOL)
			break;
	}

	while(1) {
		/* Print all the incoming characters */
		rx = wr_vuart_rx(vuart);
		if (rx < 0) {
			usleep(10);
			continue;
		}

		/* Prompt detection, skip characters */
		if (rx == prompt[i_prompt]) {
			i_prompt++;
			/* Prompt detected! */
			if(i_prompt == strlen(prompt))
				return;
		} else {
			/* Check if some previous characters have been skipped
			   by prompt detector code and print them */
			for(i = 0 ; i < i_prompt ; i++)
				putchar(prompt[i]);
			/* Reset prompt detector */
			i_prompt = 0;
			/* Print current character */
			putchar(rx);
			fflush(stdout);
		}
	}
}


int main(int argc, char *argv[])
{
	char c;
	int keep_term = 0;
	char *cmd = NULL;
	struct mapping_args *map_args;
	struct mapping_desc *vuart = NULL;

	map_args = dev_parse_mapping_args(&argc, argv);
	if (!map_args) {
		wrpc_vuart_help(argv[0]);
		return 1;
	}

	/* Parse specific args */
	while ((c = getopt (argc, argv, "c:kh")) != -1) {
		switch (c) {
		case 'c':
			/* Enable command mode */
			cmd = optarg;
			break;
		case 'k':
			keep_term = 1;
			break;
		case 'h':
			wrpc_vuart_help(argv[0]);
			return 0;
		case '?':
			break;
		}
	}

	vuart = dev_map(map_args, getpagesize() );
	if (!vuart) {
		fprintf(stderr, "%s: vuart_open() failed: %s\n", argv[0],
			strerror(errno));
		return 1;
	}

	if (cmd)
		wrpc_vuart_command(vuart, cmd);
	else
		wrpc_vuart_term(vuart, keep_term);

	dev_unmap(vuart);

	return 0;
}

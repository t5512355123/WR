/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2017 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <arpa/inet.h>

static int flag_be = 1;

static void show_usage(const char *progname)
{
	printf ("usage: %s [-l|-b] [-h]\n"
		" -l   little endian\n"
		" -b   big endian (default)\n"
		" -h   help\n", progname);
}

static const char *byte_to_binary(const unsigned char *s)
{
	static char b[33];
	unsigned int x;
	int i;
	int d;

	if (flag_be)
		x = (s[0] << 24) | (s[1] << 16) | (s[2] << 8) | (s[3] << 0);
	else
		x = (s[3] << 24) | (s[2] << 16) | (s[1] << 8) | (s[0] << 0);

	for (i = 0; i < 32; i++) {
		d = x & (0x80000000 >> i);
		b[i] = d ? '1' : '0';
	}
	b[32] = '\0';

	return b;
}


int main(int argc, char *argv[])
{
	FILE *f;
	unsigned char bytes[4];
	int i;
	int ram_size;
	int c;

	while ((c = getopt (argc, argv, "lbh")) != -1)
		switch (c) {
		case 'l':
			flag_be = 0;
			break;
		case 'b':
			flag_be = 1;
			break;
		case 'h':
			show_usage (argv[0]);
			return 0;
		case '?':
		default:
			show_usage (argv[0]);
			return 2;
		}

	if (optind + 2 != argc) {
		fprintf(stderr, "bad number of arguments, try -h\n");
		return 2;
	}

	f = fopen(argv[optind], "rb");
	if (!f) {
		fprintf(stderr, "%s: cannot open %s\n", argv[0], argv[optind]);
		return 1;
	}

	ram_size = atoi(argv[optind + 1]);
	ram_size = (ram_size+3)/4;

	for (i = 0; fread(bytes, 1, 4, f); i++) {
		puts(byte_to_binary(bytes));
	}
	//padding
	for(;i<ram_size; ++i) {
		printf("00000000000000000000000000000000\n");
	}

	fclose(f);
	return 0;
}

/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 GSI (www.gsi.de)
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[])
{
	const char *progname = argv[0];
	int i, n;
	FILE* f;
	int be = 1;

	while (argc > 1 && argv[1][0] == '-') {
		if (strcmp(argv[1], "-l") == 0)
			be = 0;
		else if (strcmp(argv[1], "-b") == 0)
			be = 1;
		else {
			fprintf (stderr, "%s: unknown option %s\n",
				 progname, argv[1]);
			return 1;
		}
		argv++;
		argc--;
	}

	if (argc < 3) {
		fprintf (stderr, "usage: %s [-L|-B] INPUT SIZE\n", progname);
		return 1;
	}
	if (!(f = fopen(argv[1], "rb"))) {
		fprintf (stderr, "%s: cannot open %s\n", progname, argv[1]);
		return 1;
	}

	n = atoi(argv[2])/4;

	printf("DEPTH = %d;\n", n);
	printf("WIDTH = 32;\n");
	printf("ADDRESS_RADIX = HEX;\n");
	printf("DATA_RADIX = HEX;\n");
	printf("CONTENT\n");
	printf("BEGIN\n");

	for (i = 0; !feof(f); ++i) {
		unsigned char x[4];
		unsigned v;

		fread(x, 1, 4, f);
		if (be)
			v = (x[0] << 24) | (x[1] << 16) | (x[2] << 8) | x[3];
		else
			v = (x[3] << 24) | (x[2] << 16) | (x[1] << 8) | x[0];
		printf("%x : %08X;\n", i, v);
	}

	/* Pad to length.   */
	for (; i < n; ++i) {
		printf("%x : %08X;\n", i, 0);
	}

	printf("END;\n");
	fclose(f);
	return 0;
}

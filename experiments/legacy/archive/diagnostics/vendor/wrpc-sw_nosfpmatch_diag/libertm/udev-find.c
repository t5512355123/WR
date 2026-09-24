#include <stdio.h>
#include <string.h>

#include "private.h"

int main(int argc, char *argv[])
{
	char *devnode;

	if (argc != 2) {
		fprintf(stderr, "usage: %s {mmc15|mmc14|wrc|wrc-console}\n", argv[0]);
		exit(1);
	}
	devnode = ertm_usb_by_function(argv[1]);
	if (devnode == NULL) {
		fprintf(stderr, "could not find function %s\n", argv[1]);
		exit(1);
	}
	printf("%s\n", devnode);
	return 0;
}

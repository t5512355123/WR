/* just a modified version of the original eb-snoop.c for performance testing */
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

//Linux C stuff
#ifdef LINUX
#include <sys/types.h>
#include <unistd.h>
#endif

#include "../etherbone.h"

unsigned int nOfWrite;
unsigned int nOfRead;

eb_data_t my_read(eb_user_data_t user, eb_address_t address, eb_width_t width) {

  //fprintf(stdout, "Received read to address %08"PRIx64" of %d bits\n", address, width*8);
  nOfRead++;
  return nOfWrite;
}

void my_write(eb_user_data_t user, eb_address_t address, eb_width_t width, eb_data_t data) {
  //fprintf(stdout, "Received write to address %08"PRIx64" of %d bits: %08"PRIx64"\n", address, width*8, data);
  nOfWrite++;
}

int main(int argc, const char** argv) {
  struct eb_handler handler;
  int port;
  int timeExpended;
  eb_socket_t socket;
  
  if (argc != 4) {
    fprintf(stderr, "Syntax: %s <port> <address> <mask>\n", argv[0]);
    return 1;
  }
  
  port = strtol(argv[1], 0, 0);
  handler.base = strtol(argv[2], 0, 0);
  handler.mask = strtol(argv[3], 0, 0);
  
  handler.data = 0;
  handler.read = &my_read;
  handler.write = &my_write;

  nOfWrite = 0;
  nOfRead  = 0;
  
  if (eb_socket_open(port, 0, &socket) != EB_OK) {
    fprintf(stderr, "Failed to open Etherbone socket\n");
    return 1;
  }
  
  if (eb_socket_attach(socket, &handler) != EB_OK) {
    fprintf(stderr, "Failed to attach slave device\n");
    return 1;
  }

  fprintf(stdout, "Snooping on port %d, address %08"PRIx64", mask %08"PRIx64"\n", port, handler.base, handler.mask);	

  while (1) {
    timeExpended = eb_socket_block(socket, 2000000); /* 2 seconds */
	if (timeExpended > 1000000) fprintf(stdout, "nOfWrite %d, nOfRead %d\n", nOfWrite, nOfRead);
    eb_socket_poll(socket);
  }
}

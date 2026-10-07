/* just a modified version of the original eb-snoop.c for performance testing */
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include "../etherbone.h"
#include <sys/types.h>
#ifdef __WIN32
#include <sys/timeb.h>
#endif
#ifdef LINUX
#include <sys/time.h>
#endif

int main(int argc, const char** argv) {
	eb_socket_t				socket;
	eb_device_t				device;
	eb_network_address_t	netaddress;
	eb_address_t			address;
	eb_data_t				data;
	int						stop;
	int						wCount;
	int						nCycles;
	int						i,j;
	double					timePerCycle;
#ifdef __WIN32
	struct _timeb			startTime;
	struct _timeb			stopTime;
#endif
#ifdef LINUX
	struct timeval startTime;
	struct timeval stopTime;
	struct timezone dummyZone;
#endif
  
	if (argc != 6) {
		fprintf(stderr, "Syntax: %s <remote-ip-port> <address> <data> <wCount> <nCycles>  \n", argv[0]);
		return 1;
	}
  
	netaddress	= argv[1];
	address		= strtol(argv[2], 0, 0);
	data		= strtol(argv[3], 0, 0);
	wCount		= strtol(argv[4], 0, 0);
	nCycles		= strtol(argv[5], 0, 0);
  
	if (eb_socket_open(0, 0, &socket) != EB_OK) {
		fprintf(stderr, "Failed to open Etherbone socket\n");
		return 1;
	}
  
	if (eb_device_open(socket, netaddress, EB_DATAX, EB_ADDRX, 3, &device) != EB_OK) {
		fprintf(stderr, "Failed to open Etherbone device\n");
		return 1;
	}
  
	stop = 0;
	fprintf(stdout, "Writing to device %s at %08"PRIx64": %08"PRIx64"\n", netaddress, address, data);
	fflush(stdout);
	
#ifdef __WIN32
	_ftime(&startTime);
#endif
#ifdef LINUX
	gettimeofday(&startTime, &dummyZone);
#endif
	
	for (i=0;i<nCycles;i++)
	{
		eb_cycle_t cycle = eb_cycle_open_read_write(device, 0, 0, address, EB_FIFO);
		for (j=0;j<wCount;j++) eb_cycle_write(cycle, data);
		eb_cycle_close(cycle);
		eb_device_flush(device);
	} //for nCycles...
  
#ifdef __WIN32
	_ftime(&stopTime);
	timePerCycle = (stopTime.time  - startTime.time)    * 1000000.0;
	timePerCycle = (stopTime.millitm - startTime.millitm) * 1000.0 + timePerCycle;
#endif
#ifdef LINUX
	gettimeofday(&stopTime, &dummyZone);
	timePerCycle = (stopTime.tv_sec - startTime.tv_sec) * 1000000;
	timePerCycle = (stopTime.tv_usec - startTime.tv_usec) + timePerCycle;
#endif

	timePerCycle = (double)timePerCycle / (double)nCycles;

	fprintf(stdout, "time per cycle %f us\n", timePerCycle);
  
	if (eb_device_close(device) != EB_OK) {
		fprintf(stderr, "Failed to close Etherbone device\n");
		return 1;
	}
  
	if (eb_socket_close(socket) != EB_OK) {
		fprintf(stderr, "Failed to close Etherbone socket\n");
		return 1;
	}
  
  return 0;
}

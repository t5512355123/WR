// lvEtherbone.c : Defines the entry point for the DLL application.
//
// author  : Dietrich Beck, GSI-Darmstadt
// maintainer: Dietrich Beck, GSI-Darmstadt
// version 16-June-2011
#define MYVERSION "0.03.0"
// purpose : This library provides a wrapper around the Etherbone API. Its main purpose is
//           to provide an interface to Etherbone that can be used with LabVIEW.
//
//
// usage   : For LabVIEW, have a look into the examples of the LabVIEW library lvEtherbone.lvlib
//           Linux: debug/info messages will be displayed on stdout
//           Windows: debug/info messages will be written into a file "lvEtherbone.log". The folder of
//                    that file can be defined with an environment variable LVETHERBONE_LOGPATH.
//
// Required: The following is required to compile this library
//           - Etherbone API, has to be downloaded (ohwr.org)
//           
// Etherbone: The Etherbone API has been developed by Wesley Terpstra. Etherbone has been developed
//            withing the White Rabbit project (ohwr.org).
//
//
//
// Compiling: 
// - Linux: "gmake all", a makefile is in the folder of THIS file 
// - Windows: use MS Visual C++ (compiler options to be set in "Configuration Properties -> 
//								 C/C++ -> Preprocessor Definitions")
//            MSVC project and solution files can be found in the subfolder "visual"
//
// Compiler options:
// - __WIN32:   to be used for compiling on Windows.
// - LINUX:   to be used for compiling on Linux.
//
// -------------------------------------------------------------------------------------------
// License Agreement for this software:
//
// Copyright (C) 2011  Dietrich Beck
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
// Planckstraße 1
// D-64291 Darmstadt
// Germany
// 
// Contact: d.beck@gsi.de 
//
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of
// the License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
// without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.

// You should have received a copy of the GNU General Public License along with this program.
// If not, see <http://www.gnu.org/licenses/>.

// For all questions and ideas contact: d.beck@gsi.de
// Last update: 24-May-2011
// -------------------------------------------------------------------------------------------


//standard includes
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

//visual C stuff
#ifdef __WIN32
#include "stdafx.h"
#include <sys/timeb.h>
#include <process.h> 
#endif

//Linux C stuff
#ifdef LINUX
// #include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#endif

//this library stuff
#include "lvEtherbone.h"
#include "lvEtherboneBasics.h"

//"global" variables used in the dll
volatile	mySocketT		sockets[MAXSOCKETS];			//array of sockets. Each socket is 
															//identified by one element of this array. The "ID" used  
															//is identical to the index of the element.
volatile	myDeviceT		devices[MAXDEVICES];			//array of devices. Each device is 
															//identified by one element of this array. The "ID" used  
															//is identical to the index of the element.
volatile	myHandlerT		handler[MAXHANDLER];			//array of handler. Each handler is
															//identified by one element of this array. The "ID" used  
															//is identical to the index of the element.
volatile	int				lastSocketCreated = -1;			//index of last socket that has been created
volatile	int				lastDeviceCreated = -1;			//index of last device that has been created
volatile	int				lastHandlerCreated = -1;		//index of last handler that has been created

			char			timeString[MAXLEN];				//buffer with string containing time
volatile	int				libInitialized = 0;             //check, if library has been initialized. At the moment, this is experimental

#ifdef __WIN32
FILE						*myStdout;                      //file to be used for printf()
char						fullLogFileName[MAXLEN];        //full file name for logfile
struct _timeb				actTime;                        //time for printing messages
#endif
#ifdef LINUX
time_t						actTime;
#endif

//-----------------------------------------------------------------------------------
// author  : Dietrich Beck, GSI-Darmstadt
// purpose : getTimeString: obtain a string containing the current time
// returns : string containing the time
char *getTimeString()
{
	char *timeline;

#ifdef __WIN32
	_ftime(&actTime);
	timeline = ctime( &(actTime.time));
#endif
#ifdef LINUX
	actTime = time(NULL);
	timeline = ctime(&actTime);
#endif
	sprintf(timeString, "%s", timeline);

	return timeString;
} //getTimeString


//-----------------------------------------------------------------------------------
// author  : Dietrich Beck, GSI-Darmstadt
// purpose : dw_printf: my own version of printf
// returns : 
void ew_printf(char *myString)
{
	printf(myString);
#ifdef __WIN32
	if (myStdout != NULL) fclose(myStdout);
	myStdout = freopen(fullLogFileName, "a+", stdout);
#endif
} //dw_printf


//-----------------------------------------------------------------------------------
// author  : Dietrich Beck, GSI-Darmstadt
// purpose : initMyLib: Initializes this shared library/dll
// returns : void
void initMyLib()
{
	//variables
	int				i;
	char			my_message[MAXLEN];

	if (!libInitialized)
	{

#ifdef __WIN32
		//initialize file name for log file

		if (getenv(EBWRAPPERPATH)) 
		{
			sprintf(fullLogFileName, "%s", getenv(EBWRAPPERPATH));
			if (strlen(fullLogFileName) > 0)	sprintf(fullLogFileName, "%s\\", fullLogFileName);
			//else								sprintf(fullLogFileName, "");
		} //if getenv
		sprintf(fullLogFileName, "%s%s", fullLogFileName, LOGFILENAME);

		//open logfile
		myStdout = freopen(fullLogFileName, "a+", stdout);
#endif

		//initialize sockets
		for (i=0;i<MAXSOCKETS;i++) sockets[i].eb_socketID = -1;
		//block first socket, so that it can not be used and accidental calling with index 0 does not work
		sockets[0].eb_socketID = 1;
		//initialize devices
		for (i=0;i<MAXDEVICES;i++) devices[i].eb_deviceID = -1; 
		//block first callback, so that it can not be used and accidental calling with index 0 does not work
		devices[0].eb_deviceID = 1;
		//initialize handler
		for (i=0;i<MAXHANDLER;i++) handler[i].eb_handlerID = -1; 
		//block first callback, so that it can not be used and accidental calling with index 0 does not work
		handler[0].eb_handlerID = 1;
	
		//initialization
		//serverActive		= 1; 
		//executingCallback	= 0;						//flag indicating a callback is executed
		//ignoreCallbackID	= -1;						//callback ID that is ignored when a callback is received
		//occurrenceLV		= 0;                        //occurrence to be fired when new service data is available
				
#ifdef __WIN32
		if (!getenv(EBWRAPPERPATH))
		{
			sprintf(my_message, "%.19s, PID %d: environment variable %s undefined - no defined folder for file %s \n", getTimeString(), getpid(), EBWRAPPERPATH, LOGFILENAME);
			ew_printf(my_message);
		} //if not getenv 
#endif
		sprintf(my_message, "%.19s, PID %d: lvEtherbone library version %s initialized\n", getTimeString(), getpid(), MYVERSION);
		ew_printf(my_message);

		libInitialized	= 1;
	} //if !libInitialized
} //initMyLib


//-----------------------------------------------------------------------------------
// author  : Dietrich Beck, GSI-Darmstadt
// purpose : deinitMyLib: deinitializes this shared library/dll
// returns : void
void deinitMyLib()
{
	int		i;
	char    my_message[MAXLEN];

	if (libInitialized)
	{	
		for (i=0;i<MAXHANDLER;i++) if (handler[i].eb_handlerID != -1) lveb_handler_detach(i);
		for (i=0;i<MAXDEVICES;i++) if (devices[i].eb_deviceID != -1) lveb_device_close(i);
		for (i=0;i<MAXSOCKETS;i++) if (sockets[i].eb_socketID != -1) lveb_socket_close(i);
		//sleep(1); //hm..., we need this sleep, otherwise something (we receive an exit signal?) happens
		
		sprintf(my_message, "%.19s, PID %d,", getTimeString(), getpid());
		sprintf(my_message, "%s lvEtherbone library deinitialized\n", my_message);
		ew_printf(my_message);
#ifdef __WIN32
		if (myStdout != NULL) fclose(myStdout);
#endif
		libInitialized = 0;
	} //if libInitialized
} //deinitMyLib


//-----------------------------------------------------------------------------------
#ifdef __WIN32
//entry point for dll. Created by MS Visual C++
BOOL APIENTRY DllMain( HANDLE hModule, 
                       DWORD  ul_reason_for_call, 
                       LPVOID lpReserved
					 )
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH: 
	{	
		initMyLib();
		break;
	} // DLL_PROCESS_ATTACH
	case DLL_THREAD_ATTACH: 
		break;
	case DLL_THREAD_DETACH:
		break;
	case DLL_PROCESS_DETACH:
	{
		deinitMyLib();
		break;
	} // DLL_PROCESS_DETACH
		break;
	}
    return TRUE;
} //DLLMain
#endif
#ifdef LINUX
//entry point for shared library (Linux)
void __attribute__ ((constructor)) my_init(void)
{
	initMyLib();
} //initMyLib

//exit point for shared library (Linux)
void __attribute__ ((destructor)) my_fini(void)
{
	deinitMyLib();
} //deinitMyLib
#endif

//-----------------------------------------------------------------------------------
//The following is a calback function that is used for reading data from a virtual
//Etherbone device.
eb_data_t cb_device_read(eb_user_data_t user, eb_address_t address, eb_width_t width) 
{
	myHandlerT		*x	= (myHandlerT *)user;	//just a tmp thing
	eb_data_t		tmp;						//return data indicating a problem
	eb_address_t	offset;						//offset for data

	tmp = address;
	
	//lock handling (just required, if handler is created or destroyed)
	if ((*x).lock == 0)	(*x).lock = 1;			//check for lock, then lock or return
	else return tmp;
	
	//check for unused handler
	if ((*x).eb_handlerID < 0)	return tmp;		//unused handler: return, no unlock needed

	//check for width and address range
	offset = address - (*x).handler.base;
	if ((width > sizeof(eb_data_t)) || (offset + width > (*x).handler.mask) || (offset < 0))
	{
		(*x).lock = 0;
		return tmp;
	}
	
	//obtain data from memory map
	memcpy(&tmp, ((*x).memMap) + offset, width);

	//increment number of read cycles
	(sockets[(*x).eb_socketID].nRead)++;

	//unlock and return data
	(*x).lock = 0;
	return tmp;
} //cb_device_read


//-----------------------------------------------------------------------------------
//The following is a calback function that is used for writing data to a virtual
//Etherbone device.
static void cb_device_write(eb_user_data_t user, eb_address_t address, eb_width_t width, eb_data_t data)
{
	myHandlerT		*x	= (myHandlerT *)user;	//just a tmp thing
	eb_address_t	offset;						//offset for data
	
	//lock handling (just required, if handler is created or destroyed)
	if ((*x).lock == 0)	(*x).lock = 1;			//check for lock, then lock or return
	else return;
	
	//check for unused handler
	if ((*x).eb_handlerID < 0)	return;			//unused handler: return, no unlock needed

	//check for illegal width and address range
	offset = address - (*x).handler.base;
	if ((width > sizeof(eb_data_t)) || (offset + width > (*x).handler.mask) || (offset < 0))
	{
		(*x).lock = 0;
		return;
	}
	
	//copy data to memory map
	memcpy(((*x).memMap) + offset, &data, width);

	//increment number of write cycles
	(sockets[(*x).eb_socketID].nWrite)++;
	
	//unlock and return
	(*x).lock = 0;
	return;
} //cb_device_write


//-----------------------------------------------------------------------------------
//the following is a call-back function that is used when a "client" reads data from 
//an Etherbone device
static void cb_client_read(eb_user_data_t user, eb_status_t status, eb_data_t *data)
{
	myUserDataT	*x	= (myUserDataT *)user;						//temp variable

	(*x).done		= 1;										//set "done" flag
	(*x).status		= status;									//copy status error flag
	if (status == EB_OK) memcpy((*x).data, data, (*x).size);	//copy data
} // cb_client_read

//-----------------------------------------------------------------------------------
//the following is a call-back function that is used when a "client" writes data to
//an Etherbone device
static void cb_client_write(eb_user_data_t user, eb_status_t status, eb_data_t *data)
{
	myUserDataT	*x	= (myUserDataT *)user;						//temp variable

	(*x).status		= status;									//copy status error flag
} // cb_client_write



//-----------------------------------------------------------------------------------
/*static void set_stop_single(eb_user_data_t user, eb_status_t status, eb_data_t data)
{
	myUserDataT	*x	= (myUserDataT *)user;			//temp variable
	
	(*x).done		= 1;							//set "done" flag
	memcpy((*x).data, &data, (*x).size);			//copy data

} // set_stop_single
*/


//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_socket_open(	int	port,			//port number
									int	flags,			//flags 
									int	*eb_socketID	//very important socket ID
								   )
{
	int			my_socketID  = -1;
    int			restartSearch = 1;
	int			i;
	eb_status_t	myStatus;
	eb_socket_t	mySocket;

	*eb_socketID = -1;

	// get index of of element in the array "sockets". First search from
    // index of last socket that has been created to MAXSOCKETS
	i = lastSocketCreated;
	if ((i < 0) || (i >= MAXSOCKETS)) i = 0;
	while ((i < MAXSOCKETS) && (my_socketID == -1))
	{
		i++;
		if ((i == MAXSOCKETS) && (restartSearch)) {i = 0; restartSearch = 0;}
		if (sockets[i].eb_socketID == -1) my_socketID = i;
	}
	
	//index valid? create socket
	if ((my_socketID >= 0) && (my_socketID < MAXSOCKETS))
	{
		//remember last (this) socket that has been created
		lastSocketCreated = my_socketID;

		//create socket
		myStatus = eb_socket_open(port, flags, &mySocket);
		if (myStatus == EB_FAIL) return LVEB_OS;
		if (myStatus == EB_BUSY) return LVEB_PORT;
		sockets[my_socketID].eb_socket		= mySocket;
		sockets[my_socketID].eb_socketID	= my_socketID;
		sockets[my_socketID].eb_activity	= EBACT_UNKNOWN;
	}
	else return	LVEB_ID;

	*eb_socketID = my_socketID;
	return LVEB_OK;
} // lveb_socket_open

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_socket_close(int eb_socketID	//very important socket ID
				 				   )
{
	eb_status_t	myStatus;

	//check range
	if ((eb_socketID < 0) || (eb_socketID >= MAXSOCKETS)) return LVEB_ID;
	if (sockets[eb_socketID].eb_socketID != eb_socketID) return LVEB_ID;

	//remove socket
	myStatus = eb_socket_close(sockets[eb_socketID].eb_socket);
	if (myStatus != EB_OK) return LVEB_SOCKET;

    //set element to default values
	sockets[eb_socketID].eb_socketID    = -1;

	//take care that next service to be created will use the array element of this service
	lastSocketCreated = eb_socketID - 1;

	return LVEB_OK;
}// lveb_socket_close

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_socket_wait4Activity(int eb_socketID,	//very important socket ID
											int timeout,		//timeout [ms]
											int *lastActivity,	//last activity on socket
											int *nRead,			//nOf read cycles
											int *nWrite			//nOf write cycles
				 							)
{
	int			usTimeout;
	int			elapsedTime;
	
	//check range
	if ((eb_socketID < 0) || (eb_socketID >= MAXSOCKETS)) return LVEB_ID;
	if (sockets[eb_socketID].eb_socketID != eb_socketID) return LVEB_ID;

	//wait
	usTimeout = timeout * 1000;
	elapsedTime = eb_socket_block(sockets[eb_socketID].eb_socket, usTimeout);
	eb_socket_poll(sockets[eb_socketID].eb_socket);

	//activity flag
	*nRead	= sockets[eb_socketID].nRead;
	*nWrite	= sockets[eb_socketID].nWrite;
	if (usTimeout == elapsedTime)		*lastActivity = EBACT_TIMEDOUT;
	else 
	{
		if (*nRead && *nWrite)			*lastActivity = EBACT_RW;
		else if (*nRead && !*nWrite)	*lastActivity = EBACT_READ;
		else if (!*nRead && *nWrite)	*lastActivity = EBACT_WRITE;
		else							*lastActivity = sockets[eb_socketID].eb_activity;
	} //else timeout
	sockets[eb_socketID].eb_activity	= EBACT_UNKNOWN;
	sockets[eb_socketID].nRead			= 0;
	sockets[eb_socketID].nWrite			= 0;

	return LVEB_OK;
}//lveb_socket_blockNPoll

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_handler_attach(	int				eb_socketID,	//Etherbone socket ID
										eb_address_t	baseAddress,	//base address of THIS device
										eb_address_t	maskAddress,	//memory mask (range) of THIS device
										int				*eb_handlerID	//ID of the handler of THIS device
									 )
{	
	int				my_handlerID  = -1;
    int				restartSearch = 1;
	int				i;
	eb_status_t		myStatus;
		
	*eb_handlerID = -1;
	//check range
	if ((eb_socketID < 0) || (eb_socketID >= MAXSOCKETS))	return LVEB_ID;
	if (sockets[eb_socketID].eb_socketID != eb_socketID)	return LVEB_ID;
	if (baseAddress < 0x8000)								return LVEB_ADDRESS;
	
	// get index of of element in the array "handler". First search from
    // index of last handler that has been created to MAXDEVICES
	i = lastHandlerCreated;
	if ((i < 0) || (i >= MAXHANDLER)) i = 0;
	while ((i < MAXHANDLER) && (my_handlerID == -1))
	{
		i++;
		if ((i == MAXHANDLER) && (restartSearch)) {i = 0; restartSearch = 0;}
		if (handler[i].eb_handlerID == -1) my_handlerID = i;
	}
	
	//index valid? create device
	if ((my_handlerID >= 0) && (my_handlerID < MAXHANDLER))
	{
		//remember last (this) handler that has been created
		lastHandlerCreated = my_handlerID;

		//lock handler
		handler[my_handlerID].lock			= 1;
		
		//create handler
		handler[my_handlerID].handler.base	= baseAddress;
		handler[my_handlerID].handler.data  = (eb_user_data_t)&(handler[my_handlerID]); //looks strange, but "data" is used to pass information to the callback
		handler[my_handlerID].handler.mask	= maskAddress;
		handler[my_handlerID].handler.read	= &cb_device_read;
		handler[my_handlerID].handler.write = &cb_device_write;
		myStatus = eb_socket_attach(sockets[eb_socketID].eb_socket, &(handler[my_handlerID].handler));
		if (myStatus == EB_FAIL) return LVEB_EB;
		if (myStatus == EB_ADDRESS) return LVEB_DEVICEEXIST;
		handler[my_handlerID].eb_socketID	= eb_socketID;
		handler[my_handlerID].memMap		= malloc(maskAddress);
		handler[my_handlerID].eb_handlerID	= my_handlerID;
		handler[my_handlerID].lock			= 0;
	}
	else return	LVEB_ID;

	*eb_handlerID = my_handlerID;
	return LVEB_OK;
}// lveb_handler_attach

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_handler_detach(int eb_handlerID) 
{
	eb_status_t	myStatus;

	//check range
	if ((eb_handlerID < 0) || (eb_handlerID >= MAXHANDLER)) return LVEB_ID;
	if (handler[eb_handlerID].eb_handlerID != eb_handlerID) return LVEB_ID;

	//lock handler
	handler[eb_handlerID].lock	= 1;

	//remove handler
	myStatus = eb_socket_detach(sockets[handler[eb_handlerID].eb_socketID].eb_socket, handler[eb_handlerID].handler.base);
	free(handler[eb_handlerID].memMap);
	
    //set element to default values
	handler[eb_handlerID].eb_handlerID	= -1;
	handler[eb_handlerID].eb_socketID	= -1;
	handler[eb_handlerID].handler.base	= 0;
	handler[eb_handlerID].handler.data	= NULL;
	handler[eb_handlerID].handler.mask	= 0;
	handler[eb_handlerID].handler.read	= NULL;
	handler[eb_handlerID].handler.write	= NULL;
	handler[eb_handlerID].lock			= 1;
	handler[eb_handlerID].memMap		= NULL;
	
	//take care that next handler to be created will use the array element of this service
	lastHandlerCreated = eb_handlerID - 1;

	if (myStatus == EB_OK)	return LVEB_OK;
	else					return LVEB_DEVICEEXIST;
}// lveb_handler_detach

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_handler_getMap(	int				eb_handlerID,	//ID of the handler of THIS device
										eb_address_t	address,		//address where to read from
										int				size,			//size of data to read
										char			*data			//buffer containing read-data
									  )
{
	eb_address_t	offset;

	//check range
	if ((eb_handlerID < 0) || (eb_handlerID >= MAXHANDLER)) return LVEB_ID;
	if (handler[eb_handlerID].eb_handlerID != eb_handlerID) return LVEB_ID;

	//check for width and address range
	offset = address - handler[eb_handlerID].handler.base;
	if (offset < 0)											return LVEB_ADDRESS;
	if (offset + size > handler[eb_handlerID].handler.mask) return LVEB_ADDRESS;
	
	//obtain data from memory map
	memcpy(data, handler[eb_handlerID].memMap + offset, size);

	return LVEB_OK;
} //lveb_handler_getMap

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_handler_setMap( int			eb_handlerID,	//ID of the handler of THIS device
									   eb_address_t	address,		//address where to data is written to
									   int			size,			//size of data to write
									   char			*data			//buffer containing write-data
									   )
{
	eb_address_t	offset;
	
	//check range
	if ((eb_handlerID < 0) || (eb_handlerID >= MAXHANDLER)) return LVEB_ID;
	if (handler[eb_handlerID].eb_handlerID != eb_handlerID) return LVEB_ID;

	//check for width and address range
	offset = address - handler[eb_handlerID].handler.base;
	if (offset < 0)											return LVEB_ADDRESS;
	if (offset + size > handler[eb_handlerID].handler.mask) return LVEB_ADDRESS;
	
	//copy data from memory map
	memcpy(handler[eb_handlerID].memMap + offset, data, size);

	return LVEB_OK;
} //lveb_handler_setMap

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_open(	int		eb_socketID,			//Etherbone socket ID
									char	*ip_port,				//IP port in the format "IP:PORT"
									int		proposed_addr_widths,	//widths of addresses (range)
									int		proposed_port_widths,	//widths of port ("data type")
									int		timeout,				//timeout [ms]
									int		*eb_deviceID			//Etherbone device ID
								   )
{	
	int			my_deviceID  = -1;
    int			restartSearch = 1;
	int			i;
	int			attempts;
	eb_status_t	myStatus;
	char		buffer[256];
		
	*eb_deviceID = -1;
	//check range
	if ((eb_socketID < 0) || (eb_socketID >= MAXSOCKETS)) return LVEB_ID;
	if (sockets[eb_socketID].eb_socketID != eb_socketID) return LVEB_ID;
	
	// get index of of element in the array "devices". First search from
    // index of last device that has been created to MAXDEVICES
	i = lastDeviceCreated;
	if ((i < 0) || (i >= MAXDEVICES)) i = 0;
	while ((i < MAXDEVICES) && (my_deviceID == -1))
	{
		i++;
		if ((i == MAXDEVICES) && (restartSearch)) {i = 0; restartSearch = 0;}
		if (devices[i].eb_deviceID == -1) my_deviceID = i;
	}
	
	//index valid? create device
	if ((my_deviceID >= 0) && (my_deviceID < MAXDEVICES))
	{
		//remember last (this) device that has been created
		lastDeviceCreated = my_deviceID;

		//create device
		attempts = (int)ceil(timeout/3000.0); //units of attemps is three seconds!!
		sprintf(buffer,  "aw: %d, pw: %d\n", proposed_addr_widths, proposed_port_widths);
		ew_printf(buffer);
		myStatus = eb_device_open(sockets[eb_socketID].eb_socket, (eb_network_address_t)ip_port, (eb_width_t)proposed_addr_widths, (eb_width_t)proposed_port_widths, attempts, &(devices[my_deviceID].device));
		
		if (myStatus == EB_ADDRESS) return LVEB_IP;
		if (myStatus == EB_FAIL) return LVEB_EB;
		if (myStatus == EB_WIDTH) return LVEB_PORT;

		devices[my_deviceID].eb_socketID	= eb_socketID;
		devices[my_deviceID].eb_deviceID	= my_deviceID;
	}
	else return	LVEB_ID;

	*eb_deviceID = my_deviceID;
	return LVEB_OK;
}// lveb_device_open

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_close(int eb_deviceID		//ID of Wishbone devie
								   )
{
	eb_status_t	myStatus;

	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;

	//remove device
	myStatus = eb_device_close(devices[eb_deviceID].device);
	if (myStatus != EB_OK) return LVEB_DEVICEBUSY;

    //set element to default values
	devices[eb_deviceID].eb_socketID    = -1;
	devices[eb_deviceID].eb_deviceID    = -1;

	//take care that next service to be created will use the array element of this service
	lastDeviceCreated = eb_deviceID - 1;

	return LVEB_OK;
}// lveb_device_close

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_width(int eb_deviceID,	//ID of Wishbone device
									int	*width			//width of bus (eb_width_t)
								   )
{
	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;
	
	*width = eb_device_width(devices[eb_deviceID].device);
	
	return LVEB_OK;
}// lveb_device_width


//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_flush(int eb_deviceID		//ID of Wishbone device
								    )
{
	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;
	eb_device_flush(devices[eb_deviceID].device);

	return LVEB_OK;
}// lveb_device_flush

/*
//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_read_single(	int			eb_deviceID,	//ID of Wishbone device
											uint64_t	address,		//address to read
											uint64_t	*data,			//data that is read
											int			timeout			//timeout in milliseconds
										  )
{
	int			myTimeout; //timeout in us
	int			mySocketID;
	myUserDataT	myUserData;

	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;

	myTimeout	= timeout * 1000;
	mySocketID	= devices[eb_deviceID].eb_socketID;
	myUserData.done = 0;
	myUserData.size	= sizeof(uint64_t);
	myUserData.data = malloc(myUserData.size);

	eb_device_read(devices[eb_deviceID].eb_device, (eb_address_t)address, &myUserData, &set_stop_single);
	eb_device_flush(devices[eb_deviceID].eb_device);
	while(!myUserData.done && timeout > 0)
	{
		timeout -= eb_socket_block(sockets[mySocketID].eb_socket, myTimeout);
		eb_socket_poll(sockets[mySocketID].eb_socket);
	}
	memcpy(data, myUserData.data, myUserData.size);
	free(myUserData.data);

	if (!myUserData.done) return EB_FAIL;
	return EB_OK;
}// lveb_device_read_single

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_write_single(int			eb_deviceID,	//ID of Wishbone device
											uint64_t	address,		//address to write
											uint64_t	data			//data that is written
										   )
{
	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;

	eb_device_write(devices[eb_deviceID].eb_device, (eb_address_t)address, (eb_data_t)data);

	return LVEB_OK;
}// lveb_device_write_single
*/

//-----------------------------------------------------------------------------------
ETHERBONE_API int lveb_device_read_write(	int			eb_deviceID,	//ID of Wishbone device
											uint64_t	addressR,		//address to read
											int			modeR,			//mode for reading (eb_mode_t)
											int			nR,				//number of read operations; no reading if 0
											uint64_t	*dataR,			//data that is read
											uint64_t	addressW,		//address to write
											int			modeW,			//mode for writing (eb_mode_t)
											int			nW,				//number of write operations; no writing if 0
											uint64_t	*dataW,			//data that is written
											int			timeout			//timeout [ms]
										 )
{
	int			i;
	eb_cycle_t	cycle;
	int			myTimeout; //timeout in us
	int			mySocketID;
	myUserDataT	myUserData;
		
	//check range
	if ((eb_deviceID < 0) || (eb_deviceID >= MAXDEVICES)) return LVEB_ID;
	if (devices[eb_deviceID].eb_deviceID != eb_deviceID) return LVEB_ID;

	myTimeout			= timeout * 1000; // ms -> us
	mySocketID			= devices[eb_deviceID].eb_socketID;
	myUserData.status	= EB_OK;

	if (nR > 0)
	{
		myUserData.size	= nR * sizeof(uint64_t);
		myUserData.data = malloc(myUserData.size);
		myUserData.done	= 0;
		cycle = eb_cycle_open_read_write(devices[eb_deviceID].device, &myUserData, &cb_client_read, addressW, modeW);
		for (i=0;i<nR;i++) eb_cycle_read(cycle, addressR+(i*8*modeR));
	}
	else cycle = eb_cycle_open_read_write(devices[eb_deviceID].device, &myUserData, &cb_client_write, addressW, modeW);
	if (myUserData.status != EB_OK) ew_printf("oha1 \n");
	else ew_printf("ok1 \n");
	for (i=0;i<nW;i++) eb_cycle_write(cycle, dataW[i]);
	if (myUserData.status != EB_OK) ew_printf("oha2 \n");
	else ew_printf("ok2 \n");
	
	eb_cycle_close(cycle);
	if (myUserData.status != EB_OK) ew_printf("oha3 \n");
	else ew_printf("ok3 \n");
	lveb_device_flush(eb_deviceID);
  	
	if (nR > 0)
	{
		while (!myUserData.done && myTimeout > 0) {
			myTimeout -= eb_socket_block(sockets[mySocketID].eb_socket, myTimeout);
			eb_socket_poll(sockets[mySocketID].eb_socket);
		}

		memcpy(dataR, myUserData.data, myUserData.size);
		free(myUserData.data);
	}
	
	if (myUserData.status == EB_OK) return LVEB_OK;
	else if (myUserData.status == EB_ADDRESS) return LVEB_ADDRESSWITDH;
	else if (myUserData.status == EB_WIDTH) return LVEB_PORTWIDTH;
	else return LVEB_OVERFLOW;
} //lveb_device_read_write

ETHERBONE_API void lveb_get_version(	char	*lvebVersion,				//version of lvEtherbone library
										char	*ebVersion					//version of Etherbone API
									)
{
	sprintf(lvebVersion, MYVERSION);
	sprintf(ebVersion, "UNKNOWN");
} //lveb_get_version

// Copyright (C) 2011
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
//
// Author: Wesley W. Terpstra <w.terpstra@gsi.de>
// converted in Delphi: M.Zweig
// not everything was converted

unit etherbone;
interface

uses
 Classes, SysUtils;

// Opaque structural types
type eb_socket =  record end;
type eb_socket_t =  ^eb_socket;

type eb_device =  record end;
type eb_device_t =  ^eb_device;

type eb_cycle =  record end;
type eb_cycle_t =  ^eb_cycle;

// Configurable types */
type eb_address_t = Int64;
type eb_data_t    = Int64;

// Control types */
type eb_descriptor_t =  Integer;
type eb_network_address_t = PChar;

//Status codes
type  eb_status=(
  EB_OK=0,
  EB_FAIL,
  EB_ABORT,
  EB_ADDRESS,
  EB_OVERFLOW,
  EB_BUSY
);

type eb_mode  =(
  EB_UNDEFINED=-1,
  EB_FIFO,
  EB_LINEAR
);

type eb_status_t = eb_status;
type eb_mode_t   = eb_mode;

//Bitmasks cannot be enums */
type eb_width_t = Word;

const
EB_DATA8	=$1;
EB_DATA16	=$2;
EB_DATA32	=$4;
EB_DATA64	=$8;
EB_DATAX	=$f;

// Callback types
type eb_user_data_t = Pointer;
type eb_read_callback_t =procedure (var user: eb_user_data_t;
                                    var status: eb_status_t;
                                    var result:eb_data_t );cdecl;


type b_cycle_callback_t = procedure(var user: eb_user_data_t;
                                    var status: eb_status_t;
                                    var result:eb_data_t );cdecl;

//todo:
{ Handler descriptor */
typedef struct eb_handler {
  eb_address_t base;
  eb_address_t mask;

  eb_user_data_t data;

  eb_data_t (*read) (eb_user_data_t, eb_address_t, eb_width_t);
  void      (*write)(eb_user_data_t, eb_address_t, eb_width_t, eb_data_t);
}{ *eb_handler_t;  }

{/****************************************************************************/
/*                                 C99 API                                  */
/****************************************************************************/

/* Open an Etherbone socket for communicating with remote devices.
 * The port parameter is optional; 0 lets the operating system choose.
 * After opening the socket, poll must be hooked into an event loop.
 *
 * Return codes:
 *   OK		- successfully open the socket port
 *   FAIL	- operating system forbids access
 *   BUSY	- specified port is in use (only possible if port != 0)
 */}
 function eb_socket_open(port:Integer;
                         flags:Integer;
                         result:eb_socket_t):eb_status_t;cdecl; external 'etherbone.dll';

{/* Block until the socket is ready to be polled.
 * This function is useful if your program has no event loop of its own.
 * It returns the time expended while waiting.
 */       }
  function eb_socket_block( socket:eb_socket_t;
                            timeout_us:Integer):Integer;cdecl; external 'etherbone.dll';

 { /* Close the Etherbone socket.
 * Any use of the socket after successful close will probably segfault!
 *
 * Return codes:
 *   OK		- successfully closed the socket and freed memory
 *   BUSY	- there are open devices on this socket
 */                  }
  function eb_socket_close(socket: eb_socket_t ):eb_status_t;cdecl; external 'etherbone.dll';

{/* Poll the Etherbone socket for activity.
 * This function must be called regularly to receive incoming packets.
 * Either call poll very often or hook a read listener on its descriptor.
 * Callback functions are only executed from within the poll function.
 *
 * Return codes:
 *   OK		- poll complete; no further packets to process
 *   FAIL       - socket error (probably closed)
 */        }
  function eb_socket_poll(socket: eb_socket_t ):eb_status_t;cdecl; external 'etherbone.dll';

 {/* Open a remote Etherbone device.
 * This resolves the address and performs Etherbone end-point discovery.
 * From the mask of proposed bus widths, one will be selected.
 * The default port is taken as 0xEBD0.
 *
 * Return codes:
 *   OK		- the remote etherbone device is ready
 *   FAIL	- the remote address did not identify itself as etherbone conformant
 *   ADDRESS	- the network address could not be parsed
 *   ABORT      - could not negotiate an acceptable data bus width
 */    }
 function eb_device_open(socket: eb_socket_t;
                        ip_port: eb_network_address_t;
                        proposed_widths: eb_width_t;
                        result: eb_device_t):eb_status_t;cdecl; external 'etherbone.dll';

{* Close a remote Etherbone device.
 *
 * Return codes:
 *   OK		- associated memory has been freed
 *   BUSY	- there are outstanding wishbone cycles on this device
 */   }
 function eb_device_close(device: eb_device_t ):eb_status_t;cdecl; external 'etherbone.dll';

{* Flush commands queued on the device out the socket.
 */          }
 procedure eb_device_flush(socket: eb_device_t );cdecl; external 'etherbone.dll';

{/* Perform a single-read wishbone cycle.
 * Semantically equivalent to cycle_open, cycle_read, cycle_close, device_flush.
 *
 * The given address is read on the remote device.
 * The callback cb(user, status, data) is invoked with the result.
 * The user parameter is passed through uninspected to the callback.
 *
 * Status codes:
 *   OK		- the operation completed successfully
 *   FAIL	- the operation failed due to an wishbone ERR_O signal
 *   ABORT	- an earlier operation failed and this operation was thus aborted
 */  }
 procedure eb_device_read(device : eb_device_t;
                          address: eb_address_t;
                          user   : eb_user_data_t;
                          cb     : eb_read_callback_t);cdecl; external 'etherbone.dll';

{/* Perform a single-write wishbone cycle.
 * Semantically equivalent to cycle_open, cycle_write, cycle_close, device_flush.
 *
 * data is written to the given address on the remote device.
 */       }
 procedure eb_device_write(device  : eb_device_t;
                           address :eb_address_t;
                           data    :eb_data_t);cdecl; external 'etherbone.dll';

implementation

end.

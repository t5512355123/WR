// Copyright (C) 2011
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
//
// Author: M.Zweig
//


unit wrdevice_unit;

interface

uses etherbone,SysUtils,StdCtrls;

type
  Twrdevice = class
  constructor Create;
  function DeviceOpen(netaddress:eb_network_address_t;address :eb_address_t;var status:string):boolean;
  function DeviceClose(var status:string):boolean;
  function DeviceCacheWR(address :eb_address_t;data: eb_data_t;var status:string):boolean;
  function DeviceCacheSend(var status:string):boolean;
  function DeviceRead(cb:eb_read_callback_t;address :eb_address_t;var status:string):boolean;
  procedure DevicePoll();

private
  IsDeviceOpen:boolean;
  socket      :eb_socket_t;
  device      :eb_device_t;

public
end;


implementation

var my_status: eb_status;


constructor Twrdevice.Create;
begin
  inherited;
  IsDeviceOpen:=false;
end;

function Twrdevice.DeviceOpen(netaddress:eb_network_address_t;address :eb_address_t;var status:string):boolean;
begin
  if not (IsDeviceOpen) then begin
    IsDeviceOpen:= true;

    // eb socket oeffnen
    my_status:=eb_socket_open(0, 0, @socket);
    if(my_status<> EB_OK) then begin
      status:='ERROR: Failed to open Etherbone socket';
      IsDeviceOpen:=false;
    end else status:='Open Etherbone socket successful';

    // etherbone device oeffnen
    if(IsDeviceOpen) then begin
      my_status:= eb_device_open(socket, netaddress, EB_DATAX, @device);
      if(my_status<> EB_OK) then begin
        status:='ERROR: Failed to open Etherbone device';
        IsDeviceOpen:=false;
      end else status:= 'Open Etherbone device successful';
    end;
  end;
  DeviceOpen:= IsDeviceOpen;
end;


function Twrdevice.DeviceClose(var status:string):boolean;

var   my_status:eb_status ;

begin
    if(IsDeviceOpen) then begin
      // etherbone device schliessen
      my_status:= eb_device_close(device);
      if(my_status<> EB_OK) then status:= 'ERROR: Failed to close Etherbone device'
      else begin
        status:='Close Etherbone device successful';
        IsDeviceOpen:=false;
      end;

    // eb socket schliesen
    my_status:= eb_socket_close(socket);
    if(my_status<> EB_OK) then status:='ERROR: Failed to close Etherbone socket'
    else begin
      status:='Close Etherbone socket successful';
      IsDeviceOpen:=false;
    end;
  end else status:='Nothing to close here';

  DeviceClose:= not(IsDeviceOpen);
end;


function Twrdevice.DeviceCacheWR(address :eb_address_t;data: eb_data_t;var status:string):boolean;

begin
  if(IsDeviceOpen) then begin
    // daten schreiben
    eb_device_write(device, address, data);
    //eb_device_flush(device);

    status:='Data sending:'+IntToHex(data,32);
    DeviceCacheWR:= true;
  end else begin
    status:='ERROR: Device/socket not open yet';
    DeviceCacheWR:= false;
  end;
end;


function Twrdevice.DeviceCacheSend(var status:string):boolean;
begin
  DeviceCacheSend:=false;
  if(IsDeviceOpen) then begin
    eb_device_flush(device);
    status:= 'The Cache is gone';
    DeviceCacheSend:=true;
  end else status:= 'ERROR: Device/socket not open yet fool';
end;


function Twrdevice.DeviceRead(cb:eb_read_callback_t;address :eb_address_t;var status:string):boolean;

var  stop:integer;

begin
  DeviceRead:=false;
  if(IsDeviceOpen) then begin
    eb_device_read(device, address, @stop, cb);

    eb_device_flush(device);
    DeviceRead:= true;
  end else status:='ERROR: Device/socket not open, buddy';
end;


procedure Twrdevice.DevicePoll();
begin
  if(IsDeviceOpen) then eb_socket_poll(socket);
end;



end.

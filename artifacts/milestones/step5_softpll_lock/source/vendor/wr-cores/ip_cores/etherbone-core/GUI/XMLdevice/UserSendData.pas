// Copyright (C) 2011
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
//
// Author: M.Zweig
//

unit UserSendData;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Buttons, StdCtrls, ExtCtrls,Global, etherbone, wrdevice_unit;

type
  TSendUserdata_Form = class(TForm)
    Panel1: TPanel;
    Label1: TLabel;
    Loop_SpeedButton:TSpeedButton;
    Send_SpeedButton: TSpeedButton;
    Timer1: TTimer;
    DataToWrite_Edit: TEdit;
    Label2: TLabel;
    Offset_Edit: TEdit;
    Label3: TLabel;
    RegArd_Edit: TEdit;
    Panel2: TPanel;
    Send_Label: TLabel;
    Adress_Panel: TPanel;
    Data_Panel: TPanel;
    procedure DataToWrite_EditKeyPress(Sender: TObject; var Key: Char);
    procedure RegArd_EditKeyPress(Sender: TObject; var Key: Char);
    procedure Offset_EditKeyPress(Sender: TObject; var Key: Char);
    procedure Loop_SpeedButtonClick(Sender: TObject);
    procedure Send_SpeedButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    function ReadUserInput(var WrPacket:TWrPacket):boolean;
    const
      Text_Send= 'Sending...';

  public
    { Public-Deklarationen }
  end;


Var
  SendUserdata_Form:TSendUserdata_Form;

implementation

{$R *.dfm}

procedure TSendUserdata_Form.FormShow(Sender: TObject);
begin
   Send_Label.Caption:='';
end;

procedure TSendUserdata_Form.Timer1Timer(Sender: TObject);
begin
  if(Loop_Speedbutton.Down) or (Send_Speedbutton.Down) then begin
      if(Send_Label.Caption = Text_Send) then Send_Label.Caption:=''
        else Send_Label.Caption:= Text_Send
  end else Send_Label.Caption:='';
  Application.ProcessMessages;
end;

// User daten einmal an device senden
procedure TSendUserdata_Form.Send_SpeedButtonClick(Sender: TObject);

var status:string;
    WrPacket:TWrPacket;

begin
  if(Send_SpeedButton.Down) then begin
    if (ReadUserInput(WrPacket)) then begin
      //  datenanzeigen
      Adress_Panel.Caption:= IntToHex(WrPacket.r.Adr,8);
      Data_Panel.Caption  := IntToHex(WrPacket.r.data,8);
      // daten schreiben
      if not(myDevice.DeviceCacheWR(myAddress,WrPacket.wpack,status)) then
        Application.MessageBox(PChar(status),'Dave? What are you doing?', 16);
      myDevice.DeviceCacheSend(status);
    end;
    Send_SpeedButton.Down:=false;
    Send_SpeedButton.Click;
  end;
end;

// User daten im loop an  die device senden
procedure TSendUserdata_Form.Loop_SpeedButtonClick(Sender: TObject);

var WrPacket:TWrPacket;
    status:string;
    index:integer;

begin
  index:= 0;

  if (ReadUserInput(WrPacket)) then begin
    //  datenanzeigen
    Adress_Panel.Caption:= IntToHex(WrPacket.r.Adr,8);
    Data_Panel.Caption  := IntToHex(WrPacket.r.data,8);

     while(Loop_SpeedButton.Down) do begin
        index:=index+1;

      if (ReadUserInput(WrPacket)) then begin
        // daten schreiben
        if not(myDevice.DeviceCacheWR(myAddress,WrPacket.wpack,status)) then begin
          Application.MessageBox(PChar(status),'Finish Him', 16);
          Loop_SpeedButton.Down:=false;
          Loop_SpeedButton.Click;
        end else myDevice.DeviceCacheSend(status);
      end;

      if((index mod 100)=0) then begin
        index:= 0;
        Application.ProcessMessages;
      end;
    end;
  end;
end;

// User daten uebernehem  und in das record uebertragen
function TSendUserdata_Form.ReadUserInput(var WrPacket:TWrPacket):boolean;

var offset   :LongWord;
    ErrFound :boolean;

begin
  ErrFound:= false;

  while length(Offset_Edit.Text)< 8 do
   Offset_Edit.Text:='0'+Offset_Edit.Text;

  //Offset uebernehem
  try
    offset:= StrToInt('$'+ Offset_Edit.Text);
  except
    Application.MessageBox('This is not a valid hex data', 'You will never win !', 16);
    ErrFound:= true;
  end;

  while length(RegArd_Edit.Text)< 8 do
   RegArd_Edit.Text:='0'+RegArd_Edit.Text;

  //Adresse uebernehmen
  if not(ErrFound) then begin
    try
      WrPacket.r.Adr:=  StrToInt('$'+RegArd_Edit.Text);
    except
      Application.MessageBox('This is not a valid hex Adress', 'You are false data...', 16);
      ErrFound:= true;
    end;
  end;

  while length(DataToWrite_Edit.Text)< 8 do
   DataToWrite_Edit.Text:='0'+DataToWrite_Edit.Text;

 //Daten uebernehmen
  if not(ErrFound) then begin
    try
      WrPacket.r.data:=  StrToInt('$'+ DataToWrite_Edit.Text);
    except
      Application.MessageBox('This is not a valid hex Adress', 'Let there be light...', 16);
      ErrFound:= true;
    end;
  end;

  //Adresse + Offset -> device prefix
  if  not(ErrFound) then begin
    WrPacket.r.Adr:= WrPacket.r.Adr + offset;
  end;

  ReadUserInput:= not(ErrFound)
end;



procedure TSendUserdata_Form.Offset_EditKeyPress(Sender: TObject;
  var Key: Char);
begin
     if not(Key in ['0'..'9', 'A'..'F', 'a'..'f'])or (length(Offset_Edit.Text)>= 8) then begin
      //Edit_WR_Constant.Text:='0000';
     Key:= #0;
   end;
end;

procedure TSendUserdata_Form.RegArd_EditKeyPress(Sender: TObject;
  var Key: Char);
begin
begin
  if not(Key in ['0'..'9', 'A'..'F', 'a'..'f'])or (length(RegArd_Edit.Text)>= 8) then begin
     //Edit_WR_Constant.Text:='0000';
     Key:= #0;
  end;
end;
end;

procedure TSendUserdata_Form.DataToWrite_EditKeyPress(Sender: TObject;
  var Key: Char);
begin
begin
  if not(Key in ['0'..'9', 'A'..'F', 'a'..'f'])or (length(DataToWrite_Edit.Text) >= 8) then begin
     //Edit_WR_Constant.Text:='0000';
     Key:= #0;
  end;
end;
end;

end.
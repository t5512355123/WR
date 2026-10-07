// Copyright (C) 2011
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
//
// Author: M.Zweig
//

unit device_setup;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls,etherbone, Global;

type
  TDevSet_Form = class(TForm)
    Panel1: TPanel;
    DevAdr_Edit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    PortNr_Edit: TEdit;
    OK: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKClick(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  DevSet_Form: TDevSet_Form;

implementation

{$R *.dfm}

procedure TDevSet_Form.OKClick(Sender: TObject);

var error:boolean;

begin
  error:= false;
  myDNSAdress:= DevAdr_Edit.Text;

  try
    myAddress  := StrToInt('$'+ PortNr_Edit.Text);
  except
    Application.MessageBox('This is not a valid hex-adress', 'So What ?', 16);
    error:= true;
  end;

  if not (error) then DevSet_Form.Close;

end;

procedure TDevSet_Form.FormShow(Sender: TObject);
begin
  DevAdr_Edit.Text:= myDNSAdress;
  PortNr_Edit.Text:= IntToHex(myAddress, 4);
end;

procedure TDevSet_Form.FormCreate(Sender: TObject);
begin
  DevAdr_Edit.Text:= First_DNSAdress;
  PortNr_Edit.Text:= First_PortNumber;
  myDNSAdress:= First_DNSAdress;
  myAddress  := StrToInt('$'+ First_PortNumber);
end;

end.

program WR;

uses
  Forms,
  XML_WR in 'XML_WR.pas' {Form1},
  wrdevice_unit in 'wrdevice_unit.pas',
  device_setup in 'device_setup.pas' {DevSet_Form},
  device_unit in 'device_unit.pas',
  Global in 'Global.pas',
  UserSendData in 'UserSendData.pas' {SendUserdata_Form},
  etherbone in '..\..\api\etherbone.pas',
  XML_collector in 'XML_collector.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDevSet_Form, DevSet_Form);
  Application.CreateForm(TSendUserdata_Form, SendUserdata_Form);
  Application.Run;
end.






















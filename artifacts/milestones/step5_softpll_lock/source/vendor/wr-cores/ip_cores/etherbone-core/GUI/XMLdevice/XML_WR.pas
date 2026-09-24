// Copyright (C) 2011
// GSI Helmholtzzentrum für Schwerionenforschung GmbH
//
// Author: M.Zweig
//


unit XML_WR;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, xmldom, XMLIntf, Menus, msxmldom, XMLDoc, ComCtrls, ExtCtrls,
  StdCtrls,wrdevice_unit, device_setup,etherbone,Global,UserSendData,XML_collector;

type
  TForm1 = class(TForm)
    Panel1: TPanel;
    XML_TreeView: TTreeView;
    Label1: TLabel;
    Panel2: TPanel;
    messages_ListBox: TListBox;
    Clear_Button: TButton;
    Panel3: TPanel;
    Panel4: TPanel;
    Label2: TLabel;
    DeviceActiv_Shape: TShape;
    Panel5: TPanel;
    SendData_Button: TButton;
    Label3: TLabel;
    PollSocket_Timer: TTimer;
    OpenDialog1: TOpenDialog;
    MainMenu1: TMainMenu;
    D1: TMenuItem;
    XMLLaden1: TMenuItem;
    Exit1: TMenuItem;
    Device1: TMenuItem;
    ConnectDevice1: TMenuItem;
    DisconnectDevice1: TMenuItem;
    Setup1: TMenuItem;
    XMLDoc: TXMLDocument;
    Extras1: TMenuItem;
    SendManual1: TMenuItem;
    Panel6: TPanel;
    ReadData_Button: TButton;
    LoopSD_CheckBox: TCheckBox;
    Lamp_Timer: TTimer;
    LoopRD_CheckBox: TCheckBox;
    Panel7: TPanel;
    Label4: TLabel;
    PaketsCnt_Panel: TPanel;
    Label5: TLabel;
    Sendings_Panel: TPanel;
    ClearCnt_Button: TButton;
    procedure ClearCnt_ButtonClick(Sender: TObject);
    procedure LoopRD_CheckBoxClick(Sender: TObject);
    procedure Lamp_TimerTimer(Sender: TObject);
    procedure LoopSD_CheckBoxClick(Sender: TObject);
    procedure SendData_ButtonClick(Sender: TObject);
    procedure XMLLaden1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure SendManual1Click(Sender: TObject);
    procedure ReadData_ButtonClick(Sender: TObject);
    //procedure myCallback(var user: eb_user_data_t; var status: eb_status_t; var data:eb_data_t );
    procedure PollSocket_TimerTimer(Sender: TObject);
    procedure Clear_ButtonClick(Sender: TObject);
    procedure DisconnectDevice1Click(Sender: TObject);
    procedure ConnectDevice1Click(Sender: TObject);
    procedure Setup1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure SendPacketsaway(offset:longword);
    procedure NodeGetAttribute(node:IXMLNode; var kindknoten:TTreeNode; knoten:TTreeNode);
    procedure UpdateCntPanels();
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  Form1        :TForm1;
  myStatus     :string;
  XML_collector:TXML_collector;
  myDeviceisOpen:boolean;

implementation

{$R *.dfm}

procedure myCallback(var user: eb_user_data_t; var status: eb_status_t; var data:eb_data_t );

begin
  Form1.messages_ListBox.Items.Add('Data receive: '+IntToHex(data,32));
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  myDevice:= Twrdevice.Create;
  myDeviceisOPen:=false;
  PaketsCnt_Panel.Caption:='0';
  Sendings_Panel.Caption:='0';
  SendingCnt  := 0;
  PaketCnt    := 0;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin

  myDeviceisOPen:=false;
  LoopSD_CheckBox.Checked:=false;

  Form1.Update;
  Application.ProcessMessages();

  myDevice.DeviceClose(myStatus);
  myDevice.Free;
end;

procedure TForm1.Setup1Click(Sender: TObject);
begin
  DevSet_Form.Show;
end;

procedure TForm1.ConnectDevice1Click(Sender: TObject);
begin
  messages_ListBox.Items.Add('Try to Open: '+ myDNSAdress+
                             ' Port:'+IntTohex(myAddress,4));
  messages_ListBox.TopIndex:= messages_ListBox.Items.Count-1;

   if(myDevice.DeviceOpen(Pchar(myDNSAdress), myAddress, myStatus)) then begin
      DeviceActiv_Shape.Brush.Color:=clLime;
      myDeviceisOPen:=true;
   end else DeviceActiv_Shape.Brush.Color:=clRed;

   messages_ListBox.Items.Add('Device Open: '+myStatus);
   messages_ListBox.TopIndex:= messages_ListBox.Items.Count-1;
end;

procedure TForm1.DisconnectDevice1Click(Sender: TObject);
begin
  if(myDevice.DeviceClose(myStatus)) then begin
    DeviceActiv_Shape.Brush.Color:= clRed;
    myDeviceisOPen:=false;
  end else DeviceActiv_Shape.Brush.Color:=clYellow;

  messages_ListBox.Items.Add('Device Close: '+myStatus);
  messages_ListBox.TopIndex:= messages_ListBox.Items.Count-1;
end;

procedure TForm1.Clear_ButtonClick(Sender: TObject);
begin
   messages_ListBox.Items.Clear;
end;

procedure TForm1.PollSocket_TimerTimer(Sender: TObject);
begin
  myDevice.DevicePoll();
end;

procedure TForm1.ReadData_ButtonClick(Sender: TObject);
begin
  if not(myDevice.DeviceRead(@myCallback, myAddress, myStatus))  then begin
    messages_ListBox.Items.Add('Device Read: '+myStatus);
    messages_ListBox.TopIndex:= messages_ListBox.Items.Count-1;
  end;
end;

procedure TForm1.SendManual1Click(Sender: TObject);
begin
  SendUserdata_Form.Show();
end;

procedure TForm1.Exit1Click(Sender: TObject);
begin
  Form1.Close;
end;

procedure TForm1.XMLLaden1Click(Sender: TObject);

var
  node   : IXMLNode;
  nodes  : IXMLNodeList;
  knoten : TTreeNode;
  s      : string;
  i      : integer;

 procedure erweitere(node : IXMLNode;knoten : TTreeNode);
  var
    nodes      : IXMLNodeList;
    kindknoten : TTreeNode;
    i          : integer;
  begin
    if node.HasChildNodes then
    begin
      nodes := node.ChildNodes;
      for i := 0 to nodes.Count - 1 do
      begin
        case nodes[i].NodeType of
          ntElement   : NodeGetAttribute(nodes[i],kindknoten,knoten);
          ntText      : kindknoten := XML_TreeView.Items.AddChild(knoten,nodes[i].text);
        end; // of case
        erweitere(nodes[i],kindknoten);
      end;
    end;
  end;

begin
  if OpenDialog1.Execute then
  try
    XML_TreeView.Items.Clear;
    XMLDoc.LoadFromFile(OpenDialog1.FileName);
    node := XMLDoc.DocumentElement;
    nodes := node.AttributeNodes;
    s := '';
    for i := 0 to nodes.Count - 1 do
      s := s + nodes[i].NodeName + ' = ' +nodes[i].NodeValue + '  ';
    knoten := XML_TreeView.Items.Add(nil,'<'+node.NodeName+'>  '+s);
    erweitere(node,knoten);
  except
    on E:Exception do
      messages_Listbox.Items.Add(E.Message);
  end;
end;

procedure TForm1.SendData_ButtonClick(Sender: TObject);

var  index:integer;
     nodes: IXMLNodeList;

begin
  if XMLDoc.Active and myDeviceisOpen then begin
     nodes:= XMLDoc.DocumentElement.ChildNodes;
     for index:=0 to Nodes.Count-1 do begin
        XML_collector.AnalyseXMLTree(Nodes[index].Childnodes);
        SendPacketsaway(StrToInt('$'+VarToStr(Nodes[index].GetAttribute('value'))));
     end;
  end else Application.MessageBox('Device not open or XML not loaded !','Whats up doc?', 16);
end;


procedure TForm1.SendPacketsaway(offset:longword);

var index:integer;
    status:string;
    WrPacket:TWrPacket;
    errorfound:boolean;

begin

  errorfound:=false;

  for index:= 0 to DeviceCtrRegCount-1  do begin
    DeviceCtrReg[index]:= DeviceCtrReg[index] + offset;

    WrPacket.r.Adr := DeviceCtrReg[index];
    WrPacket.r.data:= DeviceData  [index];

    if not(myDevice.DeviceCacheWR(myAddress,WrPacket.wpack,status)) then begin
       messages_ListBox.Items.Add('DeviceCache:'+status);
      errorfound:=true;
    end else PaketCnt:=PaketCnt+1;
  end;

  if not errorfound then begin
    if not (myDevice.DeviceCacheSend(status)) then
      messages_ListBox.Items.Add('DeviceCacheSend:'+status);
      SendingCnt:=SendingCnt+1;
    if not (LoopSD_CheckBox.Checked) then begin
      messages_ListBox.Items.Add('sending....');
      messages_ListBox.TopIndex:= messages_ListBox.Items.Count-1;
      UpdateCntPanels();
    end else begin
      if ((SendingCnt mod 100)=0)then begin
        UpdateCntPanels();
      end;
    end;
  end;
end;

procedure TForm1.NodeGetAttribute(node:IXMLNode; var kindknoten:TTreeNode; knoten:TTreeNode);
begin
  if node.HasChildNodes then begin
    kindknoten := XML_TreeView.Items.AddChild(knoten,'<'+ node.NodeName+'>'+
    '*value:'+VarToStr(node.Attributes['value']));
  end else begin
    kindknoten := XML_TreeView.Items.AddChild(knoten,'<'+
    node.NodeName+'>'+' *value:'+VarToStr(node.Attributes['value'])+
    ' *bitpos:'+ VarToStr(node.Attributes['bitpos']));
  end;
end;


procedure TForm1.LoopSD_CheckBoxClick(Sender: TObject);

var index: integer;

begin
   while LoopSD_CheckBox.Checked and myDeviceisOpen and XMLDoc.Active do begin
    SendData_Button.Enabled:= false;
    SendData_Button.Click;
    index:=index+1;

    if((index mod 100)=0) then begin
      index:= 0;
      Application.ProcessMessages;
    end;
  end;
   LoopSD_CheckBox.Checked:= false;
   SendData_Button.Enabled:= true;
end;


procedure TForm1.Lamp_TimerTimer(Sender: TObject);
begin
  if ((LoopSD_CheckBox.Checked) or (LoopRD_CheckBox.Checked)) and
     (DeviceActiv_Shape.Brush.Color=clLime) then begin
    if DeviceActiv_Shape.Brush.Color = clLime then DeviceActiv_Shape.Brush.Color:=clYellow else
    DeviceActiv_Shape.Brush.Color:=clLime;
  end else if(DeviceActiv_Shape.Brush.Color <> clRed) then DeviceActiv_Shape.Brush.Color:=clLime;
end;

procedure TForm1.LoopRD_CheckBoxClick(Sender: TObject);

var index:integer;

begin
  while LoopRD_CheckBox.Checked and myDeviceisOpen do begin
    ReadData_Button.Enabled:= false;
    index:=index+1;

//    if((index mod 50)=0) then

    if((index mod 100)=0) then begin
      index:= 0;
      ReadData_Button.Click;
      Application.ProcessMessages;
    end;
  end;
  LoopRD_CheckBox.Checked:= false;
  ReadData_Button.Enabled:= true;
end;

procedure TForm1.ClearCnt_ButtonClick(Sender: TObject);
begin
  PaketsCnt_Panel.Caption:='0';
  Sendings_Panel.Caption:='0';
  SendingCnt  := 0;
  PaketCnt    := 0;
end;

procedure TForm1.UpdateCntPanels();
begin
  Sendings_Panel.Caption  :=IntToStr(SendingCnt);
  PaketsCnt_Panel.Caption :=IntToStr(PaketCnt);
end;


end.

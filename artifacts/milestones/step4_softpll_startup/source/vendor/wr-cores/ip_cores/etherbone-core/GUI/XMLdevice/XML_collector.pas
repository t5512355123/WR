unit XML_collector;

interface

uses
  xmldom, XMLIntf, StdCtrls, ComCtrls, ExtCtrls, Menus, msxmldom,
  SysUtils, Variants, XMLDoc, Global;

type
  TXML_collector = class

  public
    { Public-Deklarationen }

  function AnalyseXMLTree   (deep1: IXMLNodeList):boolean;
  procedure ConvertData(var data:longword;BitPosL:Byte;BitPosH:Byte);

  private
  procedure ClearDataClrArray();
      { Private-Deklarationen }
   end;


implementation

//durchsucht den XML-baum und sammelt daten [value] und fomatierungsanweisungen
//bekommt den XML Baum mit der tiefe 1-> deviceXXX ab dann gilt:
//deep1 (led/timer/signal) keine daten keine fomatierungsanweisungen
//deep2 (ctrl/settime/gettime etc) evt. ctr-daten vorhanden
//deep3 (onoff/pwmoutput/startstop etc) endknoten enthalten sende daten/formatierungen
function TXML_collector.AnalyseXMLTree(deep1: IXMLNodeList):boolean;

var deep1_index:integer;
    deep2_index:integer;
    deep2      : IXMLNodeList;
    deep3_index:integer;
    deep3      : IXMLNodeList;
    BitPosL    :Byte;
    BitPosH    :Byte;
    BitPosStr  :String;
    Data       :longword;
    i          :integer;
    StringTemp :string;

begin

  ClearDataClrArray();

  DeviceCtrRegCount:= 0;
  DeviceDataCount  := 0;

  deep1_index:=0;
  while (deep1_index <= deep1.Count-1) do begin //deep1 hat keine daten(led/timer/signal)
    deep2:= deep1[deep1_index].ChildNodes;
    deep2_index:=0;
    while (deep2_index <= deep2.Count-1) do begin //deep 2 hat daten f. ctrl-reg.
      deep3:= deep2[deep2_index].ChildNodes;
      deep3_index:=0;

      if(deep3.Count = 0) then begin //letzte ebene nur daten                            x
          DeviceData[DeviceDataCount]:= 0;
      end;

      while (deep3_index <= deep3.Count-1) do begin  //reine daten, keine ctr
          if(deep3[deep3_index].GetAttribute('bitpos')<>'')then begin
            BitPosStr:= VarToStr(deep3[deep3_index].GetAttribute('bitpos'));
            StringTemp:='';
            i:=1;
            while BitPosStr[i] <> '.' do begin
              StringTemp:= StringTemp+ BitPosStr[i];
              i:=i+1;
            end;

            try
              BitPosL:=StrToInt(StringTemp);
            except
               BitPosL:=0;
            end;

            i:=i+1;
            StringTemp:='';
            while i <= Length (BitPosStr) do begin
              StringTemp:= StringTemp+ BitPosStr[i];
              i:=i+1;
            end;

           try
              BitPosH:=StrToInt(StringTemp);
            except
               BitPosH:=0;
            end;
            data:=  StrToInt('$'+VarToStr(deep3[deep3_index].GetAttribute('value')));
            ConvertData(data,BitPosL,BitPosH);
            DeviceData[DeviceDataCount]:= DeviceData[DeviceDataCount] OR data;
        end;
        deep3_index:=deep3_index + 1;
      end;//deep3
      DeviceCtrReg[DeviceCtrRegCount]:= StrToInt('$'+VarToStr(deep2[deep2_index].GetAttribute('value')));
      DeviceCtrRegCount:=DeviceCtrRegCount+1;
      DeviceDataCount:=DeviceDataCount+1;
      deep2_index:=deep2_index+1;
    end;//deep2
    deep1_index:=deep1_index+1;
  end;//deep1
end;

//convertiere data nach vorgabe im XML Baum
procedure TXML_collector.ConvertData(var data:longword;BitPosL:Byte;BitPosH:Byte);

var mask:longword;

begin
 { mask:=$FFFF;

  mask:=mask SHL (BitPosH-BitPosL);
  data:=data XOR mask;    }

  data:= data SHL BitPosL;
end;

//Loesche Control Register array und Daten array
procedure TXML_collector.ClearDataClrArray();

var i:integer;

begin
  for i:= 0 to ArrayRange do begin
    DeviceCtrReg[i] := 0;
    DeviceData[i]   := 0;
  end;
end;

end.

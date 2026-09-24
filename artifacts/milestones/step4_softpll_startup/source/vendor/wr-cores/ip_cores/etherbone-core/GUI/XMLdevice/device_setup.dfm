object DevSet_Form: TDevSet_Form
  Left = 0
  Top = 0
  Width = 329
  Height = 251
  AutoSize = True
  Caption = 'Device Setup'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 18
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 321
    Height = 161
    BevelInner = bvLowered
    TabOrder = 0
    object Label1: TLabel
      Left = 24
      Top = 16
      Width = 92
      Height = 18
      Caption = 'Device Adress'
    end
    object Label2: TLabel
      Left = 24
      Top = 80
      Width = 87
      Height = 18
      Caption = 'Port Nr.(hex)'
    end
    object DevAdr_Edit: TEdit
      Left = 24
      Top = 37
      Width = 265
      Height = 26
      TabOrder = 0
    end
    object PortNr_Edit: TEdit
      Left = 24
      Top = 104
      Width = 265
      Height = 26
      TabOrder = 1
    end
  end
  object OK: TButton
    Left = 96
    Top = 168
    Width = 145
    Height = 49
    Caption = 'OK'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 1
    OnClick = OKClick
  end
end

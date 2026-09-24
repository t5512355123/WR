object SendUserdata_Form: TSendUserdata_Form
  Left = 0
  Top = 0
  Width = 505
  Height = 275
  AutoSize = True
  Caption = 'Send User data'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 19
  object Loop_SpeedButton: TSpeedButton
    Left = 0
    Top = 208
    Width = 89
    Height = 33
    AllowAllUp = True
    GroupIndex = 1
    Caption = 'Loop'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    OnClick = Loop_SpeedButtonClick
  end
  object Send_SpeedButton: TSpeedButton
    Left = 408
    Top = 208
    Width = 89
    Height = 33
    AllowAllUp = True
    GroupIndex = 1
    Caption = 'Send'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = [fsBold]
    ParentFont = False
    OnClick = Send_SpeedButtonClick
  end
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 497
    Height = 201
    BevelInner = bvLowered
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 139
      Width = 131
      Height = 19
      Caption = 'Data to send (hex)'
    end
    object Label2: TLabel
      Left = 16
      Top = 8
      Width = 79
      Height = 19
      Caption = 'Offset(hex)'
    end
    object Label3: TLabel
      Left = 16
      Top = 72
      Width = 130
      Height = 19
      Caption = 'Register Adr.(hex)'
    end
    object DataToWrite_Edit: TEdit
      Left = 13
      Top = 161
      Width = 250
      Height = 27
      TabOrder = 0
      OnKeyPress = DataToWrite_EditKeyPress
    end
    object Offset_Edit: TEdit
      Left = 15
      Top = 30
      Width = 98
      Height = 27
      TabOrder = 1
      OnKeyPress = Offset_EditKeyPress
    end
    object RegArd_Edit: TEdit
      Left = 15
      Top = 94
      Width = 130
      Height = 27
      TabOrder = 2
      OnKeyPress = RegArd_EditKeyPress
    end
    object Panel2: TPanel
      Left = 272
      Top = 0
      Width = 225
      Height = 201
      BevelInner = bvLowered
      TabOrder = 3
      object Send_Label: TLabel
        Left = 16
        Top = 16
        Width = 80
        Height = 19
        Caption = 'Sending...'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -16
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object Adress_Panel: TPanel
        Left = 15
        Top = 38
        Width = 97
        Height = 25
        BevelInner = bvLowered
        Caption = '00000000'
        TabOrder = 0
      end
      object Data_Panel: TPanel
        Left = 110
        Top = 38
        Width = 97
        Height = 25
        BevelInner = bvLowered
        Caption = '00000000'
        TabOrder = 1
      end
    end
  end
  object Timer1: TTimer
    OnTimer = Timer1Timer
    Left = 224
    Top = 208
  end
end

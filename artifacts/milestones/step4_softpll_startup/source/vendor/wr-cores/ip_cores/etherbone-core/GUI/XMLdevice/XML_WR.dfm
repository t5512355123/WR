object Form1: TForm1
  Left = 0
  Top = 0
  Width = 657
  Height = 601
  AutoSize = True
  Caption = 'whiterabbit'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -16
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 19
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 457
    Height = 385
    BevelInner = bvLowered
    TabOrder = 0
    object Label1: TLabel
      Left = 16
      Top = 7
      Width = 66
      Height = 19
      Caption = 'XML Tree'
    end
    object XML_TreeView: TTreeView
      Left = 15
      Top = 31
      Width = 426
      Height = 338
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      Indent = 19
      ParentFont = False
      TabOrder = 0
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 384
    Width = 504
    Height = 163
    BevelInner = bvLowered
    TabOrder = 1
    object messages_ListBox: TListBox
      Left = 8
      Top = 8
      Width = 487
      Height = 129
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Tahoma'
      Font.Style = []
      ItemHeight = 18
      ParentFont = False
      TabOrder = 0
    end
    object Clear_Button: TButton
      Left = 429
      Top = 140
      Width = 65
      Height = 17
      Caption = 'Clear'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = Clear_ButtonClick
    end
  end
  object Panel3: TPanel
    Left = 448
    Top = 0
    Width = 201
    Height = 386
    BevelInner = bvLowered
    TabOrder = 2
    object Panel4: TPanel
      Left = 0
      Top = 0
      Width = 201
      Height = 49
      BevelInner = bvLowered
      TabOrder = 0
      object Label2: TLabel
        Left = 24
        Top = 13
        Width = 91
        Height = 19
        Caption = 'Device active'
      end
      object DeviceActiv_Shape: TShape
        Left = 148
        Top = 11
        Width = 33
        Height = 25
        Brush.Color = clRed
        Shape = stCircle
      end
    end
    object Panel5: TPanel
      Left = 0
      Top = 46
      Width = 201
      Height = 108
      BevelInner = bvLowered
      TabOrder = 1
      object Label3: TLabel
        Left = 8
        Top = 8
        Width = 46
        Height = 19
        Caption = 'Device'
      end
      object SendData_Button: TButton
        Left = 7
        Top = 39
        Width = 105
        Height = 25
        Caption = 'Send Data'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        OnClick = SendData_ButtonClick
      end
      object Panel6: TPanel
        Left = 0
        Top = 67
        Width = 201
        Height = 41
        BevelInner = bvLowered
        TabOrder = 1
        object ReadData_Button: TButton
          Left = 8
          Top = 8
          Width = 105
          Height = 25
          Caption = 'Read Data'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Tahoma'
          Font.Style = [fsBold]
          ParentFont = False
          TabOrder = 0
          OnClick = ReadData_ButtonClick
        end
        object LoopRD_CheckBox: TCheckBox
          Left = 129
          Top = 12
          Width = 65
          Height = 17
          Caption = 'Loop'
          Enabled = False
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Tahoma'
          Font.Style = []
          ParentFont = False
          TabOrder = 1
          OnClick = LoopRD_CheckBoxClick
        end
      end
      object LoopSD_CheckBox: TCheckBox
        Left = 128
        Top = 43
        Width = 65
        Height = 17
        Caption = 'Loop'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnClick = LoopSD_CheckBoxClick
      end
    end
    object Panel7: TPanel
      Left = 0
      Top = 152
      Width = 201
      Height = 113
      BevelInner = bvLowered
      TabOrder = 2
      object Label4: TLabel
        Left = 8
        Top = 16
        Width = 48
        Height = 18
        Caption = 'Pakets:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
      end
      object Label5: TLabel
        Left = 8
        Top = 56
        Width = 62
        Height = 18
        Caption = 'Sendings:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
      end
      object PaketsCnt_Panel: TPanel
        Left = 80
        Top = 15
        Width = 107
        Height = 26
        BevelInner = bvLowered
        Caption = '0'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
      object Sendings_Panel: TPanel
        Left = 80
        Top = 52
        Width = 107
        Height = 26
        BevelInner = bvLowered
        Caption = '0'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        TabOrder = 1
      end
      object ClearCnt_Button: TButton
        Left = 120
        Top = 87
        Width = 65
        Height = 17
        Caption = 'Clear'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        OnClick = ClearCnt_ButtonClick
      end
    end
  end
  object PollSocket_Timer: TTimer
    Interval = 100
    OnTimer = PollSocket_TimerTimer
    Left = 512
    Top = 392
  end
  object OpenDialog1: TOpenDialog
    Filter = 'XML Files |*.xml'
    Left = 512
    Top = 424
  end
  object MainMenu1: TMainMenu
    Left = 512
    Top = 456
    object D1: TMenuItem
      Caption = 'Datei'
      object XMLLaden1: TMenuItem
        Caption = 'XML-Laden'
        OnClick = XMLLaden1Click
      end
      object Exit1: TMenuItem
        Caption = 'Exit'
        OnClick = Exit1Click
      end
    end
    object Device1: TMenuItem
      Caption = 'Device'
      object Setup1: TMenuItem
        Caption = 'Setup'
        OnClick = Setup1Click
      end
      object ConnectDevice1: TMenuItem
        Caption = 'Connect  Device'
        OnClick = ConnectDevice1Click
      end
      object DisconnectDevice1: TMenuItem
        Caption = 'Disconnect Device'
        OnClick = DisconnectDevice1Click
      end
    end
    object Extras1: TMenuItem
      Caption = 'Extras'
      object SendManual1: TMenuItem
        Caption = 'Send Manual'
        OnClick = SendManual1Click
      end
    end
  end
  object XMLDoc: TXMLDocument
    Left = 512
    Top = 488
    DOMVendorDesc = 'MSXML'
  end
  object Lamp_Timer: TTimer
    OnTimer = Lamp_TimerTimer
    Left = 544
    Top = 392
  end
end

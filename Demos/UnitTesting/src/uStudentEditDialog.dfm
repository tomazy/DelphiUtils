object StudentEditDialog: TStudentEditDialog
  Left = 227
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Student'
  ClientHeight = 176
  ClientWidth = 314
  Color = clBtnFace
  ParentFont = True
  OldCreateOrder = True
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  DesignSize = (
    314
    176)
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 8
    Top = 8
    Width = 212
    Height = 161
    Anchors = [akLeft, akTop, akRight, akBottom]
    Shape = bsFrame
    ExplicitWidth = 281
  end
  object Label1: TLabel
    Left = 16
    Top = 24
    Width = 31
    Height = 13
    Caption = '&Name:'
    FocusControl = edName
  end
  object Label2: TLabel
    Left = 16
    Top = 70
    Width = 28
    Height = 13
    Caption = '&Email:'
    FocusControl = edEmail
  end
  object Label3: TLabel
    Left = 16
    Top = 118
    Width = 65
    Height = 13
    Caption = '&Date of birth:'
    FocusControl = dtpDateOfBirth
  end
  object OKBtn: TButton
    Left = 231
    Top = 8
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 3
  end
  object CancelBtn: TButton
    Left = 231
    Top = 38
    Width = 75
    Height = 25
    Anchors = [akTop, akRight]
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 4
  end
  object edName: TEdit
    Left = 16
    Top = 40
    Width = 186
    Height = 21
    TabOrder = 0
    Text = 'edName'
  end
  object edEmail: TEdit
    Left = 16
    Top = 86
    Width = 186
    Height = 21
    TabOrder = 1
    Text = 'edName'
  end
  object dtpDateOfBirth: TDateTimePicker
    Left = 16
    Top = 134
    Width = 186
    Height = 21
    Date = 40762.733315000000000000
    Time = 40762.733315000000000000
    TabOrder = 2
  end
end

object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Course Demo'
  ClientHeight = 274
  ClientWidth = 502
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  DesignSize = (
    502
    274)
  PixelsPerInch = 96
  TextHeight = 13
  object lvStudents: TListView
    Left = 8
    Top = 39
    Width = 486
    Height = 227
    Anchors = [akLeft, akTop, akRight, akBottom]
    Columns = <
      item
        AutoSize = True
        Caption = 'Name'
      end
      item
        AutoSize = True
        Caption = 'Email'
      end
      item
        Alignment = taRightJustify
        AutoSize = True
        Caption = 'Date of birth'
      end>
    OwnerData = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnData = lvStudentsData
    OnDblClick = lvStudentsDblClick
    OnEditing = lvStudentsEditing
  end
  object btnAddStudent: TButton
    Left = 8
    Top = 8
    Width = 89
    Height = 25
    Action = acNewStudent
    TabOrder = 1
  end
  object btnEditStudent: TButton
    Left = 103
    Top = 8
    Width = 89
    Height = 25
    Action = acEditStudent
    TabOrder = 2
  end
  object btnDeleteStudent: TButton
    Left = 198
    Top = 8
    Width = 89
    Height = 25
    Action = acDeleteStudent
    TabOrder = 3
  end
  object alActions: TActionList
    Left = 8
    Top = 232
    object acNewStudent: TAction
      Caption = '&New Student...'
      ShortCut = 45
      OnExecute = acNewStudentExecute
    end
    object acEditStudent: TAction
      Caption = '&Edit Student...'
      ShortCut = 113
      OnExecute = acEditStudentExecute
      OnUpdate = acEditStudentUpdate
    end
    object acDeleteStudent: TAction
      Caption = '&Delete Student'
      ShortCut = 46
      OnExecute = acDeleteStudentExecute
      OnUpdate = acDeleteStudentUpdate
    end
  end
end

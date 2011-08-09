{
This software is distributed under the BSD license.

Copyright (c) 2011, Tomasz Maszkowski
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of Tomasz Maszkowski may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

History:

}
unit uMainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ActnList, uModel, ComCtrls, StdCtrls;

type
  TMainForm = class(TForm)
    alActions: TActionList;
    acNewStudent: TAction;
    acEditStudent: TAction;
    acDeleteStudent: TAction;
    lvStudents: TListView;
    btnAddStudent: TButton;
    btnEditStudent: TButton;
    btnDeleteStudent: TButton;
    procedure FormCreate(Sender: TObject);
    procedure lvStudentsData(Sender: TObject; Item: TListItem);
    procedure acNewStudentExecute(Sender: TObject);
    procedure acDeleteStudentUpdate(Sender: TObject);
    procedure acEditStudentUpdate(Sender: TObject);
    procedure lvStudentsEditing(Sender: TObject; Item: TListItem;
      var AllowEdit: Boolean);
    procedure acDeleteStudentExecute(Sender: TObject);
    procedure acEditStudentExecute(Sender: TObject);
    procedure lvStudentsDblClick(Sender: TObject);
  strict private
    FCurrentCourse: ICourse;
    function Confirm(const AMessage: string): Boolean;
    function EditStudent(const AStudent: IStudent): Boolean;
    function GetCurrentStudent: IStudent;
    function ListItemToStudent(AItem: TListItem): IStudent;
    procedure UpdateStudentView(const AStudent: IStudent);
    procedure UpdateView;
    procedure SetCurrentStudent(const Value: IStudent);
    procedure EditCurrentStudent;
  public
    { Public declarations }
    property CurrentCourse: ICourse read FCurrentCourse;
    property CurrentStudent: IStudent read GetCurrentStudent write SetCurrentStudent;
  end;

var
  MainForm: TMainForm;

implementation

uses
  Menus, uStudentEditDialog;

{$R *.dfm}

procedure TMainForm.acDeleteStudentExecute(Sender: TObject);
var
  student: IStudent;
begin
  student := CurrentStudent;
  Assert(student <> nil);
  if (student <> nil) and Confirm('Are you sure?') then
  begin
    CurrentCourse.RemoveStudent(student);
    UpdateView;
  end;
end;

procedure TMainForm.acDeleteStudentUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := CurrentStudent <> nil
end;

procedure TMainForm.acEditStudentExecute(Sender: TObject);
begin
  EditCurrentStudent;
end;

procedure TMainForm.acEditStudentUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := CurrentStudent <> nil
end;

procedure TMainForm.acNewStudentExecute(Sender: TObject);
var
  student: IStudent;
begin
  student := TModel.CreateStudent;
  if EditStudent(student) then
  begin
    CurrentCourse.AddStudent(student);
    UpdateView;
  end;
end;

function TMainForm.Confirm(const AMessage: string): Boolean;
begin
  Result := MessageBox(Handle, PChar(AMessage), PChar(Caption), MB_ICONQUESTION or MB_YESNO) = ID_YES
end;

procedure TMainForm.EditCurrentStudent;
var
  student: IStudent;
begin
  student := CurrentStudent;
  if (student <> nil) then
  begin
    if EditStudent(student) then
      UpdateStudentView(student);
  end;
end;

function TMainForm.EditStudent(const AStudent: IStudent): Boolean;
begin
  Result := TStudentEditDialog.Edit(AStudent)
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FCurrentCourse := TModel.CreateCourse;
end;

function TMainForm.GetCurrentStudent: IStudent;
begin
  Result := ListItemToStudent(lvStudents.Selected);
end;

function TMainForm.ListItemToStudent(AItem: TListItem): IStudent;
begin
  if AItem = nil then
    Result := nil
  else
    Result := CurrentCourse.Students[AItem.Index]
end;

procedure TMainForm.lvStudentsData(Sender: TObject; Item: TListItem);
var
  student: IStudent;
begin
  student := ListItemToStudent(Item);
  if student <> nil then
  begin
    Item.Caption := student.Name;
    Item.SubItems.Add(student.Email);
    Item.SubItems.Add(DateToStr(student.DateOfBirth));
  end;
end;

procedure TMainForm.lvStudentsDblClick(Sender: TObject);
begin
  EditCurrentStudent;
end;

procedure TMainForm.lvStudentsEditing(Sender: TObject; Item: TListItem;
  var AllowEdit: Boolean);
begin
  AllowEdit := False;
end;

procedure TMainForm.UpdateStudentView(const AStudent: IStudent);
var
  idx: Integer;
begin
  idx := CurrentCourse.IndexOfStudent(AStudent);
  if idx > -1 then
  begin
    lvStudents.Items[idx].Update;
  end;
end;

procedure TMainForm.SetCurrentStudent(const Value: IStudent);
var
  idx: Integer;
begin
  idx := CurrentCourse.IndexOfStudent(Value);
  if idx = -1 then
    lvStudents.Selected := nil
  else
    lvStudents.Selected := lvStudents.Items[idx]
end;

procedure TMainForm.UpdateView;
begin
  lvStudents.Items.Count := CurrentCourse.StudentsCount;
end;

end.

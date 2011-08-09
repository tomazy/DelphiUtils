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
unit uStudentEditDialog;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, ComCtrls, uModel;

type
  EValidationError = class(Exception);
  TStudentEditDialog = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    Bevel1: TBevel;
    edName: TEdit;
    edEmail: TEdit;
    dtpDateOfBirth: TDateTimePicker;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    { Private declarations }
    procedure InitView(const AStudent: IStudent);
    procedure UpdateModel(const AStudent: IStudent);
    procedure ValidateView;
  public
    class function Edit(const AStudent: IStudent): Boolean;
  end;


implementation

{$R *.dfm}

{ TStudentEditDialog }

class function TStudentEditDialog.Edit(const AStudent: IStudent): Boolean;
var
  dlg: TStudentEditDialog;
begin
  dlg := TStudentEditDialog.Create(Application);
  try
    dlg.InitView(AStudent);
    Result := dlg.ShowModal = mrOk;
    if Result then
      dlg.UpdateModel(AStudent);
  finally
    dlg.Free;
  end;
end;

procedure TStudentEditDialog.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if ModalResult = mrOk then
    ValidateView;
end;

procedure TStudentEditDialog.InitView(const AStudent: IStudent);
begin
  edName.Text := AStudent.Name;
  edEmail.Text := AStudent.Email;
  dtpDateOfBirth.Date := AStudent.DateOfBirth;
  if Trunc(dtpDateOfBirth.Date) = 0 then
    dtpDateOfBirth.Date := Now;
end;

procedure TStudentEditDialog.UpdateModel(const AStudent: IStudent);
begin
  AStudent.Name := edName.Text;
  AStudent.Email := edEmail.Text;
  AStudent.DateOfBirth := Int(dtpDateOfBirth.Date);
end;

procedure TStudentEditDialog.ValidateView;
begin
  if edName.Text = '' then
  begin
    edName.SetFocus;
    raise EValidationError.Create('Name cannot be empty');
  end;
  if edEmail.Text = '' then
  begin
    edEmail.SetFocus;
    raise EValidationError.Create('Email cannot be empty');
  end;
  if dtpDateOfBirth.Date < EncodeDate(1960, 1, 1) then
  begin
    dtpDateOfBirth.SetFocus;
    raise EValidationError.Create('Invalid date');
  end;
end;

end.

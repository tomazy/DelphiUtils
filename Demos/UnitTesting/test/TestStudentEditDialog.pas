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
unit TestStudentEditDialog;

interface
uses
  Controls,
  uStudentEditDialog,
  FutureWindows;

type
  TStudentEditDialogFutureWindowAction = class(TAbstractWindowAction)
  protected
    procedure ExecuteFormAction(AForm: TStudentEditDialog); virtual; abstract;
    procedure Execute(const AWindow: IWindow); override;
  end;

  TEditStudentFutureWindowAction = class(TStudentEditDialogFutureWindowAction)
  strict private
    FName: string;
    FEmail: string;
    FDate: TDate;
  protected
    procedure ExecuteFormAction(AForm: TStudentEditDialog); override;
  public
    constructor Create(const AName, AEmail: string; ADate: TDate);
  end;

implementation
uses
  Windows,
  Messages,
  SysUtils,
  TestFramework,
  TestCaseBase,
  uModel,
  Forms;


type
  TStudentEditDialogTestCase = class(TTestCaseBase)
  published
    procedure TestEdit;
    procedure TestCloseAction;
  end;

{ TStudentEditDialogTestCase }
procedure TStudentEditDialogTestCase.TestCloseAction;
var
  student: IStudent;
  futureWindow: IFutureWindow;
begin
  student := TModel.CreateStudent();

  futureWindow := TFutureWindows.Expect(TStudentEditDialog.ClassName)
    .ExecPauseAction(0.2, Application.ProcessMessages)
    .ExecCloseWindow()
    ;

  CheckFalse(TStudentEditDialog.Edit(student));
end;

procedure TStudentEditDialogTestCase.TestEdit;
var
  student: IStudent;
  futureWindow: IFutureWindow;
  dateOfBirth: TDate;
const
  NAME  = 'John Doe';
  EMAIL = 'john.doe@example.com';
begin
  dateOfBirth := EncodeDate(1980, 1, 1);

  student := TModel.CreateStudent();

  futureWindow := TFutureWindows.Expect(TStudentEditDialog.ClassName);
  futureWindow.ExecAction(TEditStudentFutureWindowAction.Create(
    NAME, EMAIL, dateOfBirth
  ));

  Check(TStudentEditDialog.Edit(student));

  Check(futureWindow.WindowFound, 'window not found: ' + futureWindow.Description);

  CheckEquals(NAME, student.Name);
  CheckEquals(EMAIL, student.Email);
  CheckEquals(dateOfBirth, student.DateOfBirth, 0.1);
end;

{ TStudentEditDialogTestAction }
procedure TStudentEditDialogFutureWindowAction.Execute(const AWindow: IWindow);
begin
  Assert(AWindow.AsControl is TStudentEditDialog);
  ExecuteFormAction(AWindow.AsControl as TStudentEditDialog);
end;

{ TTestEditAction }

constructor TEditStudentFutureWindowAction.Create(const AName, AEmail: string; ADate: TDate);
begin
  FName := AName;
  FEmail := AEmail;
  FDate := ADate;
end;

procedure TEditStudentFutureWindowAction.ExecuteFormAction(AForm: TStudentEditDialog);
begin
  AForm.edName.Text := FName;
  AForm.edEmail.Text := FEmail;
  AForm.dtpDateOfBirth.Date := FDate;

  // let us see the changes
  TTestCaseBase.ProcessMessages(0);

  AForm.OKBtn.Click;
end;

initialization
  RegisterTest(TStudentEditDialogTestCase.Suite);
end.

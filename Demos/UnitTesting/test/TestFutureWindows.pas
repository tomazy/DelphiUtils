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
unit TestFutureWindows;

interface

implementation
uses
  Windows,
  TestFramework,
  TestCaseBase,
  FutureWindows,
  SysUtils,
  Forms,
  Messages;

type
  TFutureWindowsTestCase = class(TTestCaseBase, IExceptionHandler)
  published
    procedure TestAnonymousProc;
    procedure TestExceptionInAnonymousProc;
    procedure TestTimeOut;
    procedure TestSample;
  end;
{ TFutureWindowsTestCase }

procedure TFutureWindowsTestCase.TestAnonymousProc;
begin
  TFutureWindows.Expect(MESSAGE_BOX_WINDOW_CLASS)
    .ExecProc(
      procedure (const AWindow: IWindow)
      var
        c: Char;
      begin
        ProcessMessages(0.3);
        CheckEquals('', AWindow.Text);
        AWindow.Text := '';

        for c in Self.FTestName do
        begin
          AWindow.Text := AWindow.Text + c;

          // sometimes it gets hidden
          AWindow.BringToFront;

          ProcessMessages(0.1);
        end;
      end
    )
    .ExecCloseWindow();

  MessageBox(0, 'testing future window from anonymous proc', '', MB_OK);
end;

procedure TFutureWindowsTestCase.TestExceptionInAnonymousProc;
begin
  TFutureWindows.Expect(MESSAGE_BOX_WINDOW_CLASS)
    .SetExceptionHandler(Self)
    .ExecProc(
      procedure (const AWindow: IWindow)
      begin
        Fail('This is intended failure!');
      end
    );
  MessageBox(0, '', '', MB_OK);
end;

procedure TFutureWindowsTestCase.TestSample;
begin
  TFutureWindows.Expect(TForm.ClassName)
    .ExecProc(
       procedure (const AWindow: IWindow)
       var
         myForm: TForm;
       begin
         myForm := AWindow.AsControl as TForm;
         myForm.Caption := 'test caption';
         myForm.Close();
       end
    );

  with TForm.Create(Application) do
  try
    Caption := '';

    ShowModal();

    CheckEquals('test caption', Caption);
  finally
    Free;
  end;
end;

procedure TFutureWindowsTestCase.TestTimeOut;
var
  futureMessageBox,
  fakeFutureWindow: IFutureWindow;
begin
  // this should timeout
  fakeFutureWindow := TFutureWindows.Expect('abc', 0.1)
    .ExecCloseWindow();

  futureMessageBox := TFutureWindows.Expect(MESSAGE_BOX_WINDOW_CLASS)
    .ExecPauseAction(0.5, Application.ProcessMessages)
    .ExecCloseWindow();

  MessageBox(0, 'test', 'test', MB_OK);

  Check(futureMessageBox.WindowFound, 'window not found: ' + futureMessageBox.Description);
  CheckFalse(futureMessageBox.TimedOut, 'window timed out: ' + futureMessageBox.Description);

  Check(fakeFutureWindow.TimedOut, 'window not timed out: ' + fakeFutureWindow.Description);
  CheckFalse(fakeFutureWindow.WindowFound, 'window found: ' + fakeFutureWindow.Description);
end;

initialization
  RegisterTest(TFutureWindowsTestCase.Suite);
end.

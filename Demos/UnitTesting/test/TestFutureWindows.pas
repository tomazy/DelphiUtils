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
  FutureWindows, Forms;

type
  TFutureWindowsTestCase = class(TTestCaseBase)
  published
    procedure TestSetWindowText;
    procedure TestTimeOut;
  end;
{ TFutureWindowsTestCase }

type
  TTestSetWindowTextAction = class(TAbstractWindowAction)
  protected
    procedure Execute(const AWindow: IWindow); override;
  end;

procedure TFutureWindowsTestCase.TestSetWindowText;
begin
  TFutureWindows.Expect(MESSAGE_BOX_WINDOW_CLASS)
    .ExecAction(TTestSetWindowTextAction.Create)
    .ExecSendKey(VK_RETURN);
  MessageBox(0, '', '', MB_OK);
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
    .ExecSendKey(VK_RETURN);

  MessageBox(0, nil, nil, MB_OK);

  Check(futureMessageBox.WindowFound, 'window not found: ' + futureMessageBox.Description);
  CheckFalse(futureMessageBox.TimedOut, 'window timed out: ' + futureMessageBox.Description);

  Check(fakeFutureWindow.TimedOut, 'window not timed out: ' + fakeFutureWindow.Description);
  CheckFalse(fakeFutureWindow.WindowFound, 'window found: ' + fakeFutureWindow.Description);
end;

{ TTestSetWindowTextAction }

procedure TTestSetWindowTextAction.Execute(const AWindow: IWindow);
const
  TEST_STRING = 'This is a test';
begin
  Assert(AWindow.Text  = '');

  AWindow.Text := TEST_STRING;
  TTestCaseBase.ProcessMessages(0.3);

  Assert(AWindow.Text  = TEST_STRING);
end;

initialization
  RegisterTest(TFutureWindowsTestCase.Suite);
end.

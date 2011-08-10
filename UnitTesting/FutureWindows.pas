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
 2011-08-08 - [tm] initial thread-based version
 2011-08-09 - [tm] refactored to non-threaded implementation
}
{.$define EnableLogging}
unit FutureWindows;
interface
uses
  Windows,
  Classes,
  Controls;

const
  MESSAGE_BOX_WINDOW_CLASS = '#32770';
  DEFAULT_WAIT_TIME_SECS = 5.0;
type
  IFutureWindowAction = interface
    ['{8383E04C-F238-4505-94C2-B104A9467D0F}']
    procedure Execute(AWindow: HWND);
  end;

  TProcessMessagesProc = procedure of object;

  IFutureWindow = interface
    function ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
    function ExecCloseWindow(): IFutureWindow;
    function ExecPauseAction(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc): IFutureWindow;
    function ExecSendKey(AKey: Word): IFutureWindow;
    function GetDesciption: string;
    function TimedOut: Boolean;
    function WindowFound: Boolean;
    property Description: string read GetDesciption;
  end;

  TAbstractFutureWindowAction = class(TInterfacedObject, IFutureWindowAction)
  protected
    procedure Execute(AWindow: HWND); virtual; abstract;
  end;

  TVCLControlAction = class(TAbstractFutureWindowAction)
  protected
    procedure DoExecute(AControl: TControl); virtual; abstract;
    procedure Execute(AWindow: HWND); override;
  end;

  TFutureWindows = class
    class function Expect(const AWindowClass: string; AWaitSeconds: Double =  DEFAULT_WAIT_TIME_SECS): IFutureWindow;
    class function ExpectChild(AParent: HWND; const AWindowClass: string; AWaitSeconds: Double = DEFAULT_WAIT_TIME_SECS): IFutureWindow;
  end;

implementation
uses
  Messages,
  SysUtils;

type
  TAbstractFutureWindow = class(TInterfacedObject, IFutureWindow)
  strict private
    FActions: IInterfaceList;
    function GetAction(AIndex: Integer): IFutureWindowAction;
    function GetActionsCount: Integer;
  protected
    function StartWaiting(): IFutureWindow; virtual; abstract;
    procedure ExecuteActions(AWindow: HWND);
  protected
    { IFutureWindow }
    function ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
    function ExecCloseWindow(): IFutureWindow;
    function ExecPauseAction(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc): IFutureWindow;
    function ExecSendKey(AKey: Word): IFutureWindow;
    function GetDesciption: string; virtual; abstract;
    function TimedOut: Boolean; virtual; abstract;
    function WindowFound: Boolean; virtual; abstract;
  end;

//==============================================================================
// Non-threaded IFutureWindow implementation

  IFutureWindowEx = interface(IFutureWindow)
    ['{664A768E-7FB4-4397-96E0-0EF5619ABE0B}']
    procedure CheckWindow(AHandle: HWND);
  end;

  TFutureWindowObserver = class
  strict private
    class var FInstance: TFutureWindowObserver;
    class function GetInstance: TFutureWindowObserver; static;
  strict private
    FHandle: THandle;
    FFutureWindows: IInterfaceList;
    FWindowsToUnregister: IInterfaceList;
    FCurrentProcessId: Cardinal;
    FNotifying: Boolean;
    function GetFutureWindow(AIndex: Integer): IFutureWindowEx;
    function GetFutureWindowsCount: Integer;
    procedure StartTimer;
    procedure StopTimer;
  strict private
    constructor Create;
    destructor Destroy; override;
    procedure WndProc(var AMsg: TMessage);
    procedure CheckFutureWindowsForHandle(AHandle: HWND);
    procedure CheckFutureWindows;
  public
    procedure RegisterFutureWindow(const AWindow: IFutureWindowEx);
    procedure UnRegisterFutureWindow(const AWindow: IFutureWindowEx);
  public
    class procedure Finalize;
    class property Instance: TFutureWindowObserver read GetInstance;
  end;

  TFutureWindow = class(TAbstractFutureWindow, IFutureWindowEx)
  strict private
    FParentWnd: HWND;
    FTimedOut: Boolean;
    FWaitSecs: Double;
    FWindowClass: string;
    FWindowFound: Boolean;
    FStartedMillis: Cardinal;
  private
    { IFutureWindowEx }
    procedure CheckWindow(AHandle: HWND);
  protected
    function GetDesciption: string; override;
    function StartWaiting(): IFutureWindow; override;
    function TimedOut: Boolean; override;
    function WindowFound: Boolean; override;
  public
    constructor Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Double);
    destructor Destroy; override;
  end;

//===================== ACTIONS ================================================
  TSendKeyAction = class(TAbstractFutureWindowAction)
  strict private
    FKey: Word;
  protected
    procedure Execute(AWindow: HWND); override;
  public
    constructor Create(AKey: Word);
  end;

  TCloseWindowAction = class(TAbstractFutureWindowAction)
  protected
    procedure Execute(AWindow: HWND); override;
  end;

  TPauseAction = class(TAbstractFutureWindowAction)
  strict private
    FSeconds: Double;
    FProcessMessagesProc: TProcessMessagesProc;
  protected
    procedure Execute(AWindow: HWND); override;
  public
    constructor Create(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc);
  end;


{$ifdef EnableLogging}
  procedure log(const AMsg: string);
  var
    msg: string;
  begin
    msg := Format('[FutureWindows][%.4d] %s', [GetCurrentThreadId, AMsg]);
    OutputDebugString(PChar(msg));
  end;
{$endif}

{ TFutureWindows }
class function TFutureWindows.Expect(const AWindowClass: string;
  AWaitSeconds: Double): IFutureWindow;
begin
  Result := ExpectChild(0, AWindowClass, AWaitSeconds)
end;

class function TFutureWindows.ExpectChild(AParent: HWND;
  const AWindowClass: string; AWaitSeconds: Double): IFutureWindow;
begin
  Result := TFutureWindow.Create(AParent, AWindowClass, AWaitSeconds);
end;

{ TAbstractFutureWindow }
function TAbstractFutureWindow.ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
begin
  if FActions = nil then
    FActions := TInterfaceList.Create;
  FActions.Add(AAction);
  Result := StartWaiting();
end;

function TAbstractFutureWindow.ExecCloseWindow: IFutureWindow;
begin
  Result := ExecAction(TCloseWindowAction.Create)
end;

function TAbstractFutureWindow.ExecPauseAction(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc): IFutureWindow;
begin
  Result := ExecAction(TPauseAction.Create(ASeconds, AProcessMessagesProc));
end;

function TAbstractFutureWindow.ExecSendKey(AKey: Word): IFutureWindow;
begin
  Result := ExecAction(TSendKeyAction.Create(AKey))
end;

procedure TAbstractFutureWindow.ExecuteActions(AWindow: HWND);
var
  i: Integer;
begin
  {$ifdef EnableLogging}log('executing actions for: ' + GetDesciption);{$endif}
  Assert(AWindow <> 0);
  for i := 0 to GetActionsCount - 1 do
    GetAction(i).Execute(AWindow);
end;

function TAbstractFutureWindow.GetAction(AIndex: Integer): IFutureWindowAction;
begin
  Result := FActions[AIndex] as IFutureWindowAction;
end;

function TAbstractFutureWindow.GetActionsCount: Integer;
begin
  if FActions = nil then
    Result := 0
  else
    Result := FActions.Count;
end;

{ TFutureWindowObserver }
procedure TFutureWindowObserver.CheckFutureWindows;
type
  PEnumProcParams = ^TEnumProcParams;
  TEnumProcParams = record
    current_process_id: Cardinal;
    windows_list: TList;
  end;

  function enum_windows_proc(AHandle: HWND; AParam: LPARAM): Boolean; stdcall;
  var
    windowProcessId: Cardinal;
    params: PEnumProcParams;
  begin
    params := PEnumProcParams(AParam);
    GetWindowThreadProcessId(AHandle, windowProcessId);
    if (windowProcessId = params^.current_process_id) and
       IsWindowVisible(AHandle) and
       IsWindowEnabled(AHandle) then
      params^.windows_list.Add(Pointer(AHandle));
    Result := True;
  end;

var
  i: Integer;
  params: TEnumProcParams;
begin
  if FNotifying or (GetFutureWindowsCount = 0) then  Exit;

  FNotifying := True;
  try
    params.current_process_id := FCurrentProcessId;
    params.windows_list := TList.Create;
    try
      EnumWindows(@enum_windows_proc, Integer(@params));
      for i := 0 to params.windows_list.Count - 1 do
        CheckFutureWindowsForHandle(HWND(params.windows_list[i]));
    finally
      params.windows_list.Free
    end;
  finally
    FNotifying := False;
  end;

  if FWindowsToUnregister <> nil then
  begin
    for i := 0 to FWindowsToUnregister.Count - 1 do
      UnRegisterFutureWindow(FWindowsToUnregister[i] as IFutureWindowEx);
    FWindowsToUnregister := nil;
  end;
end;

procedure TFutureWindowObserver.CheckFutureWindowsForHandle(AHandle: HWND);
var
  i: Integer;
  fw: IFutureWindowEx;
begin
  for i := GetFutureWindowsCount - 1 downto 0 do
  begin
    fw := GetFutureWindow(i);
    if (FWindowsToUnregister = nil) or (FWindowsToUnregister.IndexOf(fw) = -1) then
      fw.CheckWindow(AHandle);
  end;
end;

constructor TFutureWindowObserver.Create;
begin
  inherited Create;
  FCurrentProcessId := GetCurrentProcessId;
  FFutureWindows := TInterfaceList.Create;
end;

destructor TFutureWindowObserver.Destroy;
begin
  StopTimer;
  FFutureWindows := nil;
  inherited;
end;

class procedure TFutureWindowObserver.Finalize;
begin
  FInstance.Free;
end;

function TFutureWindowObserver.GetFutureWindow(
  AIndex: Integer): IFutureWindowEx;
begin
  Result := FFutureWindows[AIndex] as IFutureWindowEx;
end;

function TFutureWindowObserver.GetFutureWindowsCount: Integer;
begin
  Result := FFutureWindows.Count
end;

class function TFutureWindowObserver.GetInstance: TFutureWindowObserver;
begin
  if FInstance = nil then
    FInstance := TFutureWindowObserver.Create;
  Result := FInstance;
end;

procedure TFutureWindowObserver.RegisterFutureWindow(const AWindow: IFutureWindowEx);
begin
  Assert(FFutureWindows.IndexOf(AWindow) = -1);
  FFutureWindows.Add(AWindow);
  if FFutureWindows.Count = 1 then
    StartTimer;
end;

procedure TFutureWindowObserver.StartTimer;
begin
  if FHandle = 0 then
  begin
    FHandle := AllocateHWnd(WndProc);
    Windows.SetTimer(FHandle, 1, 50, nil);
  end;
end;

procedure TFutureWindowObserver.StopTimer;
begin
  if FHandle <> 0 then
  begin
    KillTimer(FHandle, 1);
    DeallocateHWnd(FHandle);
    FHandle := 0;
  end;
end;

procedure TFutureWindowObserver.UnRegisterFutureWindow(const AWindow: IFutureWindowEx);
begin
  if FNotifying then
  begin
    if FWindowsToUnregister = nil then
      FWindowsToUnregister := TInterfaceList.Create;
    FWindowsToUnregister.Add(AWindow);
  end
  else
  begin
    FFutureWindows.Remove(AWindow);
    if FFutureWindows.Count = 0 then
      StopTimer;
  end;
end;

procedure TFutureWindowObserver.WndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_TIMER:
      CheckFutureWindows();
  else
    DefWindowProc(FHandle, AMsg.Msg, AMsg.WParam, AMsg.LParam)
  end;
end;

{ TNonThreadedFutureWindow }
procedure TFutureWindow.CheckWindow(AHandle: HWND);
var
  buffer: array[Byte] of Char;
begin
  Assert(not FWindowFound);
  Assert(not FTimedOut);

  if ((FParentWnd = 0) or (GetParent(AHandle) = FParentWnd)) then
  begin
    Windows.GetClassName(AHandle, @buffer, Length(buffer));
    FWindowFound := StrComp(buffer, PChar(FWindowClass)) = 0;
  end;

  if not FWindowFound then
    FTimedOut := GetTickCount > (FStartedMillis + Round(FWaitSecs * 1000));

  if FWindowFound or FTimedOut then
    TFutureWindowObserver.Instance.UnRegisterFutureWindow(Self);

  if FWindowFound then
    ExecuteActions(AHandle)
end;

constructor TFutureWindow.Create(AParent: HWND;
  const AWindowClass: string; AWaitSecs: Double);
begin
  inherited Create;
  FParentWnd := AParent;
  FWindowClass := AWindowClass;
  FWaitSecs := AWaitSecs;
end;

destructor TFutureWindow.Destroy;
begin
  TFutureWindowObserver.Instance.UnRegisterFutureWindow(Self);
  inherited;
end;

function TFutureWindow.GetDesciption: string;
begin
  Result := FWindowClass;
end;

function TFutureWindow.StartWaiting: IFutureWindow;
begin
  if FStartedMillis = 0 then
  begin
    FStartedMillis := GetTickCount;
    TFutureWindowObserver.Instance.RegisterFutureWindow(Self);
  end;
  Result := Self;
end;

function TFutureWindow.TimedOut: Boolean;
begin
  Result := FTimedOut;
end;

function TFutureWindow.WindowFound: Boolean;
begin
  Result := FWindowFound;
end;

{ TVCLControlAction }
procedure TVCLControlAction.Execute(AWindow: HWND);
var
  control: TControl;
begin
  control := FindControl(AWindow);
  Assert(control <> nil);
  DoExecute(control);
end;

{ TSendVKeyAction }
constructor TSendKeyAction.Create(AKey: Word);
begin
  FKey := AKey
end;

procedure TSendKeyAction.Execute(AWindow: HWND);
begin
  Windows.PostMessage(AWindow, WM_KEYDOWN, FKey, 0);
  Windows.PostMessage(AWindow, WM_KEYUP, FKey, 0);
end;

{ TCloseWindowAction }
procedure TCloseWindowAction.Execute(AWindow: HWND);
begin
  Windows.SendMessage(AWindow, WM_CLOSE, 0, 0);
end;

{ TPauseAction }
constructor TPauseAction.Create(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc);
begin
  Assert(Assigned(AProcessMessagesProc));
  FSeconds := ASeconds;
  FProcessMessagesProc := AProcessMessagesProc;
end;

procedure TPauseAction.Execute(AWindow: HWND);
var
  now, finish: Cardinal;
begin
  if FSeconds = 0 then
    FProcessMessagesProc()
  else
  begin
    now := GetTickCount;
    finish := now + Round(FSeconds * 1000);
    while now < finish do
    begin
      FProcessMessagesProc();
      now := GetTickCount;
    end;
  end;
end;

initialization
finalization
  TFutureWindowObserver.Finalize;
end.

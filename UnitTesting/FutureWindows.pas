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

TODO:
  - support for ansi/unicode windows
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
  IWindow = interface
    ['{1756ADCA-62F2-4B2C-BF04-2A7FDC993A5D}']
    function GetAsControl: TControl;
    function GetHandle: HWND;
    function GetParent: IWindow;
    function GetProcessId: Cardinal;
    function GetText: string;
    function GetTextLen: Integer;
    function GetThreadId: Cardinal;
    function GetWindowClass: string;
    function IsEnabled: Boolean;
    function IsUnicode: Boolean;
    function IsVisible: Boolean;
    function IsWindowValid: Boolean;
    function PostMessage(Msg: UINT; wParam: WPARAM; lParam: LPARAM): Boolean;
    function SendMessage(Msg: UINT; wParam: WPARAM; lParam: LPARAM): Integer;
    procedure SetText(const Value: string);
    property AsControl: TControl read GetAsControl;
    property Enabled: Boolean read IsEnabled;
    property Handle: HWND read GetHandle;
    property Parent: IWindow read GetParent;
    property ProcessId: Cardinal read GetProcessId;
    property Text: string read GetText write SetText;
    property TextLen: Integer read GetTextLen;
    property ThreadId: Cardinal read GetThreadId;
    property Unicode: Boolean read IsUnicode;
    property Valid: Boolean read IsWindowValid;
    property Visible: Boolean read IsVisible;
    property WindowClass: string read GetWindowClass;
  end;

  IWindowAction = interface
    ['{8383E04C-F238-4505-94C2-B104A9467D0F}']
    procedure Execute(const AWindow: IWindow);
  end;

  TProcessMessagesProc = procedure of object;

  IFutureWindow = interface
    function ExecAction(const AAction: IWindowAction): IFutureWindow;
    function ExecCloseWindow(): IFutureWindow;
    function ExecPauseAction(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc): IFutureWindow;
    function ExecSendKey(AKey: Word): IFutureWindow;
    function GetDesciption: string;
    function TimedOut: Boolean;
    function WindowFound: Boolean;
    property Description: string read GetDesciption;
  end;

  TFutureWindows = class
    class function Expect(const AWindowClass: string; AWaitSeconds: Double =  DEFAULT_WAIT_TIME_SECS): IFutureWindow;
    class function ExpectChild(AParent: HWND; const AWindowClass: string; AWaitSeconds: Double = DEFAULT_WAIT_TIME_SECS): IFutureWindow;
    class function GetWindow(AHandle: THandle): IWindow;
  end;

  TAbstractWindowAction = class(TInterfacedObject, IWindowAction)
  protected
    procedure Execute(const AWindow: IWindow); virtual; abstract;
  end;

implementation
uses
  Messages,
  SysUtils;

type
  PControl = ^TControl;
  TWindow = class(TInterfacedObject, IWindow)
  strict private
    FWindowClass: string;
    FHandle: HWND;
    FProcessId: Cardinal;
    FThreadId: Cardinal;
    FControl: PControl;
    FParent: IWindow;
    procedure InitThreadIdAndProcessId;
  private
    function GetAsControl: TControl;
    function GetHandle: HWND;
    function GetParent: IWindow;
    function GetProcessId: Cardinal;
    function GetText: string;
    function GetTextLen: Integer;
    function GetThreadId: Cardinal;
    function GetWindowClass: string;
    function IsEnabled: Boolean;
    function IsUnicode: Boolean;
    function IsVisible: Boolean;
    function IsWindowValid: Boolean;
    function PostMessage(Msg: UINT; wParam: WPARAM; lParam: LPARAM): Boolean;
    function SendMessage(Msg: UINT; wParam: WPARAM; lParam: LPARAM): Integer;
    procedure SetText(const Value: string);
  public
    constructor Create(AHandle: HWND);
    destructor Destroy; override;
    property AsControl: TControl read GetAsControl;
    property Enabled: Boolean read IsEnabled;
    property Handle: HWND read GetHandle;
    property Parent: IWindow read GetParent;
    property ProcessId: Cardinal read GetProcessId;
    property Text: string read GetText write SetText;
    property TextLen: Integer read GetTextLen;
    property ThreadId: Cardinal read GetThreadId;
    property Unicode: Boolean read IsUnicode;
    property Valid: Boolean read IsWindowValid;
    property Visible: Boolean read IsVisible;
    property WindowClass: string read GetWindowClass;
  end;

  TAbstractFutureWindow = class(TInterfacedObject, IFutureWindow)
  strict private
    FActions: IInterfaceList;
    function GetAction(AIndex: Integer): IWindowAction;
    function GetActionsCount: Integer;
  protected
    function StartWaiting(): IFutureWindow; virtual; abstract;
    procedure ExecuteActions(const AWindow: IWindow);
  protected
    { IFutureWindow }
    function ExecAction(const AAction: IWindowAction): IFutureWindow;
    function ExecCloseWindow(): IFutureWindow;
    function ExecPauseAction(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc): IFutureWindow;
    function ExecSendKey(AKey: Word): IFutureWindow;
    function GetDesciption: string; virtual; abstract;
    function TimedOut: Boolean; virtual; abstract;
    function WindowFound: Boolean; virtual; abstract;
  end;

//==============================================================================
// Non-threaded IFutureWindow implementation

  TWindowCallback = procedure(const AWindow: IWindow) of object;

  TWindowCallbackList = class
  strict private type
    PWindowCallback = ^TWindowCallback;
  strict private
    FItems: TList;
  public
    constructor Create;
    destructor Destroy; override;
    function Find(ACallback: TWindowCallback; out AIndex: Integer): Boolean;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TWindowCallback;
    function Has(ACallback: TWindowCallback): Boolean;
    procedure Add(ACallback: TWindowCallback);
    procedure Clear;
    procedure Delete(AIndex: Integer);
    procedure Remove(ACallback: TWindowCallback);
  public
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TWindowCallback read GetItem; default;
  end;

  TFutureWindowObserver = class
  strict private
    class var FInstance: TFutureWindowObserver;
    class function GetInstance: TFutureWindowObserver; static;
  strict private
    FCallbacks: TWindowCallbackList;
    FCallbacksToRemove: TWindowCallbackList;
    FCurrentProcessId: Cardinal;
    FHandle: THandle;
    FNotifying: Boolean;
    constructor Create;
    procedure CallCallbacks;
    procedure CallCallbacksForWindow(const AWindow: IWindow);
    procedure StartTimer;
    procedure StopTimer;
    procedure WndProc(var AMsg: TMessage);
  public
    destructor Destroy; override;
    procedure RegisterCallback(ACallback: TWindowCallback);
    procedure UnRegisterCallback(ACallback: TWindowCallback);
  public
    class procedure Finalize;
    class property Instance: TFutureWindowObserver read GetInstance;
  end;

  TFutureWindow = class(TAbstractFutureWindow)
  strict private
    FParentWnd: HWND;
    FTimedOut: Boolean;
    FWaitSecs: Double;
    FWindowClass: string;
    FWindowFound: Boolean;
    FStartedMillis: Cardinal;
  private
    { IFutureWindowEx }
    procedure CheckWindow(const AWindow: IWindow);
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
  TSendKeyAction = class(TAbstractWindowAction)
  strict private
    FKey: Word;
  protected
    procedure Execute(const AWindow: IWindow); override;
  public
    constructor Create(AKey: Word);
  end;

  TCloseWindowAction = class(TAbstractWindowAction)
  protected
    procedure Execute(const AWindow: IWindow); override;
  end;

  TPauseAction = class(TAbstractWindowAction)
  strict private
    FSeconds: Double;
    FProcessMessagesProc: TProcessMessagesProc;
  protected
    procedure Execute(const AWindow: IWindow); override;
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

class function TFutureWindows.GetWindow(AHandle: THandle): IWindow;
begin
  Result := TWindow.Create(AHandle);
end;

{ TAbstractFutureWindow }
function TAbstractFutureWindow.ExecAction(const AAction: IWindowAction): IFutureWindow;
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

procedure TAbstractFutureWindow.ExecuteActions(const AWindow: IWindow);
var
  i: Integer;
begin
  Assert(AWindow <> nil);
  Assert(AWindow.Valid);
  {$ifdef EnableLogging}log('executing actions for: ' + GetDesciption);{$endif}
  for i := 0 to GetActionsCount - 1 do
    GetAction(i).Execute(AWindow);
end;

function TAbstractFutureWindow.GetAction(AIndex: Integer): IWindowAction;
begin
  Result := FActions[AIndex] as IWindowAction;
end;

function TAbstractFutureWindow.GetActionsCount: Integer;
begin
  if FActions = nil then
    Result := 0
  else
    Result := FActions.Count;
end;

{ TFutureWindowObserver }
procedure TFutureWindowObserver.CallCallbacks;
type
  PEnumProcParams = ^TEnumProcParams;
  TEnumProcParams = record
    current_process_id: Cardinal;
    windows_list: IInterfaceList;
  end;

  function enum_windows_proc(AHandle: HWND; AParam: LPARAM): Boolean; stdcall;
  var
    params: PEnumProcParams;
    w: IWindow;
  begin
    w := TFutureWindows.GetWindow(AHandle);
    params := PEnumProcParams(AParam);
    if (w.ProcessId = params^.current_process_id) and
       w.Visible and w.Enabled then
      params^.windows_list.Add(w);
    Result := True;
  end;

var
  i: Integer;
  params: TEnumProcParams;
  w: IWindow;
begin
  if FNotifying or (FCallbacks.Count = 0) then  Exit;

  {$ifdef EnableLogging}log(ToString + '.CallCallbacks');{$endif}

  FNotifying := True;
  try
    params.current_process_id := FCurrentProcessId;
    params.windows_list := TInterfaceList.Create;
    try
      EnumWindows(@enum_windows_proc, Integer(@params));
      for i := 0 to params.windows_list.Count - 1 do
      begin
        w := params.windows_list[i] as IWindow;
        CallCallbacksForWindow(w);
      end;
    finally
      params.windows_list := nil;
    end;
  finally
    FNotifying := False;
  end;

  for i := 0 to FCallbacksToRemove.Count - 1 do
    UnRegisterCallback(FCallbacksToRemove[i]);
  FCallbacksToRemove.Clear;
end;

procedure TFutureWindowObserver.CallCallbacksForWindow(const AWindow: IWindow);
var
  i: Integer;
  cb: TWindowCallback;
begin
  for i := FCallbacks.Count - 1 downto 0 do
  begin
    cb := FCallbacks[i];
    if (not FCallbacksToRemove.Has(cb))  then
      cb(AWindow)
  end;
end;

constructor TFutureWindowObserver.Create;
begin
  inherited Create;
  FCurrentProcessId := GetCurrentProcessId;
  FCallbacks := TWindowCallbackList.Create;
  FCallbacksToRemove := TWindowCallbackList.Create;
end;

destructor TFutureWindowObserver.Destroy;
begin
  StopTimer;
  FCallbacks.Free;;
  FCallbacksToRemove.Free;
  inherited;
end;

class procedure TFutureWindowObserver.Finalize;
begin
  FInstance.Free;
end;

class function TFutureWindowObserver.GetInstance: TFutureWindowObserver;
begin
  if FInstance = nil then
    FInstance := TFutureWindowObserver.Create;
  Result := FInstance;
end;

procedure TFutureWindowObserver.RegisterCallback(ACallback: TWindowCallback);
begin
  {$ifdef EnableLogging}log(ToString + '.RegisterCallback');{$endif}
  Assert(not FCallbacks.Has(ACallback));
  FCallbacks.Add(ACallback);
  if FCallbacks.Count = 1 then
    StartTimer;
end;

procedure TFutureWindowObserver.StartTimer;
begin
  if FHandle = 0 then
  begin
    {$ifdef EnableLogging}log(ToString + '.StartTimer');{$endif}
    FHandle := AllocateHWnd(WndProc);
    Windows.SetTimer(FHandle, 1, 50, nil);
  end;
end;

procedure TFutureWindowObserver.StopTimer;
begin
  if FHandle <> 0 then
  begin
    {$ifdef EnableLogging}log(ToString + '.StopTimer');{$endif}
    KillTimer(FHandle, 1);
    DeallocateHWnd(FHandle);
    FHandle := 0;
  end;
end;

procedure TFutureWindowObserver.UnRegisterCallback(ACallback: TWindowCallback);
begin
  {$ifdef EnableLogging}log(ToString + '.UnRegisterCallback');{$endif}
  if FNotifying then
    FCallbacksToRemove.Add(ACallback)
  else
  begin
    FCallbacks.Remove(ACallback);
    if FCallbacks.Count = 0 then
      StopTimer;
  end;
end;

procedure TFutureWindowObserver.WndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_TIMER:
      CallCallbacks();
  else
    DefWindowProc(FHandle, AMsg.Msg, AMsg.WParam, AMsg.LParam)
  end;
end;

{ TNonThreadedFutureWindow }
procedure TFutureWindow.CheckWindow(const AWindow: IWindow);
begin
  Assert(not FWindowFound);
  Assert(not FTimedOut);

  FWindowFound := ((FParentWnd = 0) or (AWindow.Parent.Handle = FParentWnd)) and
    (AWindow.WindowClass = FWindowClass);

  if not FWindowFound then
    FTimedOut := GetTickCount > (FStartedMillis + Round(FWaitSecs * 1000));

  if FWindowFound or FTimedOut then
    TFutureWindowObserver.Instance.UnRegisterCallback(CheckWindow);

  if FWindowFound then
    ExecuteActions(AWindow)
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
  {$ifdef EnableLogging}log(Self.ToString + '.Destroy');{$endif}
  TFutureWindowObserver.Instance.UnRegisterCallback(CheckWindow);
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
    {$ifdef EnableLogging}log(ToString + '.StartWaiting');{$endif}
    FStartedMillis := GetTickCount;
    TFutureWindowObserver.Instance.RegisterCallback(CheckWindow);
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

{ TSendVKeyAction }
constructor TSendKeyAction.Create(AKey: Word);
begin
  FKey := AKey
end;

procedure TSendKeyAction.Execute(const AWindow: IWindow);
begin
  AWindow.PostMessage(WM_KEYDOWN, FKey, 0);
  AWindow.PostMessage(WM_KEYUP, FKey, 0);
end;

{ TCloseWindowAction }
procedure TCloseWindowAction.Execute(const AWindow: IWindow);
begin
  AWindow.SendMessage(WM_CLOSE, 0, 0);
end;

{ TPauseAction }
constructor TPauseAction.Create(ASeconds: Double; AProcessMessagesProc: TProcessMessagesProc);
begin
  Assert(Assigned(AProcessMessagesProc));
  FSeconds := ASeconds;
  FProcessMessagesProc := AProcessMessagesProc;
end;

procedure TPauseAction.Execute(const AWindow: IWindow);
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

{ TWindow }

constructor TWindow.Create(AHandle: HWND);
begin
  FHandle := AHandle;
end;

destructor TWindow.Destroy;
begin
  Dispose(FControl);
  inherited;
end;

function TWindow.GetAsControl: TControl;
begin
  if FControl = nil then
  begin
    New(FControl);
    FControl^ := FindControl(FHandle)
  end;
  Result := FControl^
end;

function TWindow.GetHandle: HWND;
begin
  Result := FHandle
end;

function TWindow.GetParent: IWindow;
begin
  if FParent = nil then
    FParent := TFutureWindows.GetWindow(Windows.GetParent(FHandle));
  Result := FParent;
end;

function TWindow.GetProcessId: Cardinal;
begin
  InitThreadIdAndProcessId;
  Result := FProcessId;
end;

function TWindow.GetText: string;
var
  len: Integer;
begin
  len := TextLen;
  SetString(Result, PChar(nil), len);
  if len > 0 then
    SendMessage(WM_GETTEXT, len + 1, Integer(PChar(Result)))
end;

function TWindow.GetTextLen: Integer;
begin
  Result := SendMessage(WM_GETTEXTLENGTH, 0, 0)
end;

function TWindow.GetThreadId: Cardinal;
begin
  InitThreadIdAndProcessId;
  Result := FThreadId;
end;

function TWindow.GetWindowClass: string;
var
  buffer: array[Byte] of Char;
begin
  if FWindowClass = '' then
  begin
    Windows.GetClassName(FHandle, @buffer, Length(buffer));
    FWindowClass := buffer;
  end;
  Result := FWindowClass;
end;

procedure TWindow.InitThreadIdAndProcessId;
begin
  if FThreadId = 0 then
    FThreadId := Windows.GetWindowThreadProcessId(FHandle, FProcessId)
end;

function TWindow.IsEnabled: Boolean;
begin
  Result := Windows.IsWindowEnabled(FHandle)
end;

function TWindow.IsUnicode: Boolean;
begin
  Result := Windows.IsWindowUnicode(FHandle)
end;

function TWindow.IsVisible: Boolean;
begin
  Result := Windows.IsWindowVisible(FHandle)
end;

function TWindow.IsWindowValid: Boolean;
begin
  Result := Windows.IsWindow(FHandle);
end;

function TWindow.PostMessage(Msg: UINT; wParam: WPARAM;
  lParam: LPARAM): Boolean;
begin
  if IsUnicode then
    Result := Windows.PostMessageW(FHandle, Msg, wParam, lParam)
  else
    Result := Windows.PostMessageA(FHandle, Msg, wParam, lParam)
end;

function TWindow.SendMessage(Msg: UINT; wParam: WPARAM;
  lParam: LPARAM): Integer;
begin
  if IsUnicode then
    Result := Windows.SendMessageW(FHandle, Msg, wParam, lParam)
  else
    Result := Windows.SendMessageA(FHandle, Msg, wParam, lParam)
end;

procedure TWindow.SetText(const Value: string);
begin
  SendMessage(WM_SETTEXT, 0, Integer(PChar(Value)));
end;

{ TWindowCallbackList }

procedure TWindowCallbackList.Add(ACallback: TWindowCallback);
var
  p: PWindowCallback;
begin
  if FItems = nil then
    FItems := TList.Create;

  New(p);
  p^ := ACallback;
  FItems.Add(p);
end;

procedure TWindowCallbackList.Clear;
var
  cnt: Integer;
begin
  cnt := GetCount;
  while cnt > 0 do
  begin
    Dec(cnt);
    Delete(cnt);
  end;
end;

constructor TWindowCallbackList.Create;
begin
  FItems := TList.Create;
end;

procedure TWindowCallbackList.Delete(AIndex: Integer);
var
  p: PWindowCallback;
begin
  p := FItems[AIndex];
  Dispose(p);
  FItems.Delete(AIndex);
end;

destructor TWindowCallbackList.Destroy;
begin
  Clear;
  FItems.Free;
  inherited;
end;

function TWindowCallbackList.Find(ACallback: TWindowCallback;
  out AIndex: Integer): Boolean;
var
  p: PWindowCallback;
  method: TMethod;
begin
  AIndex := 0;
  method := TMethod(ACallback);
  while AIndex < GetCount  do
  begin
    p := FItems[AIndex];
    if CompareMem(p, @method, SizeOf(TWindowCallback)) then
      Exit(True);
    Inc(AIndex);
  end;
  AIndex := -1;
  Result := False;
end;

function TWindowCallbackList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TWindowCallbackList.GetItem(AIndex: Integer): TWindowCallback;
begin
  Result := PWindowCallback(FItems[AIndex])^
end;

function TWindowCallbackList.Has(ACallback: TWindowCallback): Boolean;
var
  dummy: Integer;
begin
  Result := Find(ACallback, dummy)
end;

procedure TWindowCallbackList.Remove(ACallback: TWindowCallback);
var
  idx: Integer;
begin
  if Find(ACallback, idx) then
    Delete(idx);
end;

initialization
finalization
  TFutureWindowObserver.Finalize;
end.

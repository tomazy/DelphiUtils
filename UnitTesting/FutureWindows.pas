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
unit FutureWindows;
interface
uses
  Windows,
  Classes,
  Controls;

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
    class function Expect(const AWindowClass: string; AWaitSeconds: Cardinal = 5): IFutureWindow;
    class function ExpectChild(AParent: HWND; const AWindowClass: string; AWaitSeconds: Cardinal = 5): IFutureWindow;
  end;

implementation
uses
  Messages,
  SysUtils,
  Contnrs;

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
    function WaitFor: Boolean; virtual; abstract;
    function WindowFound: Boolean; virtual; abstract;
  protected
    property ActionsCount: Integer read GetActionsCount;
    property Actions[AIndex: Integer]: IFutureWindowAction read GetAction;
  end;

  TFutureWindowSharedData = class
  strict private
    FParentWnd: HWND;
    FTimedOut: Boolean;
    FWaitSecs: Cardinal;
    FWindowClass: string;
    FWindowHandle: HWND;
    procedure SetTimedOut(const Value: Boolean);
    procedure SetWindowHandle(const Value: HWND);
  public
    constructor Create(const AWindowClass: string; AParentWnd: HWND; AWaitSecs: Cardinal);
    destructor Destroy; override;
    property ParentWnd: HWND read FParentWnd;
    property TimedOut: Boolean read FTimedOut write SetTimedOut;
    property WaitSecs: Cardinal read FWaitSecs;
    property WindowClass: string read FWindowClass;
    property WindowHandle: HWND read FWindowHandle write SetWindowHandle;
  end;

  TFindWindowThread = class(TThread)
  strict private
    FSharedData: TFutureWindowSharedData;
    FCurrProcessId: Cardinal;
    FNotifyWnd: HWND;
  private
    function EnumCheckWindow(AHandle: HWND): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(ASharedData: TFutureWindowSharedData; ANotifyWnd: HWND);
    destructor Destroy; override;
  end;

  TThreadedFutureWindow = class(TAbstractFutureWindow)
  strict private
    FThread: TFindWindowThread;
    FSharedData: TFutureWindowSharedData;
    FMessageArrived: Boolean;
    procedure CheckStartThread;
    procedure HandleThreadFinished(Sender: TObject);
  protected
    function GetDesciption: string; override;
    function StartWaiting(): IFutureWindow; override;
    function TimedOut: Boolean; override;
    function WaitFor: Boolean; override;
    function WindowFound: Boolean; override;
  public
    constructor Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Cardinal);
    destructor Destroy; override;
  end;

  TWindowFoundEvent = procedure (Sender: TObject; AHandle: HWND) of object;

  TTheadSynchronizer = class
  strict private type
     TThreadReg = class
       handle: THandle;
       on_finished: TNotifyEvent;
     end;
  strict private
    class var FInstance: TTheadSynchronizer;
  strict private
    FHandle: THandle;
    FRegistry: TList;
    function FindByThreadHandle(AHandle: THandle; out AIndex: Integer): Boolean;
    procedure NotifyThreadFinished(AThreadHandle: THandle);
    procedure WndProc(var AMsg: TMessage);
  private
    class procedure Finalize;
  public
    constructor Create();
    destructor Destroy; override;
    class function GetInstance:  TTheadSynchronizer;
    procedure SynchronizeThread(AHandle: THandle; AOnThreadFinished: TNotifyEvent);
    procedure RemoveThread(AThreadHandle: THandle);
    property Handle: THandle read FHandle;
  end;

//==============================================================================
// Non-threaded version
const
  WM_CHECK_FUTURE_WINDOWS = WM_USER + 1;
type
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
    FCurrentProcessId: Cardinal;
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

  TNonThreadedFutureWindow = class(TAbstractFutureWindow, IFutureWindowEx)
  strict private
    FParentWnd: HWND;
    FTimedOut: Boolean;
    FWaitSecs: Cardinal;
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
    function WaitFor: Boolean; override;
    function WindowFound: Boolean; override;
  public
    constructor Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Cardinal);
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

const
  WM_THREAD_FINISHED = WM_USER + 1;

{ TFutureWindows }

procedure log(const AMsg: string);
var
  msg: string;
begin
  msg := Format('[%.4d] %s', [GetCurrentThreadId, AMsg]);
  OutputDebugString(PChar(msg));
end;

class function TFutureWindows.Expect(const AWindowClass: string;
  AWaitSeconds: Cardinal): IFutureWindow;
begin
  Result := ExpectChild(0, AWindowClass, AWaitSeconds)
end;

class function TFutureWindows.ExpectChild(AParent: HWND;
  const AWindowClass: string; AWaitSeconds: Cardinal): IFutureWindow;
begin
//  Result := TThreadedFutureWindow.Create(AParent, AWindowClass, AWaitSeconds);
  Result := TNonThreadedFutureWindow.Create(AParent, AWindowClass, AWaitSeconds);
end;

{ TFutureWindow }

procedure TThreadedFutureWindow.CheckStartThread;
begin
  if FThread = nil then
  begin
    FThread := TFindWindowThread.Create(FSharedData, TTheadSynchronizer.GetInstance.Handle);
    //FThread.OnTerminate := HandleThreadTerminated;
    //FThread.FreeOnTerminate := True;
    TTheadSynchronizer.GetInstance.SynchronizeThread(FThread.Handle, HandleThreadFinished);
    FThread.Start;
  end;
end;

constructor TThreadedFutureWindow.Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Cardinal);
begin
  inherited Create;
  FSharedData := TFutureWindowSharedData.Create(AWindowClass, AParent, AWaitSecs);
end;

destructor TThreadedFutureWindow.Destroy;
begin
  if FThread <> nil then
  begin
    TTheadSynchronizer.GetInstance.RemoveThread(FThread.Handle);
    FThread.Free;
  end;
  FSharedData.Free;
  inherited;
end;

function TThreadedFutureWindow.GetDesciption: string;
begin
  Result := FSharedData.WindowClass;
end;

procedure TThreadedFutureWindow.HandleThreadFinished(Sender: TObject);
begin
  log('thread finished notification');
  if FSharedData.WindowHandle <> 0 then
    ExecuteActions(FSharedData.WindowHandle);
  FMessageArrived := True;
end;

function TThreadedFutureWindow.StartWaiting: IFutureWindow;
begin
  CheckStartThread;
  Result := Self;
end;

function TThreadedFutureWindow.TimedOut: Boolean;
begin
  Result := FSharedData.TimedOut
end;

function TThreadedFutureWindow.WaitFor: Boolean;
var
  res: Cardinal;
  handles: array[0..0] of THandle;
  msg: TMsg;
begin
  log('waitfor: ' + FSharedData.WindowClass);
  CheckStartThread;
  if not FThread.Finished then
  begin
    handles[0] := FThread.Handle;
    while True do
    begin
      res := MsgWaitForMultipleObjects(1, handles, False, INFINITE, QS_ALLEVENTS);
      case res of
         WAIT_OBJECT_0:
           begin
             // the thread terminated. We need to wait for the message to arrive
             // noop;
             log('thread terminated. wnd: ' + IntToStr(FSharedData.WindowHandle));
           end;
         WAIT_OBJECT_0 + 1:
           begin
             // we have a message. peek and dispatch
             if PeekMessage(msg, 0, 0, 0, PM_REMOVE) then
             begin
               log('msg arrived: ' + IntToStr(msg.message));

               TranslateMessage(msg);
               DispatchMessage(msg);
             end;

             // break the loop if we got the notification
             if FMessageArrived then
               Break;
           end;
      else
        RaiseLastOSError;
      end;
    end;
  end;
  Result := not FSharedData.TimedOut;
end;

function TThreadedFutureWindow.WindowFound: Boolean;
begin
  Result := FSharedData.WindowHandle <> 0;
end;

{ TFindWindowThread }
constructor TFindWindowThread.Create(ASharedData: TFutureWindowSharedData; ANotifyWnd: HWND);
begin
  inherited Create(True);
  FSharedData := ASharedData;
  FCurrProcessId := GetCurrentProcessId;
  FNotifyWnd := ANotifyWnd;
end;

destructor TFindWindowThread.Destroy;
begin
  inherited;
end;

function enum_windows_proc(AHandle: HWND; AParam: LPARAM): Boolean; stdcall;
var
  thread: TFindWindowThread;
begin
  thread := TFindWindowThread(AParam);
  Result := thread.EnumCheckWindow(AHandle);
end;

function TFindWindowThread.EnumCheckWindow(AHandle: HWND): Boolean;
var
  buffer: array[Byte] of Char;
  wnd_process_id: Cardinal;
begin
  if Terminated then
    Result := False
  else
  begin
    Result := True;
    Windows.GetWindowThreadProcessId(AHandle, wnd_process_id);
    if (wnd_process_id = FCurrProcessId) and
      IsWindowVisible(AHandle) and
      IsWindowEnabled(AHandle) and
      ((FSharedData.ParentWnd = 0) or (Windows.GetParent(AHandle) = FSharedData.ParentWnd)) then
    begin
      Windows.GetClassName(AHandle, @buffer, Length(buffer));
      if StrComp(buffer, PChar(FSharedData.WindowClass)) = 0 then
      begin
        FSharedData.WindowHandle := AHandle;
        Result := False;
      end
    end;
  end;
end;

procedure TFindWindowThread.Execute;
var
  finish: Cardinal;
  secs: Cardinal;
begin
  secs := FSharedData.WaitSecs;
  if secs = 0 then
    secs := 5{min} * 60{sec}; // 5 minutes should be enough for debugging

  finish := GetTickCount + secs * 1000;
  while not Terminated do
  begin
    //EnumChildWindows(FParent, @enum_windows_proc, Integer(Self));
    EnumWindows(@enum_windows_proc, Integer(Self));

    if (FSharedData.WindowHandle <> 0) then
    begin
      log('window found: ' + FSharedData.WindowClass + ', ' + IntToStr(FSharedData.WindowHandle));
      Break;
    end;

    if GetTickCount > finish then
    begin
      log('timeout: ' + FSharedData.WindowClass);
      FSharedData.TimedOut := True;
      Break;
    end;

    Sleep(100);
  end;
  PostMessage(FNotifyWnd, WM_THREAD_FINISHED, Handle, 0);
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

{ TTheadSynchronizer }

constructor TTheadSynchronizer.Create;
begin
  inherited Create;
  FHandle := AllocateHWnd(WndProc);
  FRegistry := TObjectList.Create;
end;

destructor TTheadSynchronizer.Destroy;
begin
  FRegistry.Free;
  DeallocateHWnd(FHandle);
  inherited;
end;

class procedure TTheadSynchronizer.Finalize;
begin
  FInstance.Free;
end;

function TTheadSynchronizer.FindByThreadHandle(AHandle: THandle;
  out AIndex: Integer): Boolean;
var
  i: Integer;
begin
  for i := 0 to FRegistry.Count - 1 do
  begin
    if TThreadReg(FRegistry[i]).handle = AHandle then
    begin
      Result := True;
      AIndex := i;
      Exit;
    end;
  end;
  Result := False;
  AIndex := -1;
end;

class function TTheadSynchronizer.GetInstance: TTheadSynchronizer;
begin
  if FInstance = nil then
    FInstance := TTheadSynchronizer.Create;
  Result := FInstance;
end;

procedure TTheadSynchronizer.NotifyThreadFinished(AThreadHandle: THandle);
var
  r: TThreadReg;
  idx: Integer;
  event: TNotifyEvent;
begin
  if FindByThreadHandle(AThreadHandle, idx) then
  begin
    r := FRegistry[idx];
    event := r.on_finished;
    FRegistry.Delete(idx);
    event(Self);
  end;
end;

procedure TTheadSynchronizer.RemoveThread(AThreadHandle: THandle);
var
  idx: Integer;
begin
  if FindByThreadHandle(AThreadHandle, idx) then
    FRegistry.Delete(idx);
end;

procedure TTheadSynchronizer.SynchronizeThread(AHandle: THandle; AOnThreadFinished: TNotifyEvent);
var
  r: TThreadReg;
begin
  Assert(AHandle <> 0);
  r := TThreadReg.Create;
  r.handle := AHandle;
  r.on_finished := AOnThreadFinished;
  FRegistry.Add(r);
end;

procedure TTheadSynchronizer.WndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_THREAD_FINISHED:
      NotifyThreadFinished(AMsg.WParam);
  else
    DefWindowProc(Handle, AMsg.Msg, AMsg.WParam, AMsg.LParam)
  end;
end;

{ TFutureWindowSharedData }

constructor TFutureWindowSharedData.Create(const AWindowClass: string; AParentWnd: HWND; AWaitSecs: Cardinal);
begin
  inherited Create;
  FWindowClass := AWindowClass;
  FParentWnd := AParentWnd;
  FWaitSecs := AWaitSecs;
end;

destructor TFutureWindowSharedData.Destroy;
begin
  inherited;
end;

procedure TFutureWindowSharedData.SetTimedOut(const Value: Boolean);
begin
  FTimedOut := Value;
end;

procedure TFutureWindowSharedData.SetWindowHandle(const Value: HWND);
begin
  FWindowHandle := Value;
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
  log('executing actions for: ' + GetDesciption);
  Assert(AWindow <> 0);
  for i := 0 to ActionsCount - 1 do
    Actions[i].Execute(AWindow);
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

  function enum_windows_proc(AHandle: HWND; AParam: LPARAM): Boolean; stdcall;
  var
    list: TList;
  begin
    if IsWindow(AHandle) and
       IsWindowVisible(AHandle) and
       IsWindowEnabled(AHandle) then
    begin
      list := TList(AParam);
      list.Add(Pointer(AHandle));
    end;
    Result := True;
  end;

var
  i: Integer;
  list: TList;
begin
  if GetFutureWindowsCount > 0 then
  begin
    list := TList.Create;
    try
      EnumWindows(@enum_windows_proc, Integer(list));
      for i := 0 to list.Count - 1 do
        CheckFutureWindowsForHandle(HWND(list[i]));
    finally
      list.Free
    end;
  end;
end;

procedure TFutureWindowObserver.CheckFutureWindowsForHandle(AHandle: HWND);
var
  i: Integer;
begin
  for i := GetFutureWindowsCount - 1 downto 0 do
    GetFutureWindow(i).CheckWindow(AHandle);
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

procedure TFutureWindowObserver.UnRegisterFutureWindow(
  const AWindow: IFutureWindowEx);
begin
  Assert(FFutureWindows.IndexOf(AWindow) > -1);
  FFutureWindows.Remove(AWindow);
  if FFutureWindows.Count = 0 then
    StopTimer;
end;

procedure TFutureWindowObserver.WndProc(var AMsg: TMessage);
begin
  case AMsg.Msg of
    WM_TIMER:
      CheckFutureWindows();
    WM_CHECK_FUTURE_WINDOWS:
      CheckFutureWindows();
  else
    DefWindowProc(FHandle, AMsg.Msg, AMsg.WParam, AMsg.LParam)
  end;
end;

{ TNonThreadedFutureWindow }

procedure TNonThreadedFutureWindow.CheckWindow(AHandle: HWND);
var
  buffer: array[Byte] of Char;
begin
  Windows.GetClassName(AHandle, @buffer, Length(buffer));
  FWindowFound :=
     ((FParentWnd = 0) or (GetParent(AHandle) = FParentWnd)) and
     (StrComp(buffer, PChar(FWindowClass)) = 0);
  if FWindowFound then
  begin
    TFutureWindowObserver.Instance.UnRegisterFutureWindow(Self);
    ExecuteActions(AHandle);
  end;
end;

constructor TNonThreadedFutureWindow.Create(AParent: HWND;
  const AWindowClass: string; AWaitSecs: Cardinal);
begin
  inherited Create;
  FParentWnd := AParent;
  FWindowClass := AWindowClass;
  FWaitSecs := AWaitSecs;
end;

function TNonThreadedFutureWindow.GetDesciption: string;
begin
  Result := FWindowClass;
end;

function TNonThreadedFutureWindow.StartWaiting: IFutureWindow;
begin
  if FStartedMillis = 0 then
  begin
    FStartedMillis := GetTickCount;
    TFutureWindowObserver.Instance.RegisterFutureWindow(Self);
  end;
  Result := Self;
end;

function TNonThreadedFutureWindow.TimedOut: Boolean;
begin
  Result := FTimedOut;
end;

function TNonThreadedFutureWindow.WaitFor: Boolean;
begin
  Result := False;
end;

function TNonThreadedFutureWindow.WindowFound: Boolean;
begin
  Result := FWindowFound;
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
  finish: Cardinal;
begin
  if FSeconds = 0 then
    FProcessMessagesProc()
  else
  begin
    finish := GetTickCount + Round(FSeconds * 1000);
    while GetTickCount < finish do
      FProcessMessagesProc();
  end;
end;

initialization
finalization
  TTheadSynchronizer.Finalize;
  TFutureWindowObserver.Finalize;
end.

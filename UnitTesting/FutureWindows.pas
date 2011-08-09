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

  IFutureWindow = interface
    function ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
    function GetDesciption: string;
    function TimedOut: Boolean;
    function WaitFor: Boolean;
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
    class function CreateSendKeyAction(AKey: WORD): IFutureWindowAction;
    class function Expect(const AWindowClass: string; AWaitSeconds: Cardinal = 5): IFutureWindow;
    class function ExpectChild(AParent: HWND; const AWindowClass: string; AWaitSeconds: Cardinal = 5): IFutureWindow;
  end;

implementation
uses
  Messages,
  SysUtils, Contnrs, Forms;

type
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
    property WindowHandle: HWND read FWindowHandle write SetWindowHandle;
    property TimedOut: Boolean read FTimedOut write SetTimedOut;
    property WindowClass: string read FWindowClass;
    property ParentWnd: HWND read FParentWnd;
    property WaitSecs: Cardinal read FWaitSecs;
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

  TFutureWindow = class(TInterfacedObject, IFutureWindow)
  strict private
    FActions: IInterfaceList;
    FThread: TFindWindowThread;
    FSharedData: TFutureWindowSharedData;
    FMessageArrived: Boolean;
    function GetAction(AIndex: Integer): IFutureWindowAction;
    function GetActionsCount: Integer;
    function StartWaiting(): IFutureWindow;
    procedure CheckStartThread;
    procedure ExecuteActions();
    procedure HandleThreadFinished(Sender: TObject);
  private
    { IFutureWindow }
    function ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
    function GetDesciption: string;
    function TimedOut: Boolean;
    function WindowFound: Boolean;
  public
    constructor Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Cardinal);
    destructor Destroy; override;
    function WaitFor: Boolean;
  end;

  TWindowFoundEvent = procedure (Sender: TObject; AHandle: HWND) of object;

  TTheadSynchronizer = class
  strict private type
     TThreadReg = class
       handle: THandle;
       on_finished: TNotifyEvent;
     end;
  strict private
    FHandle: THandle;
    FRegistry: TList;
    function FindByThreadHandle(AHandle: THandle; out AIndex: Integer): Boolean;
    procedure NotifyThreadFinished(AThreadHandle: THandle);
    procedure WndProc(var AMsg: TMessage);
  public
    constructor Create();
    destructor Destroy; override;
    procedure SynchronizeThread(AHandle: THandle; AOnThreadFinished: TNotifyEvent);
    procedure RemoveThread(AThreadHandle: THandle);
    property Handle: THandle read FHandle;
  end;

//===================== ACTIONS ================================================
  TSendVKeyAction = class(TAbstractFutureWindowAction)
  strict private
    FKey: Word;
  protected
    procedure Execute(AWindow: HWND); override;
  public
    constructor Create(AKey: Word);
  end;

const
  WM_THREAD_FINISHED = WM_USER + 1;

var
  __synchronizer: TTheadSynchronizer = nil;
{ TFutureWindows }

procedure log(const AMsg: string);
var
  msg: string;
begin
  msg := Format('[%.4d] %s', [GetCurrentThreadId, AMsg]);
  OutputDebugString(PChar(msg));
end;

class function TFutureWindows.CreateSendKeyAction(
  AKey: WORD): IFutureWindowAction;
begin
  Result := TSendVKeyAction.Create(AKey);
end;

class function TFutureWindows.Expect(const AWindowClass: string;
  AWaitSeconds: Cardinal): IFutureWindow;
begin
  Result := ExpectChild(0, AWindowClass, AWaitSeconds)
end;

class function TFutureWindows.ExpectChild(AParent: HWND;
  const AWindowClass: string; AWaitSeconds: Cardinal): IFutureWindow;
begin
  Result := TFutureWindow.Create(AParent, AWindowClass, AWaitSeconds);
end;

{ TFutureWindow }

procedure TFutureWindow.CheckStartThread;
begin
  if FThread = nil then
  begin
    FThread := TFindWindowThread.Create(FSharedData, __synchronizer.Handle);
    //FThread.OnTerminate := HandleThreadTerminated;
    //FThread.FreeOnTerminate := True;
    __synchronizer.SynchronizeThread(FThread.Handle, HandleThreadFinished);
    FThread.Start;
  end;
end;

constructor TFutureWindow.Create(AParent: HWND; const AWindowClass: string; AWaitSecs: Cardinal);
begin
  inherited Create;
  FSharedData := TFutureWindowSharedData.Create(AWindowClass, AParent, AWaitSecs);
  FActions := TInterfaceList.Create;
end;

destructor TFutureWindow.Destroy;
begin
  if FThread <> nil then
  begin
    __synchronizer.RemoveThread(FThread.Handle);
    FThread.Free;
  end;
  FSharedData.Free;
  inherited;
end;

function TFutureWindow.ExecAction(const AAction: IFutureWindowAction): IFutureWindow;
begin
  FActions.Add(AAction);
  Result := StartWaiting();
end;

function TFutureWindow.GetAction(AIndex: Integer): IFutureWindowAction;
begin
  Result := FActions[AIndex] as IFutureWindowAction
end;

function TFutureWindow.GetActionsCount: Integer;
begin
  Result := FActions.Count;
end;

function TFutureWindow.GetDesciption: string;
begin
  Result := FSharedData.WindowClass;
end;

procedure TFutureWindow.HandleThreadFinished(Sender: TObject);
begin
  log('thread finished notification');
  if FSharedData.WindowHandle <> 0 then
    ExecuteActions();
  FMessageArrived := True;
end;

procedure TFutureWindow.ExecuteActions();
var
  action: IFutureWindowAction;
  i: Integer;
begin
  log('executing actions for: ' + FSharedData.WindowClass);
  Assert(FSharedData.WindowHandle <> 0);
  for i := 0 to GetActionsCount - 1 do
  begin
    action := GetAction(i);
    action.Execute(FSharedData.WindowHandle);
  end;
end;

function TFutureWindow.StartWaiting: IFutureWindow;
begin
  CheckStartThread;
  Result := Self;
end;

function TFutureWindow.TimedOut: Boolean;
begin
  Result := FSharedData.TimedOut
end;

function TFutureWindow.WaitFor: Boolean;
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

function TFutureWindow.WindowFound: Boolean;
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
   // sleep(1000);
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

constructor TSendVKeyAction.Create(AKey: Word);
begin
  FKey := AKey
end;

procedure TSendVKeyAction.Execute(AWindow: HWND);
begin
  PostMessage(AWindow, WM_KEYDOWN, FKey, 0);
  PostMessage(AWindow, WM_KEYUP, FKey, 0);
end;

initialization
  __synchronizer := TTheadSynchronizer.Create;
finalization
  __synchronizer.Free;
end.

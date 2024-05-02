unit DNLog.Thread;

interface

uses
  System.Classes, System.SysUtils, System.Threading, DNLog.Sender, System.Generics.Collections,
  System.SyncObjs;

type TDNSendThread = class(TThread)
  private
    FDNLogSender: IDNLogSender;
    FSendBuffer: TList<TBytes>;
    procedure LockBuffer;
    procedure UnlockBuffer;
  protected
    procedure Execute; override;
    function CanSend: Boolean;
    procedure DoSend;
  public
    constructor Create(DNLogSender: IDNLogSender);
    destructor  Destroy; override;
    procedure Send(Bytes: TBytes);
    function Connected: Boolean;
    function Count: Integer;
end;

implementation

var
  FMutex: TMutex;

{ TDNSendThread }

function TDNSendThread.CanSend: Boolean;
begin
  LockBuffer;
  try
    Result := FSendBuffer.Count > 0;
  finally
    UnlockBuffer;
  end;
end;

function TDNSendThread.Connected: Boolean;
begin
  Result := FDNLogSender.Connected;
end;

function TDNSendThread.Count: Integer;
begin
  LockBuffer;
  try
    Result := FSendBuffer.Count;
  finally
    UnlockBuffer;
  end;
end;

constructor TDNSendThread.Create(DNLogSender: IDNLogSender);
begin
  Assert(Assigned(DNLogSender));

  inherited Create(False);
  FSendBuffer     := TList<TBytes>.Create;
  FDNLogSender    := DNLogSender;
  FreeOnTerminate := True;
end;

destructor TDNSendThread.Destroy;
begin
  FDNLogSender := nil;
  FSendBuffer.Free;
  inherited;
end;

procedure TDNSendThread.DoSend;
var
  Data: TBytes;
begin
  LockBuffer;
  try
    Data := FSendBuffer[0];
    FSendBuffer.Delete(0);
  finally
    UnlockBuffer;
  end;

  if Length(Data) > 0 then
    FDNLogSender.Write(Data);
end;

procedure TDNSendThread.Execute;
begin
  while not Terminated do
  begin
    if CanSend then
      DoSend;
  end;
end;

procedure TDNSendThread.LockBuffer;
begin
  FMutex.Acquire;
end;

procedure TDNSendThread.Send(Bytes: TBytes);
begin
  LockBuffer;
  try
    FSendBuffer.Add(Bytes);
  finally
    UnlockBuffer;
  end;
end;

procedure TDNSendThread.UnlockBuffer;
begin
  FMutex.Release;
end;

initialization
  FMutex := TMutex.Create(False);
finalization
  FMutex.Free;

end.

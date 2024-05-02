unit DNLog.Client;

interface

{$IF Defined(DEBUG)}
  {$DEFINE LOGS}
{$ENDIF}

{x$DEFINE USE_UDP}

uses
  DNLog.Types, DNLog.Sender, System.SysUtils, System.classes, System.IOUtils,
  IdGlobal, DNLog.Thread;

type TDNLogClient = class(TObject)
  strict private
    class var
      FShuttingDown: Boolean;
      FDNLogClient: TDNLogClient;
  strict protected
    class function GetInstance: TDNLogClient; static; inline;
    class function GetActive: Boolean; static; inline;
  private
    FDNSendThread: TDNSendThread;
  protected
    procedure LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);
  public
    constructor Create(DNLogSender: IDNLogSender);
    class destructor Destroy;
    class property Active: Boolean read GetActive;
    class function QueueCount: Integer;
    // Singleton management
    class property Instance: TDNLogClient read GetInstance;
    class function NewInstance: TObject; override;
    procedure FreeInstance; override;
    // Debug
    procedure d(const LogMessage: string); overload; inline;
    procedure d(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    //
    procedure d(const LogMessage: string; const Args: array of const); overload;
    procedure d(const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const); overload;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    // Information
    procedure i(const LogMessage: string); overload; inline;
    procedure i(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    //
    procedure i(const LogMessage: string; const Args: array of const); overload;
    procedure i(const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const); overload;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    // Warning
    procedure w(const LogMessage: string); overload; inline;
    procedure w(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    //
    procedure w(const LogMessage: string; const Args: array of const); overload;
    procedure w(const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const); overload;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    // Error
    procedure e(const LogMessage: string); overload; inline;
    procedure e(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    //
    procedure e(const LogMessage: string; const Args: array of const); overload;
    procedure e(const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const); overload;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    // Exception
    procedure x(const LogMessage: string); overload; inline;
    procedure x(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    //
    procedure x(const LogMessage: string; const Args: array of const); overload;
    procedure x(const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const); overload;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string; const Args: array of const; const LogData: TBytes); overload;
end;


function _Log: TDNLogClient; inline;


implementation

function _Log: TDNLogClient;
begin
{$IFDEF LOGS}
  Result := TDNLogClient.Instance;
{$ELSE}
  Result := nil;
{$ENDIF}
end;

{ TDNLogClient }

constructor TDNLogClient.Create(DNLogSender: IDNLogSender);
begin
  Assert(Assigned(DNLogSender));
  inherited Create;
{$IFDEF LOGS}
  FDNSendThread := TDNSendThread.Create(DNLogSender);
{$ENDIF}
end;

class destructor TDNLogClient.Destroy;
begin
  if _Log <> nil then
    _Log.FDNSendThread.Terminate;
  FShuttingDown := true;
  inherited;
end;

procedure TDNLogClient.e(const LogMessage: string; const Args: array of const);
begin
{$IFDEF LOGS}
  e(Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.e(const LogMessage: string; const Args: array of const;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  e(Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const);
begin
{$IFDEF LOGS}
  e(LogTypeNr, Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const; const LogData: TBytes);
begin
{$IFDEF LOGS}
  e(LogTypeNr, Format(LogMessage, Args), LogData);
{$ENDIF}
end;

class function TDNLogClient.GetActive: Boolean;
begin
{$IFDEF LOGS}
  Result := Assigned(TDNLogClient.Instance) and TDNLogClient.Instance.FDNSendThread.Connected;
{$ELSE}
  Result := False;
{$ENDIF}
end;

class function TDNLogClient.GetInstance: TDNLogClient;
begin
{$IFDEF LOGS}
  if not Assigned(FDNLogClient) then
  begin
  {$IFDEF USE_UDP}
    Result := TDNLogclient.Create(TDNLogSenderUDP.Create(SERVER_ADDRESS, SERVER_BIND_PORT));
  {$ELSE}
    Result := TDNLogclient.Create(TDNLogSenderTCP.Create(SERVER_ADDRESS, SERVER_BIND_PORT));
  {$ENDIF}
  end else
  begin
    Result := FDNLogClient;
  end;
{$ELSE}
  Result := nil;
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const; const LogData: TBytes);
begin
{$IFDEF LOGS}
  i(LogTypeNr, Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const);
begin
{$IFDEF LOGS}
  i(LogTypeNr, Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string; const Args: array of const);
begin
{$IFDEF LOGS}
  i(Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string; const Args: array of const;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  i(Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.FreeInstance;
begin
  if FShuttingDown then
  begin
{$IFDEF LOGS}
    FDNSendThread.Terminate;
{$ENDIF}
    inherited;
  end;
end;

procedure TDNLogClient.e(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt;
  LogMessage: string; LogData: TBytes);
{$IFDEF LOGS}
var
  sendBuffer: TBytes;
  dt: Cardinal;
  logMessageUTF8: TBytes;
{$ENDIF}
begin
{$IFDEF LOGS}
  if not Active then
    Exit;

  dt := TThread.GetTickCount;
  logMessageUTF8 := TEncoding.UTF8.GetBytes(LogMessage);
  var len := 3 {Length} +
             1 {Priority} +
             4 {timestamp} +
             1 {TypeNr} +
             2 {Message Length} +
             2 {Data Length} +
             Length(logMessageUTF8) +
             Length(LogData);

  SetLength(sendBuffer, len);

  sendBuffer[0]  := Byte(len shr 16); {Length}
  sendBuffer[1]  := Byte(len shr 8); {Length}
  sendBuffer[2]  := Byte(len); {Length}
  sendBuffer[3]  := Ord(Priority);   {Priority}
  sendBuffer[4]  := Byte(dt shr 24); {timestamp}
  sendBuffer[5]  := Byte(dt shr 16); {timestamp}
  sendBuffer[6]  := Byte(dt shr 8);  {timestamp}
  sendBuffer[7]  := Byte(dt);        {timestamp}
  sendBuffer[8]  := LogTypeNr;       {TypeNr}
  sendBuffer[9]  := Byte(Length(logMessageUTF8) shr 8); {Message Length}
  sendBuffer[10] := Byte(Length(logMessageUTF8));       {Message Length}

  {Message}
  if Length(logMessageUTF8) > 0 then
    System.Move(logMessageUTF8[0], sendBuffer[11], Length(logMessageUTF8));

  sendBuffer[11 + Length(logMessageUTF8)] := Byte(Length(LogData) shr 8); {Data Length}
  sendBuffer[12 + Length(logMessageUTF8)] := Byte(Length(LogData));       {Data Length}

  {Data}
  if Length(LogData) > 0 then
    System.Move(LogData[0], sendBuffer[13 + Length(logMessageUTF8)], Length(LogData));

  FDNSendThread.Send(sendBuffer);
{$ENDIF}
end;

class function TDNLogClient.NewInstance: TObject;
begin
{$IFDEF LOGS}
  if not assigned(FDNLogClient) then
    FDNLogClient := TDNLogClient(inherited NewInstance);
  Result := FDNLogClient;
{$ELSE}
  Result := nil;
{$ENDIF}
end;

class function TDNLogClient.QueueCount: Integer;
begin
  Result := 0;
{$IFDEF LOGS}
  if Assigned(TDNLogClient.Instance) then
    Result := TDNLogClient.Instance.FDNSendThread.Count;
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const; const LogData: TBytes);
begin
{$IFDEF LOGS}
  d(LogTypeNr, Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const);
begin
{$IFDEF LOGS}
  d(LogTypeNr, Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const Args: array of const;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  d(Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const Args: array of const);
begin
{$IFDEF LOGS}
  d(Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const);
begin
{$IFDEF LOGS}
  w(LogTypeNr, Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const; const LogData: TBytes);
begin
{$IFDEF LOGS}
  w(LogTypeNr, Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const Args: array of const;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  w(Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const Args: array of const);
begin
{$IFDEF LOGS}
  w(Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const; const LogData: TBytes);
begin
{$IFDEF LOGS}
  x(LogTypeNr, Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string;
  const Args: array of const);
begin
{$IFDEF LOGS}
  x(LogTypeNr, Format(LogMessage, Args));
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const Args: array of const;
  const LogData: TBytes);
begin
{$IFDEF LOGS}
  x(Format(LogMessage, Args), LogData);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const Args: array of const);
begin
{$IFDEF LOGS}
  x(Format(LogMessage, Args));
{$ENDIF}
end;

end.

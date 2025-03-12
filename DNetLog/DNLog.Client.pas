unit DNLog.Client;

interface

{x$DEFINE USE_UDP}

uses
  DNLog.Types, DNLog.Sender, System.SysUtils, System.classes, System.IOUtils,
  IdGlobal;

type TDNLogClient = class(TObject)
  strict private
    class var
      FShuttingDown: Boolean;
      FDNLogClient: TDNLogClient;
  strict protected
    class function GetInstance: TDNLogClient; static; inline;
    class function GetActive: Boolean; static; inline;
  private
    FDNLogSender: IDNLogSender;
  protected
    procedure LogRaw(const Priority: TDNLogPriority; const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes);
  public
    constructor Create(DNLogSender: IDNLogSender);
    class destructor Destroy;
    class property Active: Boolean read GetActive;
    // Singleton management
    class property Instance: TDNLogClient read GetInstance;
    class function NewInstance: TObject; override;
    procedure FreeInstance; override;
    // Debug
    procedure d(const LogMessage: string); overload; inline;
    procedure d(const LogMessage: string; const Args: array of const); overload;
    procedure d(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure d(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    // Information
    procedure i(const LogMessage: string); overload; inline;
    procedure i(const LogMessage: string; const Args: array of const); overload;
    procedure i(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure i(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    // Warning
    procedure w(const LogMessage: string); overload; inline;
    procedure w(const LogMessage: string; const Args: array of const); overload;
    procedure w(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure w(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    // Error
    procedure e(const LogMessage: string); overload; inline;
    procedure e(const LogMessage: string; const Args: array of const); overload;
    procedure e(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure e(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
    // Exception
    procedure x(const LogMessage: string); overload; inline;
    procedure x(const LogMessage: string; const Args: array of const); overload;
    procedure x(const LogMessage: string; const LogData: TBytes); overload; inline;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string); overload; inline;
    procedure x(const LogTypeNr: ShortInt; const LogMessage: string; const LogData: TBytes); overload; inline;
end;


function _Log: TDNLogClient; inline;


implementation

function _Log: TDNLogClient;
begin
  Result := TDNLogClient.Instance;
end;

{ TDNLogClient }

constructor TDNLogClient.Create(DNLogSender: IDNLogSender);
begin
  Assert(Assigned(DNLogSender));
  inherited Create;
{$IFDEF USE_DNLOGS}
  FDNLogSender := DNLogSender;
{$ENDIF}
end;

class destructor TDNLogClient.Destroy;
begin
  FShuttingDown := true;
{$IFDEF USE_DNLOGS}
  FreeAndNil(FDNLogClient);
{$ENDIF}
  inherited;
end;

procedure TDNLogClient.e(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, 0, Format(LogMessage, Args), nil);
{$ENDIF}
end;

class function TDNLogClient.GetActive: Boolean;
begin
{$IFDEF USE_DNLOGS}
  Result := Assigned(TDNLogClient.Instance) and TDNLogClient.Instance.FDNLogSender.Connected;
{$ELSE}
  Result := False;
{$ENDIF}
end;

class function TDNLogClient.GetInstance: TDNLogClient;
begin
  if not Assigned(FDNLogClient) then
  begin
{$IFDEF USE_DNLOGS}
  {$IFDEF USE_UDP}
    Result := TDNLogClient.Create(TDNLogSenderUDP.Create(SERVER_ADDRESS, SERVER_BIND_PORT));
  {$ELSE}
    Result := TDNLogClient.Create(TDNLogSenderTCP.Create(SERVER_ADDRESS, SERVER_BIND_PORT));
  {$ENDIF}
{$ELSE}
    Result := TDNLogClient.Create(TDNLogSenderDummy.Create('', 0));;
{$ENDIF}
  end else
  begin
    Result := FDNLogClient;
  end;
end;

procedure TDNLogClient.i(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, 0, Format(LogMessage, Args), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, Format(LogMessage, Args), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.FreeInstance;
begin
  if FShuttingDown then
    inherited;
end;

procedure TDNLogClient.e(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.LogRaw(const Priority: TDNLogPriority; const LogTypeNr: ShortInt;
  const LogMessage: string; const LogData: TBytes);
{$IFDEF USE_DNLOGS}
var
  sendBuffer: TIdBytes;
  dt: Cardinal;
  logMessageUTF8: TBytes;
{$ENDIF}
begin
{$IFDEF USE_DNLOGS}
  if not Active then
    Exit;

  dt := TThread.GetTickCount;
  logMessageUTF8 := TEncoding.UTF8.GetBytes(LogMessage);
  SetLength(sendBuffer,
            1 {Priority} +
            4 {timestamp} +
            1 {TypeNr} +
            2 {Message Length} +
            2 {Data Length} +
            Length(logMessageUTF8) +
            Length(LogData));

  sendBuffer[0] := Ord(Priority);   {Priority}
  sendBuffer[1] := Byte(dt shr 24); {timestamp}
  sendBuffer[2] := Byte(dt shr 16); {timestamp}
  sendBuffer[3] := Byte(dt shr 8);  {timestamp}
  sendBuffer[4] := Byte(dt);        {timestamp}
  sendBuffer[5] := LogTypeNr;       {TypeNr}
  sendBuffer[6] := Byte(Length(logMessageUTF8) shr 8); {Message Length}
  sendBuffer[7] := Byte(Length(logMessageUTF8));       {Message Length}

  {Message}
  if Length(logMessageUTF8) > 0 then
    System.Move(logMessageUTF8[0], sendBuffer[8], Length(logMessageUTF8));

  sendBuffer[8 + Length(logMessageUTF8)] := Byte(Length(LogData) shr 8); {Data Length}
  sendBuffer[9 + Length(logMessageUTF8)] := Byte(Length(LogData));       {Data Length}

  {Data}
  if Length(LogData) > 0 then
    System.Move(LogData[0], sendBuffer[10 + Length(logMessageUTF8)], Length(LogData));

  FDNLogSender.Write(sendBuffer);
{$ENDIF}
end;

class function TDNLogClient.NewInstance: TObject;
begin
  if not assigned(FDNLogClient) then
    FDNLogClient := TDNLogClient(inherited NewInstance);
  Result := FDNLogClient;
end;

procedure TDNLogClient.x(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, Format(LogMessage, Args), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, Format(LogMessage, Args), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, LogData);
{$ENDIF}
end;

end.

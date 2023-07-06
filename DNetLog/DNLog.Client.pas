unit DNLog.Client;

interface

{$IF Defined(DEBUG)}
  {$DEFINE LOGS}
{$ENDIF}

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
    procedure LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);
  public
    constructor Create(DNLogSender: IDNLogSender);
    class destructor Destroy;
    class property Active: Boolean read GetActive;
    // Singleton management
    class property Instance: TDNLogClient read GetInstance;
    class function NewInstance: TObject; override;
    procedure FreeInstance; override;
    // Debug
    procedure d(LogMessage: string); overload; inline;
    procedure d(LogMessage: string; LogData: TBytes); overload; inline;
    procedure d(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Information
    procedure i(LogMessage: string); overload; inline;
    procedure i(LogMessage: string; LogData: TBytes); overload; inline;
    procedure i(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Warning
    procedure w(LogMessage: string); overload; inline;
    procedure w(LogMessage: string; LogData: TBytes); overload; inline;
    procedure w(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Error
    procedure e(LogMessage: string); overload; inline;
    procedure e(LogMessage: string; LogData: TBytes); overload; inline;
    procedure e(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Exception
    procedure x(LogMessage: string); overload; inline;
    procedure x(LogMessage: string; LogData: TBytes); overload; inline;
    procedure x(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure x(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
end;


function _Log: TDNLogClient; inline;


implementation

var
  FLogClient: TDNLogClient;

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
  FDNLogSender := DNLogSender;
{$ENDIF}
end;

class destructor TDNLogClient.Destroy;
begin
  FShuttingDown := true;
{$IFDEF LOGS}
  FreeAndNil(FDNLogClient);
{$ENDIF}
  inherited;
end;

class function TDNLogClient.GetActive: Boolean;
begin
{$IFDEF LOGS}
  Result := Assigned(TDNLogClient.Instance) and TDNLogClient.Instance.FDNLogSender.Connected;
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

procedure TDNLogClient.d(LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(LogTypeNr: ShortInt; LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.d(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.d(LogMessage: string; LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.FreeInstance;
begin
  if FShuttingDown then
    inherited;
end;

procedure TDNLogClient.e(LogMessage: string; LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(LogTypeNr: ShortInt; LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.e(LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(LogTypeNr: ShortInt; LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.i(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.i(LogMessage: string; LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt;
  LogMessage: string; LogData: TBytes);
{$IFDEF LOGS}
var
  sendBuffer: TIdBytes;
  dt: Cardinal;
  logMessageUTF8: TBytes;
{$ENDIF}
begin
{$IFDEF LOGS}
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
{$IFDEF LOGS}
  if not assigned(FDNLogClient) then
    FDNLogClient := TDNLogClient(inherited NewInstance);
  Result := FDNLogClient;
{$ELSE}
  Result := nil;
{$ENDIF}
end;

procedure TDNLogClient.x(LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(LogTypeNr: ShortInt; LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.x(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.x(LogMessage: string; LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prException, 0, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(LogTypeNr: ShortInt; LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(LogMessage: string);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, nil);
{$ENDIF}
end;

procedure TDNLogClient.w(LogMessage: string; LogData: TBytes);
begin
{$IFDEF LOGS}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, LogData);
{$ENDIF}
end;

end.

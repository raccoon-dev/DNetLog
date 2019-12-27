unit DNLog.Client;

interface

uses
  DNLog.Types, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, IdGlobal,
  System.SysUtils, System.classes;

{$DEFINE LOG_CLIENT_AUTO_CREATE}

type TDNLogClient = class(TObject)
  private
    FConnected: Boolean;
    FClient: TIdUDPClient;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  protected
    procedure LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);
  public
    constructor Create(AUseIPv6: Boolean = False);
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    class function Get: TDNLogClient;
    procedure LogDebug(LogMessage: string); overload;
    procedure LogDebug(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure LogDebug(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    procedure LogInfo(LogMessage: string); overload;
    procedure LogInfo(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure LogInfo(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    procedure LogWarning(LogMessage: string); overload;
    procedure LogWarning(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure LogWarning(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    procedure LogError(LogMessage: string); overload;
    procedure LogError(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure LogError(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
end;

// Short version of TDNLogClient.Get
function _Log: TDNLogClient;


implementation


function _Log: TDNLogClient;
begin
  Result := TDNLogClient.Get;
end;

var
  FLogClient: TDNLogClient;

{ TDNLogClient }

constructor TDNLogClient.Create(AUseIPv6: Boolean);
begin
  FClient := TIdUDPClient.Create(nil);
  FClient.Host := SERVER_ADDRESS;
  FClient.Port := SERVER_BIND_PORT;
  try
    FClient.Connect;
    FConnected := True;
  except
    FConnected := False;
  end;
end;

destructor TDNLogClient.Destroy;
begin
  FClient.Disconnect;
  FClient.Free;
  inherited;
end;

class function TDNLogClient.Get: TDNLogClient;
begin
  Result := FLogClient;
end;

function TDNLogClient.GetActive: Boolean;
begin
  Result := FConnected and FClient.Active;
end;

procedure TDNLogClient.LogDebug(LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, Data);
end;

procedure TDNLogClient.LogDebug(LogTypeNr: ShortInt; LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, Data);
end;

procedure TDNLogClient.LogDebug(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, LogData);
end;

procedure TDNLogClient.LogError(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, LogData);
end;

procedure TDNLogClient.LogError(LogTypeNr: ShortInt; LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, Data);
end;

procedure TDNLogClient.LogError(LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prError, 0, LogMessage, Data);
end;

procedure TDNLogClient.LogInfo(LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, Data);
end;

procedure TDNLogClient.LogInfo(LogTypeNr: ShortInt; LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, Data);
end;

procedure TDNLogClient.LogInfo(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, LogData);
end;

procedure TDNLogClient.LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt;
  LogMessage: string; LogData: TBytes);
var
  Buffer: TIdBytes;
  dt: Cardinal;
  arrLogMessage: TBytes;
begin
  if not FConnected then
    Exit;

  dt := TThread.GetTickCount;
  arrLogMessage := TEncoding.UTF8.GetBytes(LogMessage);
  SetLength(Buffer,
            1 {Priority} +
            4 {timestamp} +
            1 {TypeNr} +
            2 {Message Length} +
            2 {Data Length} +
            Length(arrLogMessage) +
            Length(LogData));

  Buffer[0] := Ord(Priority);
  Buffer[1] := Byte(dt shr 24);
  Buffer[2] := Byte(dt shr 16);
  Buffer[3] := Byte(dt shr 8);
  Buffer[4] := Byte(dt);
  Buffer[5] := LogTypeNr;
  Buffer[6] := Byte(Length(arrLogMessage) shr 8);
  Buffer[7] := Byte(Length(arrLogMessage));

  System.Move(arrLogMessage[0], Buffer[8], Length(arrLogMessage));

  Buffer[8 + Length(arrLogMessage)] := Byte(Length(LogData) shr 8);
  Buffer[9 + Length(arrLogMessage)] := Byte(Length(LogData));

  System.Move(LogData[0], Buffer[10 + Length(arrLogMessage)], Length(LogData));

  FClient.SendBuffer(Buffer);
end;

procedure TDNLogClient.LogWarning(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, LogData);
end;

procedure TDNLogClient.LogWarning(LogTypeNr: ShortInt; LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, Data);
end;

procedure TDNLogClient.LogWarning(LogMessage: string);
var
  Data: TBytes;
begin
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, Data);
end;

procedure TDNLogClient.SetActive(const Value: Boolean);
begin
  if Value <> FClient.Active then
    FClient.Active := Value;
end;

{$IF Defined(LOG_CLIENT_AUTO_CREATE)}
initialization
  FLogClient := TDNLogClient.Create;

finalization
  FLogClient.Free;
{$ENDIF}

end.

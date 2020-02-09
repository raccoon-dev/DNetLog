unit DNLog.Client;

interface

uses
  DNLog.Types, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, IdGlobal,
  System.SysUtils, System.classes;


// Tip: You can comment that part and add "LOGS" to your's project conditional defines.
{$UNDEF LOGS}
{$IF Defined(DEBUG)}
  {$DEFINE LOGS}
{$ENDIF}


type TDNLogClient = class(TObject)
  private
{$IF Defined(DEBUG) AND Defined(LOGS)}
    FClient: TIdUDPClient;
{$ENDIF}
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  protected
    procedure LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);
  public
    constructor Create(AUseIPv6: Boolean = False);
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    class function Get: TDNLogClient;
    // Debug
    procedure d(LogMessage: string); overload;
    procedure d(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    // Information
    procedure i(LogMessage: string); overload;
    procedure i(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    // Warning
    procedure w(LogMessage: string); overload;
    procedure w(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
    // Error
    procedure e(LogMessage: string); overload;
    procedure e(LogTypeNr: ShortInt; LogMessage: string); overload;
    procedure e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload;
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
{$IF Defined(DEBUG) AND Defined(LOGS)}
  FClient := TIdUDPClient.Create(nil);
  FClient.Host := SERVER_ADDRESS;
  FClient.Port := SERVER_BIND_PORT;
  FClient.Connect;
{$ENDIF}
end;

destructor TDNLogClient.Destroy;
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  FClient.Disconnect;
  FClient.Free;
{$ENDIF}
  inherited;
end;

class function TDNLogClient.Get: TDNLogClient;
begin
  if not Assigned(FLogClient) then
    FLogClient := Self.Create;
  Result := FLogClient;
end;

function TDNLogClient.GetActive: Boolean;
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  Result := FClient.Active;
{$ELSE}
  Result := False;
{$ENDIF}
end;

procedure TDNLogClient.d(LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prDebug, 0, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.d(LogTypeNr: ShortInt; LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.d(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.e(LogTypeNr: ShortInt; LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prError, LogTypeNr, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.e(LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prError, 0, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.i(LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prInfo, 0, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.i(LogTypeNr: ShortInt; LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.i(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt;
  LogMessage: string; LogData: TBytes);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Buffer: TIdBytes;
  dt: Cardinal;
  arrLogMessage: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
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
{$ENDIF}
end;

procedure TDNLogClient.w(LogTypeNr: ShortInt; LogMessage: string;
  LogData: TBytes);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, LogData);
{$ENDIF}
end;

procedure TDNLogClient.w(LogTypeNr: ShortInt; LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.w(LogMessage: string);
{$IF Defined(DEBUG) AND Defined(LOGS)}
var
  Data: TBytes;
{$ENDIF}
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  LogRaw(TDNLogPriority.prWarning, 0, LogMessage, Data);
{$ENDIF}
end;

procedure TDNLogClient.SetActive(const Value: Boolean);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  if Value <> FClient.Active then
    FClient.Active := Value;
{$ENDIF}
end;

initialization
// nil

finalization
  if Assigned(FLogClient) then
    FreeAndNil(FLogClient);

end.

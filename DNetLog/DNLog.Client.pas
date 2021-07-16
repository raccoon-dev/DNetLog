unit DNLog.Client;

interface

// Tip: You can comment that part and add "LOGS" to your's project conditional defines.
{$UNDEF LOGS}
{$IF Defined(DEBUG)}
  {$DEFINE LOGS}
{$ENDIF}

// Comment this define to use UDP by default
{$DEFINE BY_DEFAULT_USE_TCP}

// Comment this to disable auto create log client on first use, but
// _Log and TDNLogClient.Get functions  will return nil in that case.
{$DEFINE AUTO_CREATE_CLIENT}

{$IF Defined(DEBUG) AND Defined(LOGS)}
uses
  DNLog.Types, IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, IdGlobal,
  System.SysUtils, System.classes, IdTCPClient;
{$ENDIF}


type TDNLogClient = class(TObject)
  private
{$IF Defined(DEBUG) AND Defined(LOGS)}
    FUdpClient: TIdUDPClient;
    FTcpClient: TIdTCPClient;
    FUseTcp: Boolean;
{$ENDIF}
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  protected
    procedure LogRaw(Priority: TDNLogPriority; LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);
  public
    constructor Create(AUseTCP: Boolean; AUseIPv6: Boolean);
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    class function Get: TDNLogClient;
    class procedure CreateClient(AUseTCP: Boolean = {$IF Defined(BY_DEFAULT_USE_TCP)}True{$ELSE}False{$ENDIF}; AUseIPv6: Boolean = False);
    // Debug
    procedure d(LogMessage: string); overload; inline;
    procedure d(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Information
    procedure i(LogMessage: string); overload; inline;
    procedure i(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Warning
    procedure w(LogMessage: string); overload; inline;
    procedure w(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
    // Error
    procedure e(LogMessage: string); overload; inline;
    procedure e(LogTypeNr: ShortInt; LogMessage: string); overload; inline;
    procedure e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes); overload; inline;
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

constructor TDNLogClient.Create(AUseTCP: Boolean; AUseIPv6: Boolean);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  if AUseTcp then
  begin
    FUseTcp := True;
    FTcpclient := TIdTCPClient.Create(nil);
    FTcpClient.Host := SERVER_ADDRESS;
    FTcpClient.Port := SERVER_BIND_PORT;
    FTcpClient.Connect;
  end else
  begin
    FUseTcp := False;
    FUdpClient := TIdUDPClient.Create(nil);
    FUdpClient.Host := SERVER_ADDRESS;
    FUdpClient.Port := SERVER_BIND_PORT;
    FUdpClient.Connect;
  end;
{$ENDIF}
end;

class procedure TDNLogClient.CreateClient(AUseTCP: Boolean = {$IF Defined(BY_DEFAULT_USE_TCP)}True{$ELSE}False{$ENDIF}; AUseIPv6: Boolean = False);
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  FLogClient := Self.Create(AUseTCP, AUseIPv6);
{$ENDIF}
end;

destructor TDNLogClient.Destroy;
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  if FUseTcp then
  begin
    FTcpClient.Disconnect;
    FTcpClient.Free;
  end else
  begin
    FUdpClient.Disconnect;
    FUdpClient.Free;
  end;
{$ENDIF}
  inherited;
end;

class function TDNLogClient.Get: TDNLogClient;
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  {$IF Defined(AUTO_CREATE_CLIENT)}
  if not Assigned(FLogClient) then
    CreateClient;
  {$ENDIF}
  Result := FLogClient;
{$ELSE}
  Result := nil;
{$ENDIF}
end;

function TDNLogClient.GetActive: Boolean;
begin
{$IF Defined(DEBUG) AND Defined(LOGS)}
  if FUseTcp then
    Result := FTcpClient.Connected
  else
    Result := FUdpClient.Active;
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
  if FUseTcp then
    FTcpClient.Socket.Write(TIdBytes(Buffer), Length(Buffer))
  else
    FUdpClient.SendBuffer(Buffer);
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
  if FUseTcp then
  begin
    if Value <> FTcpClient.Connected then
      if Value then
        FTcpClient.Connect else
      begin
        FTcpClient.DisconnectNotifyPeer;
        FTcpClient.Disconnect;
      end;
  end else
  begin
    if Value <> FUdpClient.Active then
      FUdpClient.Active := Value;
  end;
{$ENDIF}
end;

initialization
  FLogClient := nil;

finalization
  if Assigned(FLogClient) then
    FreeAndNil(FLogClient);

end.

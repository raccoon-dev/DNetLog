unit DNLog.Server;

interface

uses
  DNLog.Types, IdGlobal, IdBaseComponent, IdComponent, IdUDPBase, IdUDPServer,
  IdSocketHandle, System.SysUtils;

{$DEFINE LOG_SERVER_AUTO_ON}

type TOnLogReceived = procedure(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage) of object;

type TDNLogServer = class(TObject)
  private
    FServer: TIdUDPServer;
    FOnLogReceived: TOnLogReceived;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
  protected
    procedure _OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    function DecodeLogMsg(ABytes: TIdBytes): TDNLogMessage;
  public
    constructor Create;
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    property OnLogReceived: TOnLogReceived read FOnLogReceived write FOnLogReceived;
end;

implementation

{ TDNLogServer }

constructor TDNLogServer.Create;
var
  sockh: TIdSocketHandle;
begin
  FServer := TIdUDPServer.Create(nil);
  FServer.DefaultPort := SERVER_BIND_PORT;
  FServer.IPVersion := TIdIPVersion.Id_IPv4;
  FServer.BufferSize := SERVER_BUFFER_SIZE * 1024 * 1024; // [MB]
  sockh := FServer.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_4, SERVER_BIND_PORT, TIdIPVersion.Id_IPv4);
  sockh := FServer.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_6, SERVER_BIND_PORT, TIdIPVersion.Id_IPv6);
  FServer.OnUDPRead := _OnUDPRead;
{$IF Defined(LOG_SERVER_AUTO_ON)}
  Active := True;
{$ENDIF}
end;

function TDNLogServer.DecodeLogMsg(ABytes: TIdBytes): TDNLogMessage;
var
  Msg: TBytes;
  Len, RawLen: Word;
begin
  if Length(ABytes) < 10 then
    raise Exception.Create('Wrong message size');

  Result.LogPriority := TDNLogPriority(ABytes[0]);
  Result.LogTimestamp := (ABytes[1] shl 24) +
                         (ABytes[2] shl 16) +
                         (ABytes[3] shl 8) +
                          ABytes[4];
  Result.LogTypeNr := ABytes[5];

  Len := (ABytes[6] shl 8) + ABytes[7];
  if Len > Length(ABytes) - 10 then
    raise Exception.Create('Wrong message data size');
  if Len > 0 then
  begin
    SetLength(Msg, Len);
    System.Move(ABytes[8], Msg[0], Len);
    Result.LogMessage := TEncoding.UTF8.GetString(Msg);
  end else
    Result.LogMessage := string.Empty; // Not necessary
  SetLength(Msg, 0);

  RawLen := (ABytes[8 + Len] shl 8) + ABytes[9 + Len];
  if RawLen > Length(ABytes) - 10 then
    raise Exception.Create('Wrong message data size');
  if RawLen > 0 then
  begin
    SetLength(Result.LogData, RawLen);
    System.Move(ABytes[10 + Len], Result.LogData[0], RawLen);
  end else
    SetLength(Result.LogData, 0); // Not necessary
end;

destructor TDNLogServer.Destroy;
begin
  FOnLogReceived := nil;
  FServer.Active := False;
  FServer.Free;
  inherited;
end;

function TDNLogServer.GetActive: Boolean;
begin
  Result := FServer.Active;
end;

procedure TDNLogServer.SetActive(const Value: Boolean);
begin
  if Value <> FServer.Active then
    FServer.Active := Value;
end;

procedure TDNLogServer._OnUDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  if Assigned(FOnLogReceived) then
    try
      FOnLogReceived(Self, ABinding.PeerIP, DecodeLogMsg(AData));
    except
      // null
    end;
end;

end.

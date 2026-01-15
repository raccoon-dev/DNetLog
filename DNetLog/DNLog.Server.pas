unit DNLog.Server;

interface

uses
  DNLog.Types, IdGlobal, IdBaseComponent, IdComponent, IdUDPBase, IdUDPServer,
  IdSocketHandle, System.SysUtils, IdTCPServer, System.Classes, IdContext;

{$DEFINE LOG_SERVER_AUTO_ON}

type TOnLogReceived = procedure(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage) of object;

type TDNLogServer = class(TObject)
  private
    FBuffer: TIdBytes;
    FServerUDP: TIdUDPServer;
    FServerTCP: TIdTCPServer;
    FOnLogReceived: TOnLogReceived;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
    procedure TrimLeft(var AData: TBytes; ALength: Integer);
    procedure LogInternalError(const Text: string);
  protected
    procedure _OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure _OnExecute(AContext: TIdContext);
    function DecodeLogMsg(var ABytes: TIdBytes; var AMessage: TDNLogMessage): Boolean;
  public
    constructor Create;
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    property OnLogReceived: TOnLogReceived read FOnLogReceived write FOnLogReceived;
end;

implementation

const
  DEFAULT_UDP_BUFFER_LENGTH = 20*1024*1024; // 20 [MB]
  MIN_PACKET_LENGTH = 1 {Priority} +
                      4 {Timestamp} +
                      1 {TypeNr} +
                      2 {Message Length} +
                      2 {Data Length};

{ TDNLogServer }

constructor TDNLogServer.Create;
var
  sockh: TIdSocketHandle;
begin
  inherited;

  FServerUDP := TIdUDPServer.Create(nil);
  FServerUDP.DefaultPort := SERVER_BIND_PORT;
  FServerUDP.IPVersion := TIdIPVersion.Id_IPv4;
  FServerUDP.BufferSize := DEFAULT_UDP_BUFFER_LENGTH;
  sockh := FServerUDP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_4, SERVER_BIND_PORT, TIdIPVersion.Id_IPv4);
  sockh := FServerUDP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_6, SERVER_BIND_PORT, TIdIPVersion.Id_IPv6);
  FServerUDP.OnUDPRead := _OnUDPRead;

  FServerTCP := TIdTCPServer.Create(nil);
  FServerTCP.DefaultPort := SERVER_BIND_PORT;
  sockh := FServerTCP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_4, SERVER_BIND_PORT, TIdIPVersion.Id_IPv4);
  sockh := FServerTCP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_6, SERVER_BIND_PORT, TIdIPVersion.Id_IPv6);
  FServerTCP.OnExecute := _OnExecute;

{$IF Defined(LOG_SERVER_AUTO_ON)}
  Active := True;
{$ENDIF}
end;

function TDNLogServer.DecodeLogMsg(var ABytes: TIdBytes; var AMessage: TDNLogMessage): boolean;
var
  TextLen, DataLen: Word;
begin
  Result := False;
  if Length(ABytes) < MIN_PACKET_LENGTH then
    Exit;

  AMessage.LogPriority := TDNLogPriority(ABytes[0]);
  AMessage.LogTimestamp := (ABytes[1] shl 24) +
                         (ABytes[2] shl 16) +
                         (ABytes[3] shl 8) +
                          ABytes[4];
  AMessage.LogTypeNr := ABytes[5];

  // Message text length
  TextLen := (ABytes[6] shl 8) + ABytes[7];

  // Validate we have enough bytes for: header(8) + TextLen + DataLenField(2)
  if Length(ABytes) < 8 + TextLen + 2 then
    Exit;

  // Message text
  if TextLen > 0 then
  begin
    try
      AMessage.LogMessage := TEncoding.UTF8.GetString(TBytes(ABytes), 8, TextLen);
    except
      AMessage.LogMessage := '[Invalid UTF-8 data]';
    end;
  end
  else
    AMessage.LogMessage := string.Empty;

  // Message data length
  DataLen := (ABytes[8 + TextLen] shl 8) + ABytes[9 + TextLen];

  // Validate we have enough bytes for full packet
  if Length(ABytes) < MIN_PACKET_LENGTH + TextLen + DataLen then
    Exit;

  // Message data
  if DataLen > 0 then
  begin
    SetLength(AMessage.LogData, DataLen);
    System.Move(ABytes[MIN_PACKET_LENGTH + TextLen], AMessage.LogData[0], DataLen);
  end
  else
    SetLength(AMessage.LogData, 0);

  TrimLeft(TBytes(ABytes), MIN_PACKET_LENGTH + TextLen + DataLen);
  Result := True;
end;

destructor TDNLogServer.Destroy;
begin
  FOnLogReceived := nil;
  FServerUDP.Active := False;
  FServerUDP.Free;
  FServerTCP.Active := False;
  FServerTCP.Free;
  inherited;
end;

function TDNLogServer.GetActive: Boolean;
begin
  Result := FServerUDP.Active and FServerTCP.Active;
end;

procedure TDNLogServer.LogInternalError(const Text: string);
var
  DNLogMessage: TDNLogMessage;
begin
  if Assigned(FOnLogReceived) then
  begin
    DNLogMessage.LogPriority := TDNLogPriority.prException;
    DNLogMessage.LogTimestamp := 0;
    DNLogMessage.LogTypeNr := 0;
    DNLogMessage.LogMessage := Text;
    SetLength(DNLogMessage.LogData, 0);
    FOnLogReceived(Self, '0.0.0.0', DNLogMessage);
  end;
end;

procedure TDNLogServer.SetActive(const Value: Boolean);
begin
  if Value <> FServerUDP.Active then
    FServerUDP.Active := Value;
  if Value <> FServerTcp.Active then
    FServerTCP.Active := Value;
end;

procedure TDNLogServer.TrimLeft(var AData: TBytes; ALength: Integer);
var
  NewData: TBytes;
begin
  if ALength <= 0 then
    Exit;
  if ALength >= Length(AData) then
  begin
    SetLength(AData, 0);
    Exit;
  end;
  SetLength(NewData, Length(AData) - ALength);
  System.Move(AData[ALength], NewData[0], Length(NewData));
  AData := NewData;
end;

procedure TDNLogServer._OnExecute(AContext: TIdContext);
var
  DNLogMessage: TDNLogMessage;
begin
  try
    AContext.Connection.Socket.ReadTimeout := 100;
    AContext.Connection.Socket.ReadBytes(FBuffer, -1, True);
    while DecodeLogMsg(FBuffer, DNLogMessage) do
      if Assigned(FOnLogReceived) then
        FOnLogReceived(Self, AContext.Binding.PeerIP, DNLogMessage);
  except
    on e: Exception do
    begin
      LogInternalError(e.ToString);
    end;
  end;
end;

procedure TDNLogServer._OnUDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  if Assigned(FOnLogReceived) then
    TThread.Queue(nil, procedure
    var
      LogMsg: TDNLogMessage;
      b: TIdBytes;
    begin
      try
        SetLength(b, Length(AData));
        System.Move(AData[0], b[0], Length(b));
        if DecodeLogMsg(b, LogMsg) and Assigned(FOnLogReceived) then
          FOnLogReceived(Self, ABinding.PeerIP, LogMsg);
        SetLength(b, 0);
      except
        on e: Exception do
        begin
          LogInternalError(e.ToString);
        end;
      end;
    end);
end;

end.

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
  Msg: TBytes;
  TextLen, DataLen: Word;
begin
  Result := False;
  if Length(ABytes) < 10 then
    Exit;

  AMessage.LogPriority := TDNLogPriority(ABytes[0]);
  AMessage.LogTimestamp := (ABytes[1] shl 24) +
                         (ABytes[2] shl 16) +
                         (ABytes[3] shl 8) +
                          ABytes[4];
  AMessage.LogTypeNr := ABytes[5];

  // Message text
  TextLen := (ABytes[6] shl 8) + ABytes[7];
  if TextLen > Length(ABytes) - 10 then
    Exit;
  if TextLen > 0 then
  begin
    SetLength(Msg, TextLen);
    System.Move(ABytes[8], Msg[0], TextLen);
    AMessage.LogMessage := TEncoding.UTF8.GetString(Msg);
  end else
    AMessage.LogMessage := string.Empty; // Not really necessary
  SetLength(Msg, 0);

  // Message data
  DataLen := (ABytes[8 + TextLen] shl 8) + ABytes[9 + TextLen];
  if DataLen > Length(ABytes) - 10 then
    Exit;
  if DataLen > 0 then
  begin
    SetLength(AMessage.LogData, DataLen);
    System.Move(ABytes[10 + TextLen], AMessage.LogData[0], DataLen);
  end else
    SetLength(AMessage.LogData, 0); // Not really necessary
  TrimLeft(TBytes(ABytes),
            1 {Priority} +
            4 {timestamp} +
            1 {TypeNr} +
            2 {Message Length} +
            2 {Data Length} +
            TextLen +
            DataLen);
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

procedure TDNLogServer.SetActive(const Value: Boolean);
begin
  if Value <> FServerUDP.Active then
    FServerUDP.Active := Value;
  if Value <> FServerTcp.Active then
    FServerTCP.Active := Value;
end;

procedure TDNLogServer.TrimLeft(var AData: TBytes; ALength: Integer);
var
  b: TBytes;
begin
  SetLength(b, Length(AData) - ALength);
  System.Move(AData[ALength], b[0], Length(b));
  SetLength(AData, Length(b));
  System.Move(b[0], AData[0], Length(b));
  SetLength(b, 0);
end;

procedure TDNLogServer._OnExecute(AContext: TIdContext);
var
  DNLogMessage: TDNLogMessage;
begin
  try
    AContext.Connection.Socket.ReadTimeout := 100;
    AContext.Connection.Socket.ReadBytes(FBuffer, -1, True);
    if Length(FBuffer) > 0 then
      while DecodeLogMsg(FBuffer, DNLogMessage) do
        if Assigned(FOnLogReceived) then
          TThread.Synchronize(TThread.Current, procedure
          begin
            FOnLogReceived(Self, AContext.Binding.PeerIP, DNLogMessage);
          end);
  except
    // null
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
        // null
      end;
    end);
end;

end.

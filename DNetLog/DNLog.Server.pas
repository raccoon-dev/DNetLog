unit DNLog.Server;

interface

uses
  DNLog.Types, IdGlobal, IdBaseComponent, IdComponent, IdUDPBase, IdUDPServer,
  IdSocketHandle, System.SysUtils, System.SyncObjs, IdTCPServer, System.Classes,
  IdContext;

{$DEFINE LOG_SERVER_AUTO_ON}

// OnLogReceived is always called from a background (Indy) thread, never from
// the main thread. Calls are serialized (never concurrent) and LogId values
// arrive in strictly increasing order. The handler should be fast and must not
// wait for the main thread (e.g. TThread.Synchronize) - queue the data instead.
type TOnLogReceived = procedure(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage) of object;

type TDNLogServer = class(TObject)
  private
    FServerUDP: TIdUDPServer;
    FServerTCP: TIdTCPServer;
    FOnLogReceived: TOnLogReceived;
    FDispatchLock: TCriticalSection;
    FLastLogId: Int64;
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
    function GetOnLogReceived: TOnLogReceived;
    procedure SetOnLogReceived(const Value: TOnLogReceived);
    procedure TrimLeft(var AData: TIdBytes; ALength: Integer);
    procedure LogInternalError(const Text: string);
    procedure DispatchLog(const ClientIP: string; var LogMessage: TDNLogMessage);
  protected
    procedure _OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure _OnExecute(AContext: TIdContext);
    function DecodeLogMsg(const ABytes: TIdBytes; var AOffset: Integer; var AMessage: TDNLogMessage): Boolean;
  public
    constructor Create;
    destructor  Destroy; override;
    property Active: Boolean read GetActive write SetActive;
    property OnLogReceived: TOnLogReceived read GetOnLogReceived write SetOnLogReceived;
end;

implementation

uses
  IdCustomTCPServer, IdException, IdExceptionCore, IdStackConsts;

const
  // Application buffer for ONE datagram (Indy: SetLength before every RecvFrom).
  // Must be >= the largest datagram (UDP max payload is 65507 bytes), otherwise
  // bigger datagrams are lost (WSAEMSGSIZE). Making it bigger does not help with
  // bursts - that is what UDP_SOCKET_RECEIVE_BUFFER_SIZE is for.
  UDP_RECEIVE_BUFFER_SIZE = 65536;
  // Kernel socket receive buffer (SO_RCVBUF) - holds datagrams waiting to be
  // read, so bursts of logs sent very quickly are not dropped by the OS.
  UDP_SOCKET_RECEIVE_BUFFER_SIZE = 16*1024*1024; // 16 [MB]
  TCP_READ_TIMEOUT_MS = 100;

type
  // Per-connection state. Every TCP client gets its own receive buffer, so data
  // from concurrent connections is never mixed.
  TDNLogServerContext = class(TIdServerContext)
  public
    Buffer: TIdBytes;
  end;

{ TDNLogServer }

constructor TDNLogServer.Create;
var
  sockh: TIdSocketHandle;
begin
  inherited;

  FDispatchLock := TCriticalSection.Create;
  FLastLogId := 0;

  FServerUDP := TIdUDPServer.Create(nil);
  FServerUDP.DefaultPort := SERVER_BIND_PORT;
  FServerUDP.IPVersion := TIdIPVersion.Id_IPv4;
  FServerUDP.BufferSize := UDP_RECEIVE_BUFFER_SIZE;
  // Decode in the listener thread instead of synchronizing with the main
  // thread - a busy UI must not stall receiving (which causes dropped datagrams).
  FServerUDP.ThreadedEvent := True;
  sockh := FServerUDP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_4, SERVER_BIND_PORT, TIdIPVersion.Id_IPv4);
  sockh := FServerUDP.Bindings.Add;
  sockh.SetBinding(SERVER_BIND_ADDRESS_6, SERVER_BIND_PORT, TIdIPVersion.Id_IPv6);
  FServerUDP.OnUDPRead := _OnUDPRead;

  FServerTCP := TIdTCPServer.Create(nil);
  FServerTCP.ContextClass := TDNLogServerContext;
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

function TDNLogServer.DecodeLogMsg(const ABytes: TIdBytes; var AOffset: Integer;
  var AMessage: TDNLogMessage): Boolean;
var
  Available, P: Integer;
  TextLen, DataLen: Integer;
  PriorityByte: Byte;
begin
  Result := False;
  P := AOffset;
  Available := Length(ABytes) - P;

  // Make sure the whole packet is available before decoding anything
  if Available < PACKET_HEADER_SIZE then
    Exit;

  TextLen := (Integer(ABytes[P + PACKET_OFFSET_MSGLEN]) shl 8) or ABytes[P + PACKET_OFFSET_MSGLEN + 1];
  if Available < PACKET_OFFSET_MESSAGE + TextLen + PACKET_SIZE_DATALEN then
    Exit;

  DataLen := (Integer(ABytes[P + PACKET_OFFSET_MESSAGE + TextLen]) shl 8) or ABytes[P + PACKET_OFFSET_MESSAGE + TextLen + 1];
  if Available < PACKET_HEADER_SIZE + TextLen + DataLen then
    Exit;

  // Priority (unknown values are clamped, so the enum is always valid)
  PriorityByte := ABytes[P + PACKET_OFFSET_PRIORITY];
  if Integer(PriorityByte) > Ord(High(TDNLogPriority)) then
    PriorityByte := Byte(Ord(High(TDNLogPriority)));
  AMessage.LogPriority := TDNLogPriority(PriorityByte);

  // Timestamp - unsigned 32-bit big-endian (client tick count, wraps after ~49.7 days)
  AMessage.LogTimestamp := (Cardinal(ABytes[P + PACKET_OFFSET_TIMESTAMP])     shl 24) or
                           (Cardinal(ABytes[P + PACKET_OFFSET_TIMESTAMP + 1]) shl 16) or
                           (Cardinal(ABytes[P + PACKET_OFFSET_TIMESTAMP + 2]) shl 8) or
                            Cardinal(ABytes[P + PACKET_OFFSET_TIMESTAMP + 3]);

  // Type number - signed byte
  AMessage.LogTypeNr := ShortInt(ABytes[P + PACKET_OFFSET_TYPENR]);

  // Message text
  if TextLen > 0 then
  begin
    try
      AMessage.LogMessage := TEncoding.UTF8.GetString(TBytes(ABytes), P + PACKET_OFFSET_MESSAGE, TextLen);
    except
      AMessage.LogMessage := '[Invalid UTF-8 data]';
    end;
  end
  else
    AMessage.LogMessage := string.Empty;

  // Message data
  SetLength(AMessage.LogData, DataLen);
  if DataLen > 0 then
    System.Move(ABytes[P + PACKET_HEADER_SIZE + TextLen], AMessage.LogData[0], DataLen);

  // Server-side fields are assigned in DispatchLog
  AMessage.LogId := 0;
  AMessage.LogReceivedAt := 0;

  Inc(AOffset, PACKET_HEADER_SIZE + TextLen + DataLen);
  Result := True;
end;

destructor TDNLogServer.Destroy;
begin
  // Detach the handler first, so no event is fired during shutdown
  OnLogReceived := nil;
  FServerUDP.Active := False;
  FServerUDP.Free;
  FServerTCP.Active := False;
  FServerTCP.Free;
  FDispatchLock.Free;
  inherited;
end;

procedure TDNLogServer.DispatchLog(const ClientIP: string; var LogMessage: TDNLogMessage);
begin
  // Serialized, so LogId is unique and the handler sees ids in increasing order
  FDispatchLock.Enter;
  try
    Inc(FLastLogId);
    LogMessage.LogId := FLastLogId;
    LogMessage.LogReceivedAt := Now;
    if Assigned(FOnLogReceived) then
      FOnLogReceived(Self, ClientIP, LogMessage);
  finally
    FDispatchLock.Leave;
  end;
end;

function TDNLogServer.GetActive: Boolean;
begin
  Result := FServerUDP.Active and FServerTCP.Active;
end;

function TDNLogServer.GetOnLogReceived: TOnLogReceived;
begin
  FDispatchLock.Enter;
  try
    Result := FOnLogReceived;
  finally
    FDispatchLock.Leave;
  end;
end;

procedure TDNLogServer.LogInternalError(const Text: string);
var
  DNLogMessage: TDNLogMessage;
begin
  DNLogMessage.LogPriority := TDNLogPriority.prException;
  DNLogMessage.LogTimestamp := 0;
  DNLogMessage.LogTypeNr := 0;
  DNLogMessage.LogMessage := Text;
  SetLength(DNLogMessage.LogData, 0);
  DispatchLog('0.0.0.0', DNLogMessage);
end;

procedure TDNLogServer.SetActive(const Value: Boolean);
var
  i: Integer;
begin
  if Value <> FServerUDP.Active then
  begin
    FServerUDP.Active := Value;
    // Sockets exist only after activation - enlarge the kernel receive buffer
    if Value then
      for i := 0 to FServerUDP.Bindings.Count - 1 do
        try
          FServerUDP.Bindings[i].SetSockOpt(Id_SOL_SOCKET, Id_SO_RCVBUF, UDP_SOCKET_RECEIVE_BUFFER_SIZE);
        except
          // Not fatal - the OS default buffer is used
        end;
  end;
  if Value <> FServerTcp.Active then
    FServerTCP.Active := Value;
end;

procedure TDNLogServer.SetOnLogReceived(const Value: TOnLogReceived);
begin
  FDispatchLock.Enter;
  try
    FOnLogReceived := Value;
  finally
    FDispatchLock.Leave;
  end;
end;

procedure TDNLogServer.TrimLeft(var AData: TIdBytes; ALength: Integer);
var
  NewData: TIdBytes;
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
  Ctx: TDNLogServerContext;
  DNLogMessage: TDNLogMessage;
  Offset: Integer;
begin
  Ctx := AContext as TDNLogServerContext;
  try
    AContext.Connection.Socket.ReadTimeout := TCP_READ_TIMEOUT_MS;
    AContext.Connection.Socket.ReadBytes(Ctx.Buffer, -1, True);

    // Decode all complete packets, then drop them from the buffer in one go
    // (an incomplete packet stays in the buffer until the rest arrives).
    Offset := 0;
    while DecodeLogMsg(Ctx.Buffer, Offset, DNLogMessage) do
      DispatchLog(AContext.Binding.PeerIP, DNLogMessage);
    TrimLeft(Ctx.Buffer, Offset);
  except
    // Client disconnected - let Indy close the connection silently
    on EIdConnClosedGracefully do
      raise;
    on EIdNotConnected do
      raise;
    // Any other error: report it and drop the connection - the stream position
    // can't be trusted anymore, so continuing would only produce garbage.
    on e: Exception do
    begin
      LogInternalError(Format('[%s] %s', [AContext.Binding.PeerIP, e.ToString]));
      raise;
    end;
  end;
end;

procedure TDNLogServer._OnUDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
var
  DNLogMessage: TDNLogMessage;
  Offset: Integer;
begin
  // Runs in the UDP listener thread (ThreadedEvent = True)
  try
    Offset := 0;
    while DecodeLogMsg(AData, Offset, DNLogMessage) do
      DispatchLog(ABinding.PeerIP, DNLogMessage);
  except
    on e: Exception do
      LogInternalError(e.ToString);
  end;
end;

end.

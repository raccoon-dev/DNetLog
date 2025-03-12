unit DNLog.Sender;

interface

uses
  IdBaseComponent, IdComponent, IdUDPBase, IdUDPClient, IdGlobal, IdTCPClient;

type IDNLogSender = interface(IInterface)
  ['{AD968E05-E6A8-4A5C-A4DE-5C14199D4101}']
  procedure Write(IdBytes: TIdBytes);
  function GetConnected: Boolean;
  procedure SetConnected(Value: Boolean);
  property Connected: Boolean read GetConnected write SetConnected;
end;

type TDNLogSenderTCP = class(TInterfacedObject, IDNLogSender)
  private
    FIdTCPClient: TIdTCPClient;
  protected
    function GetConnected: Boolean;
    procedure SetConnected(Value: Boolean);
  public
    constructor Create(Address: String; Port: Word);
    destructor Destroy; override;
    procedure Write(IdBytes: TIdBytes);
    property Connected: Boolean read GetConnected write SetConnected;
end;

type TDNLogSenderUDP = class(TInterfacedObject, IDNLogSender)
  private
    FIdUDPClient: TIdUDPClient;
  protected
    function GetConnected: Boolean;
    procedure SetConnected(Value: Boolean);
  public
    constructor Create(Address: String; Port: Word);
    destructor Destroy; override;
    procedure Write(IdBytes: TIdBytes);
    property Connected: Boolean read GetConnected write SetConnected;
end;

type TDNLogSenderDummy = class(TInterfacedObject, IDNLogSender)
  protected
    function GetConnected: Boolean;
    procedure SetConnected(Value: Boolean);
  public
    constructor Create(Address: String; Port: Word);
    destructor Destroy; override;
    procedure Write(IdBytes: TIdBytes);
    property Connected: Boolean read GetConnected write SetConnected;
end;

implementation

{ TDNLogSenderTCP }

constructor TDNLogSenderTCP.Create(Address: String; Port: Word);
begin
  FIdTCPClient      := TIdTCPClient.Create;
  FIdTCPClient.Host := Address;
  FIdTCPClient.Port := Port;
  Connected         := True;
end;

destructor TDNLogSenderTCP.Destroy;
begin
  Connected := False;
  FIdTCPClient.Free;
  inherited;
end;

function TDNLogSenderTCP.GetConnected: Boolean;
begin
  Result := FIdTCPClient.Connected;
end;

procedure TDNLogSenderTCP.SetConnected(Value: Boolean);
begin
  if Value then
  begin
    try
      FIdTCPClient.Connect;
    except
    end;
  end else
  begin
    FIdTCPClient.Disconnect(True);
  end;
end;

procedure TDNLogSenderTCP.Write(IdBytes: TIdBytes);
begin
  FIdTCPClient.Socket.Write(IdBytes, Length(IdBytes));
end;

{ TDNLogSenderUDP }

constructor TDNLogSenderUDP.Create(Address: String; Port: Word);
begin
  FIdUDPClient            := TIdUDPClient.Create;
  FIdUDPClient.Host       := Address;
  FIdUDPClient.Port       := Port;
  Connected               := True;
end;

destructor TDNLogSenderUDP.Destroy;
begin
  Connected := False;
  FIdUDPClient.Free;
  inherited;
end;

function TDNLogSenderUDP.GetConnected: Boolean;
begin
  Result := FIdUDPClient.Connected;
end;

procedure TDNLogSenderUDP.SetConnected(Value: Boolean);
begin
  if Value then
  begin
    try
      FIdUDPClient.Connect;
    except
    end;
  end else
  begin
    FIdUDPClient.Disconnect;
  end;
end;

procedure TDNLogSenderUDP.Write(IdBytes: TIdBytes);
begin
  FIdUDPClient.SendBuffer(IdBytes);
end;

{ TDNLogSenderDummy }

constructor TDNLogSenderDummy.Create(Address: String; Port: Word);
begin
  // nil
end;

destructor TDNLogSenderDummy.Destroy;
begin
  // nil
  inherited;
end;

function TDNLogSenderDummy.GetConnected: Boolean;
begin
  Result := False;
end;

procedure TDNLogSenderDummy.SetConnected(Value: Boolean);
begin
  // nil
end;

procedure TDNLogSenderDummy.Write(IdBytes: TIdBytes);
begin
  // nil
end;

end.

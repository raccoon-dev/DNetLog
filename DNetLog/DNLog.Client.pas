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
    function TruncateUTF8(const UTF8Text: TBytes; const MaxDataLength: Integer): TBytes;
    function ShrinkMessage(const LogMessage: string): TBytes;
    function ShrinkRawData(const LogData: TBytes): TBytes;
    procedure LogRaw(const Priority: TDNLogPriority; const LogTypeNr: ShortInt; const LogMessage: TBytes; const LogData: TBytes);
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

const
  MAX_DATA_LENGTH = 65535;

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
  LogRaw(TDNLogPriority.prError, 0, ShrinkMessage(Format(LogMessage, Args)), nil);
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
  LogRaw(TDNLogPriority.prInfo, 0, ShrinkMessage(Format(LogMessage, Args)), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, LogTypeNr, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, ShrinkMessage(Format(LogMessage, Args)), nil);
{$ENDIF}
end;

procedure TDNLogClient.d(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prDebug, 0, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
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
  LogRaw(TDNLogPriority.prError, 0, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.e(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, LogTypeNr, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.e(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prError, 0, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, 0, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.i(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, LogTypeNr, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.i(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prInfo, 0, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.LogRaw(const Priority: TDNLogPriority; const LogTypeNr: ShortInt;
  const LogMessage: TBytes; const LogData: TBytes);
{$IFDEF USE_DNLOGS}
var
  sendBuffer: TIdBytes;
  dt: Cardinal;
{$ENDIF}
begin
{$IFDEF USE_DNLOGS}
  if not Active then
    Exit;

  dt := TThread.GetTickCount;
  SetLength(sendBuffer,
            1 {Priority} +
            4 {timestamp} +
            1 {TypeNr} +
            2 {Message Length} +
            2 {Data Length} +
            Length(LogMessage) +
            Length(LogData));

  sendBuffer[0] := Ord(Priority);   {Priority}
  sendBuffer[1] := Byte(dt shr 24); {timestamp}
  sendBuffer[2] := Byte(dt shr 16); {timestamp}
  sendBuffer[3] := Byte(dt shr 8);  {timestamp}
  sendBuffer[4] := Byte(dt);        {timestamp}
  sendBuffer[5] := LogTypeNr;       {TypeNr}
  sendBuffer[6] := Byte(Length(LogMessage) shr 8); {Message Length}
  sendBuffer[7] := Byte(Length(LogMessage));       {Message Length}

  {Message}
  if Length(LogMessage) > 0 then
    System.Move(LogMessage[0], sendBuffer[8], Length(LogMessage));

  sendBuffer[8 + Length(LogMessage)] := Byte(Length(LogData) shr 8); {Data Length}
  sendBuffer[9 + Length(LogMessage)] := Byte(Length(LogData));       {Data Length}

  {Data}
  if Length(LogData) > 0 then
    System.Move(LogData[0], sendBuffer[10 + Length(LogMessage)], Length(LogData));

  FDNLogSender.Write(sendBuffer);
{$ENDIF}
end;

class function TDNLogClient.NewInstance: TObject;
begin
  if not assigned(FDNLogClient) then
    FDNLogClient := TDNLogClient(inherited NewInstance);
  Result := FDNLogClient;
end;

function TDNLogClient.ShrinkMessage(const LogMessage: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(LogMessage);
  Result := TruncateUTF8(Result, MAX_DATA_LENGTH);
end;

function TDNLogClient.ShrinkRawData(const LogData: TBytes): TBytes;
begin
  Result := LogData;
  if Length(Result) > MAX_DATA_LENGTH then
    SetLength(Result, MAX_DATA_LENGTH);
end;

function TDNLogClient.TruncateUTF8(const UTF8Text: TBytes;
  const MaxDataLength: Integer): TBytes;
begin
  Result := UTF8Text;

  var Counter := 0;
  if Length(Result) > MaxDataLength then
    for var i := MaxDataLength downto 0 do
    begin
      if (Result[i] and $C0) <> $80 then
      begin
        SetLength(Result, i);
        Break;
      end;
      Inc(Counter);
      if Counter > 3 then
      begin
        Result := TEncoding.UTF8.GetBytes('[DNLOG ERROR: Incorrect UTF-8 message]');
        Break;
      end;
    end;
end;

procedure TDNLogClient.x(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, LogTypeNr, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string;
  const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, ShrinkMessage(Format(LogMessage, Args)), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const Args: array of const);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, ShrinkMessage(Format(LogMessage, Args)), nil);
{$ENDIF}
end;

procedure TDNLogClient.x(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prException, 0, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

procedure TDNLogClient.w(const LogTypeNr: ShortInt; const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, LogTypeNr, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, ShrinkMessage(LogMessage), nil);
{$ENDIF}
end;

procedure TDNLogClient.w(const LogMessage: string; const LogData: TBytes);
begin
{$IFDEF USE_DNLOGS}
  LogRaw(TDNLogPriority.prWarning, 0, ShrinkMessage(LogMessage), ShrinkRawData(LogData));
{$ENDIF}
end;

end.

unit uLogStats;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  DNLog.Types;

type
  TLogStats = class
  private
    FTotal: Int64;
    FDebug: Int64;
    FInfo: Int64;
    FWarning: Int64;
    FError: Int64;
    FException: Int64;
    FClients: TDictionary<string, Int64>;
    FTypes: TDictionary<Integer, Int64>;
    FThroughputCount: Int64;
    FThroughputLastCount: Int64;
    FThroughputLastTick: Cardinal;
    FLastThroughput: Double;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddLog(Priority: TDNLogPriority; const Client: string; TypeNr: Integer);
    procedure UpdateThroughput;
    function GetThroughput: Double;
    function GetClientsText: string;
    function GetTypesText: string;
    property Total: Int64 read FTotal;
    property Debug: Int64 read FDebug;
    property Info: Int64 read FInfo;
    property Warning: Int64 read FWarning;
    property Error: Int64 read FError;
    property Exception: Int64 read FException;
    property Clients: TDictionary<string, Int64> read FClients;
    property Types: TDictionary<Integer, Int64> read FTypes;
  end;

implementation

{ TLogStats }

constructor TLogStats.Create;
begin
  inherited Create;
  FClients := TDictionary<string, Int64>.Create;
  FTypes := TDictionary<Integer, Int64>.Create;
  Clear;
end;

destructor TLogStats.Destroy;
begin
  FClients.Free;
  FTypes.Free;
  inherited;
end;

procedure TLogStats.Clear;
begin
  FTotal := 0;
  FDebug := 0;
  FInfo := 0;
  FWarning := 0;
  FError := 0;
  FException := 0;
  FClients.Clear;
  FTypes.Clear;
  FThroughputCount := 0;
  FThroughputLastCount := 0;
  FThroughputLastTick := TThread.GetTickCount;
  FLastThroughput := 0;
end;

procedure TLogStats.AddLog(Priority: TDNLogPriority; const Client: string; TypeNr: Integer);
var
  Count: Int64;
begin
  Inc(FTotal);
  Inc(FThroughputCount);

  case Priority of
    TDNLogPriority.prDebug:     Inc(FDebug);
    TDNLogPriority.prInfo:      Inc(FInfo);
    TDNLogPriority.prWarning:   Inc(FWarning);
    TDNLogPriority.prError:     Inc(FError);
    TDNLogPriority.prException: Inc(FException);
  end;

  if FClients.TryGetValue(Client, Count) then
    FClients[Client] := Count + 1
  else
    FClients.Add(Client, 1);

  if FTypes.TryGetValue(TypeNr, Count) then
    FTypes[TypeNr] := Count + 1
  else
    FTypes.Add(TypeNr, 1);
end;

procedure TLogStats.UpdateThroughput;
var
  CountDelta: Int64;
  CurrentTick: Cardinal;
  TimeDelta: Cardinal;
begin
  CurrentTick := TThread.GetTickCount;
  TimeDelta := CurrentTick - FThroughputLastTick;

  // Only update if at least 250ms have passed
  if TimeDelta >= 250 then
  begin
    CountDelta := FThroughputCount - FThroughputLastCount;

    if TimeDelta > 0 then
      FLastThroughput := (CountDelta * 1000) / TimeDelta
    else
      FLastThroughput := 0;

    FThroughputLastCount := FThroughputCount;
    FThroughputLastTick := CurrentTick;
  end;
end;

function TLogStats.GetThroughput: Double;
begin
  Result := FLastThroughput;
end;

function TLogStats.GetClientsText: string;
var
  Pair: TPair<string, Int64>;
  sb: TStringBuilder;
  First: Boolean;
begin
  sb := TStringBuilder.Create;
  try
    First := True;
    for Pair in FClients do
    begin
      if not First then
        sb.Append(', ');
      sb.AppendFormat('%s: %d', [Pair.Key, Pair.Value]);
      First := False;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

function TLogStats.GetTypesText: string;
var
  Keys: TArray<Integer>;
  Key: Integer;
  sb: TStringBuilder;
  First: Boolean;
begin
  sb := TStringBuilder.Create;
  try
    Keys := FTypes.Keys.ToArray;
    TArray.Sort<Integer>(Keys);

    First := True;
    for Key in Keys do
    begin
      if not First then
        sb.AppendLine;
      sb.AppendFormat('%d: %d', [Key, FTypes[Key]]);
      First := False;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

end.

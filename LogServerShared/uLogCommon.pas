unit uLogCommon;

// Code shared by LogServerWin (VCL) and LogServerFMX.
// Must not depend on VCL or FMX.

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  DNLog.Types;

type
  PLogNode = ^TLogNode;
  TLogNode = record
    LogId: Int64;
    LogReceivedAt: TDateTime;
    LogReceivedAtString: string;
    LogPriority: TDNLogPriority;
    LogTimestamp: Cardinal;
    LogTimestampString: string;
    LogClient: string;
    LogTypeNr: Integer;
    LogTypeNrString: string;
    LogMessage: string;
    LogMessageLC: string;
    LogDataRaw: TBytes;
    LogData: string;
    Selected: Boolean;  // used by the FMX list only
  end;

  TCLientLogMessage = record
    ClientIP: string;
    DNLogMessage: TDNLogMessage;
    constructor Create(const ClientIP: string; const DNLogMessage: TDNLogMessage);
  end;

  TOnProcessLogs = procedure(const Logs: TArray<TCLientLogMessage>) of object;

  // Collects logs received by the server (background threads) and passes them
  // in batches to the main thread (OnProcessLogs is called via Synchronize).
  TLogUpdateThread = class(TThread)
  private
    FLogs: TThreadList<TCLientLogMessage>;
    FOnProcessLogs: TOnProcessLogs;
    FDroppedCount: Int64;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
    procedure Execute; override;
    procedure AddLog(const ClientIP: string; const LogMessage: TDNLogMessage);
    property Terminated; // used by the forms to stop processing a batch on shutdown
    property Logs: TThreadList<TCLientLogMessage> read FLogs;
    property DroppedCount: Int64 read FDroppedCount;
    property OnProcessLogs: TOnProcessLogs read FOnProcessLogs write FOnProcessLogs;
  end;

  // Filter values prepared once, then used for every node.
  TLogFilter = record
  private
    FShowAll: Boolean;
    FPriority: string;      // lower case, '' or 'all' = any
    FClient: string;
    FHasTypeNr: Boolean;
    FTypeNrs: set of Byte;  // LogTypeNr - Low(ShortInt) (LogTypeNr is ShortInt)
    FText: string;
    FTextLC: string;
    procedure AddTypeNr(Value: Integer);
    procedure ParseTypeNrs(const TypeNrFilter: string);
  public
    // Priority - 'All', 'Debug', ... (case-insensitive)
    // Client   - prefix of the client IP (case-sensitive)
    // TypeNr   - values and ranges separated by space, comma, semicolon or dot,
    //            e.g. "1-3, 5; 10", "-5", "-10--5"
    // Text     - case-insensitive in Message, case-sensitive in Data
    constructor Create(const Priority, Client, TypeNr, Text: string);
    function Matches(const Node: TLogNode): Boolean;
    property ShowAll: Boolean read FShowAll;
  end;

procedure FillLogNode(var Node: TLogNode; const LogMessage: TCLientLogMessage);
function  BytesToHexStr(const Bytes: TBytes): string;
function  PriorityToStr(Priority: TDNLogPriority): string;
procedure AppendLogHeader(StringBuilder: TStringBuilder; const Separator: string);
procedure AppendLogRow(StringBuilder: TStringBuilder; const Node: TLogNode; const Separator: string);
function  FormatDeltaTime(MinTimestamp, MaxTimestamp: Cardinal): string;

implementation

uses
  uConstants;

{ helpers }

function BytesToHexStr(const Bytes: TBytes): string;
var
  sb: TStringBuilder;
  i: Integer;
begin
  sb := TStringBuilder.Create(Length(Bytes) * 3);
  try
    for i := Low(Bytes) to High(Bytes) do
    begin
      sb.Append(IntToHex(Bytes[i], 2));
      if i < High(Bytes) then
        sb.Append(' ');
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

procedure FillLogNode(var Node: TLogNode; const LogMessage: TCLientLogMessage);
begin
  Node.LogId               := LogMessage.DNLogMessage.LogId;
  Node.LogReceivedAt       := LogMessage.DNLogMessage.LogReceivedAt;
  Node.LogReceivedAtString := FormatDateTime(RECEIVED_AT_FORMAT, Node.LogReceivedAt);
  Node.LogPriority         := LogMessage.DNLogMessage.LogPriority;
  Node.LogTimestamp        := LogMessage.DNLogMessage.LogTimestamp;
  Node.LogTimestampString  := Format('%d.%.3d', [Node.LogTimestamp div 1000, Node.LogTimestamp mod 1000]);
  Node.LogClient           := LogMessage.ClientIP;
  Node.LogTypeNr           := LogMessage.DNLogMessage.LogTypeNr;
  Node.LogTypeNrString     := IntToStr(Node.LogTypeNr);
  Node.LogMessage          := LogMessage.DNLogMessage.LogMessage;
  Node.LogMessageLC        := Node.LogMessage.ToLower;
  Node.LogDataRaw          := Copy(LogMessage.DNLogMessage.LogData);
  Node.LogData             := BytesToHexStr(Node.LogDataRaw);
  Node.Selected            := False;
end;

function PriorityToStr(Priority: TDNLogPriority): string;
begin
  case Priority of
    prDebug    : Result := 'Debug';
    prInfo     : Result := 'Info';
    prWarning  : Result := 'Warning';
    prError    : Result := 'Error';
    prException: Result := 'Exception';
  else
    Result := string.Empty;
  end;
end;

procedure AppendLogHeader(StringBuilder: TStringBuilder; const Separator: string);
begin
  StringBuilder.Append('Id').Append(Separator)
               .Append('Received').Append(Separator)
               .Append('Priority').Append(Separator)
               .Append('Timestamp').Append(Separator)
               .Append('Client').Append(Separator)
               .Append('TypeNr').Append(Separator)
               .Append('Message').Append(Separator)
               .Append('Data')
               .AppendLine;
end;

procedure AppendLogRow(StringBuilder: TStringBuilder; const Node: TLogNode; const Separator: string);
begin
  StringBuilder.Append(Node.LogId).Append(Separator)
               .Append(Node.LogReceivedAtString).Append(Separator)
               .Append(PriorityToStr(Node.LogPriority)).Append(Separator)
               .Append(Node.LogTimestampString).Append(Separator)
               .Append(Node.LogClient).Append(Separator)
               .Append(Node.LogTypeNrString).Append(Separator)
               .Append(Node.LogMessage).Append(Separator)
               .Append(Node.LogData)
               .AppendLine;
end;

function FormatDeltaTime(MinTimestamp, MaxTimestamp: Cardinal): string;
var
  Delta: Cardinal;
begin
  Delta := MaxTimestamp - MinTimestamp;
  Result := Format('dt = %d.%.3d [s]', [Delta div 1000, Delta mod 1000]);
end;

{ TLogFilter }

constructor TLogFilter.Create(const Priority, Client, TypeNr, Text: string);
begin
  FPriority := Priority.Trim.ToLower;
  FClient   := Client;
  FText     := Text;
  FTextLC   := Text.ToLower;
  ParseTypeNrs(TypeNr);

  FShowAll := ((FPriority = '') or (FPriority = 'all')) and
              FClient.IsEmpty and not FHasTypeNr and FText.IsEmpty;
end;

procedure TLogFilter.AddTypeNr(Value: Integer);
begin
  if (Value >= Low(ShortInt)) and (Value <= High(ShortInt)) then
  begin
    Include(FTypeNrs, Byte(Value - Low(ShortInt)));
    FHasTypeNr := True;
  end;
end;

procedure TLogFilter.ParseTypeNrs(const TypeNrFilter: string);
var
  Part: string;
  Value, RangeStart, RangeEnd, j, p: Integer;
begin
  FHasTypeNr := False;
  FTypeNrs := [];
  if TypeNrFilter.Trim.IsEmpty then
    Exit;

  for Part in TypeNrFilter.Split([' ', ',', ';', '.'], TStringSplitOptions.ExcludeEmpty) do
  begin
    if TryStrToInt(Part, Value) then
    begin
      AddTypeNr(Value);
      Continue;
    end;

    // Range - the separating '-' is never the first char (that one is a sign)
    p := Part.IndexOf('-', 1);
    while p > 0 do
    begin
      if TryStrToInt(Part.Substring(0, p), RangeStart) and
         TryStrToInt(Part.Substring(p + 1), RangeEnd) then
      begin
        if RangeStart > RangeEnd then
        begin
          j := RangeStart;
          RangeStart := RangeEnd;
          RangeEnd := j;
        end;
        RangeStart := Max(RangeStart, Low(ShortInt));
        RangeEnd   := Min(RangeEnd, High(ShortInt));
        for j := RangeStart to RangeEnd do
          AddTypeNr(j);
        Break;
      end;
      p := Part.IndexOf('-', p + 1);
    end;
  end;
end;

function TLogFilter.Matches(const Node: TLogNode): Boolean;
var
  bVisible: Boolean;
begin
  if FShowAll then
    Exit(True);

  Result := False;

  if (FPriority <> '') and (FPriority <> 'all') then
  begin
    case Node.LogPriority of
      TDNLogPriority.prDebug    : bVisible := FPriority = 'debug';
      TDNLogPriority.prInfo     : bVisible := FPriority = 'info';
      TDNLogPriority.prWarning  : bVisible := FPriority = 'warning';
      TDNLogPriority.prError    : bVisible := FPriority = 'error';
      TDNLogPriority.prException: bVisible := FPriority = 'exception';
    else
      bVisible := True;
    end;
    if not bVisible then
      Exit;
  end;

  if not FClient.IsEmpty then
    if not Node.LogClient.StartsWith(FClient) then
      Exit;

  if FHasTypeNr then
    if (Node.LogTypeNr < Low(ShortInt)) or (Node.LogTypeNr > High(ShortInt)) or
       not (Byte(Node.LogTypeNr - Low(ShortInt)) in FTypeNrs) then
      Exit;

  // Message - case-insensitive, Data - case-sensitive
  if not FText.IsEmpty then
    if not Node.LogMessageLC.Contains(FTextLC) and not Node.LogData.Contains(FText) then
      Exit;

  Result := True;
end;

{ TCLientLogMessage }

constructor TCLientLogMessage.Create(const ClientIP: string;
  const DNLogMessage: TDNLogMessage);
begin
  Self.ClientIP := ClientIP;
  Self.DNLogMessage := DNLogMessage;
end;

{ TLogUpdateThread }

constructor TLogUpdateThread.Create(CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);
  FLogs := TThreadList<TCLientLogMessage>.Create;
  FDroppedCount := 0;
end;

destructor TLogUpdateThread.Destroy;
begin
  FLogs.Free;
  inherited;
end;

procedure TLogUpdateThread.Execute;
begin
  while not Terminated do
  begin
    var Queue := FLogs.LockList;
    if Queue.Count > 0 then
    begin
      if Assigned(FOnProcessLogs) then
      begin
        var LogsCount := Min(REFRESH_LIST_LOGS_COUNT, Queue.Count);
        var Logs: TArray<TCLientLogMessage>;
        SetLength(Logs, LogsCount);
        for var i := 0 to LogsCount - 1 do
          Logs[i] := Queue[i];
        Queue.DeleteRange(0, LogsCount);
        FLogs.UnlockList;

        if not Terminated then
          TThread.Synchronize(nil, procedure
          begin
            FOnProcessLogs(Logs);
          end);

        SetLength(Logs, 0);
      end else
      begin
        Queue.Clear;
        FLogs.UnlockList;
      end;
    end else
    begin
      FLogs.UnlockList;
      Sleep(10);
    end;
  end;
end;

procedure TLogUpdateThread.AddLog(const ClientIP: string; const LogMessage: TDNLogMessage);
var
  Queue: TList<TCLientLogMessage>;
  DropCount: Integer;
begin
  Queue := FLogs.LockList;
  try
    // Drop oldest logs if queue is full
    if Queue.Count >= MAX_LOG_QUEUE_SIZE then
    begin
      DropCount := Queue.Count - MAX_LOG_QUEUE_SIZE + 1;
      Queue.DeleteRange(0, DropCount);
      Inc(FDroppedCount, DropCount);
    end;
    Queue.Add(TCLientLogMessage.Create(ClientIP, LogMessage));
  finally
    FLogs.UnlockList;
  end;
end;

end.

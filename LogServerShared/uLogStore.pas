unit uLogStore;

// Thread-safe copy of the logs shown by the log server window, plus the UI state
// (filter, selection) the MCP server reports.
//
// Written only by the main thread (the forms), read by the MCP server from Indy
// threads. The MCP server never touches the UI, so it never has to wait for the
// main thread (no Synchronize - no deadlock when the app closes).
//
// TLogNode copies share their strings/bytes with the list nodes (reference
// counting), so the extra memory is just the record itself.
//
// Must not depend on VCL or FMX.

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  System.Generics.Defaults,
  uLogCommon;

type
  TLogUIFilter = record
    Priority: string;
    Client: string;
    TypeNr: string;
    Text: string;
    function IsEmpty: Boolean;
  end;

  TLogStore = class
  private
    FLock: TLightweightMREW;
    FLogs: TList<TLogNode>;
    FSelectedIds: TArray<Int64>;
    FUIFilter: TLogUIFilter;
  public
    constructor Create;
    destructor Destroy; override;

    // --- main thread -------------------------------------------------------
    procedure AddNodes(const Nodes: TArray<TLogNode>; Count: Integer);
    procedure Clear;
    procedure SetSelection(const Ids: TArray<Int64>);
    procedure SetUIFilter(const Priority, Client, TypeNr, Text: string);

    // --- any thread --------------------------------------------------------
    // Everything below must be called between BeginRead and EndRead. Keep the
    // lock short (copy what you need, format it after EndRead) - the main
    // thread can't add new logs while it is held.
    procedure BeginRead;
    procedure EndRead;
    function  Count: Integer;
    function  Node(Index: Integer): PLogNode;
    // Index of the first log with LogId >= Id (Count if there is none).
    function  LowerBound(Id: Int64): Integer;
    // Index of the log with exactly this Id, -1 if it isn't in the store.
    function  IndexOfId(Id: Int64): Integer;
    function  SelectedIds: TArray<Int64>;
    function  UIFilter: TLogUIFilter;
  end;

implementation

{ TLogUIFilter }

function TLogUIFilter.IsEmpty: Boolean;
begin
  Result := ((Priority = '') or SameText(Priority, 'All')) and
            (Client = '') and (TypeNr.Trim = '') and (Text = '');
end;

{ TLogStore }

constructor TLogStore.Create;
begin
  inherited Create;
  FLogs := TList<TLogNode>.Create;
end;

destructor TLogStore.Destroy;
begin
  FLogs.Free;
  inherited;
end;

procedure TLogStore.AddNodes(const Nodes: TArray<TLogNode>; Count: Integer);
begin
  if Count <= 0 then
    Exit;
  FLock.BeginWrite;
  try
    FLogs.Capacity := FLogs.Count + Count;
    for var i := 0 to Count - 1 do
      FLogs.Add(Nodes[i]);
  finally
    FLock.EndWrite;
  end;
end;

procedure TLogStore.Clear;
begin
  FLock.BeginWrite;
  try
    FLogs.Clear;
    FLogs.TrimExcess;
    FSelectedIds := nil;
  finally
    FLock.EndWrite;
  end;
end;

procedure TLogStore.SetSelection(const Ids: TArray<Int64>);
var
  Sorted: TArray<Int64>;
begin
  Sorted := Copy(Ids);
  TArray.Sort<Int64>(Sorted);
  FLock.BeginWrite;
  try
    FSelectedIds := Sorted;
  finally
    FLock.EndWrite;
  end;
end;

procedure TLogStore.SetUIFilter(const Priority, Client, TypeNr, Text: string);
begin
  FLock.BeginWrite;
  try
    FUIFilter.Priority := Priority;
    FUIFilter.Client   := Client;
    FUIFilter.TypeNr   := TypeNr;
    FUIFilter.Text     := Text;
  finally
    FLock.EndWrite;
  end;
end;

procedure TLogStore.BeginRead;
begin
  FLock.BeginRead;
end;

procedure TLogStore.EndRead;
begin
  FLock.EndRead;
end;

function TLogStore.Count: Integer;
begin
  Result := FLogs.Count;
end;

function TLogStore.Node(Index: Integer): PLogNode;
begin
  Result := @FLogs.List[Index];
end;

function TLogStore.LowerBound(Id: Int64): Integer;
var
  L, H, M: Integer;
begin
  // LogId is strictly increasing (assigned by TDNLogServer), so binary search
  L := 0;
  H := FLogs.Count;
  while L < H do
  begin
    M := (L + H) shr 1;
    if FLogs.List[M].LogId < Id then
      L := M + 1
    else
      H := M;
  end;
  Result := L;
end;

function TLogStore.IndexOfId(Id: Int64): Integer;
begin
  Result := LowerBound(Id);
  if (Result >= FLogs.Count) or (FLogs.List[Result].LogId <> Id) then
    Result := -1;
end;

function TLogStore.SelectedIds: TArray<Int64>;
begin
  Result := FSelectedIds;
end;

function TLogStore.UIFilter: TLogUIFilter;
begin
  Result := FUIFilter;
end;

end.

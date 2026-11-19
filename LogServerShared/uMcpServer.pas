unit uMcpServer;

// MCP (Model Context Protocol) server - gives AI tools (Claude Code, Codex,
// Cursor, ...) read access to the logs shown by the log server window.
//
// Transport: MCP "Streamable HTTP" - JSON-RPC 2.0 over HTTP POST to
// http://127.0.0.1:<port>/mcp, every request is answered with a single JSON
// response (no SSE streams, no sessions). Bound to localhost only.
//
// Requests are handled in Indy threads and read only from TLogStore - they
// never touch (or wait for) the UI.
//
// Must not depend on VCL or FMX.

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  uLogStore;

const
  MCP_PATH = '/mcp';

type
  TLogMcpServer = class
  private
    FStore: TLogStore;
    FHttp: TIdHTTPServer;
    FPort: Integer;
    FLastError: string;
    procedure AddBinding(const IP: string; IPv6: Boolean);
    procedure HttpCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    function  HandleMessage(const Msg: TJSONValue): TJSONObject;
    function  HandleRequest(const Method: string; const Params: TJSONObject): TJSONValue;
    function  Initialize(const Params: TJSONObject): TJSONObject;
    function  ToolsList: TJSONObject;
    function  CallTool(const Params: TJSONObject): TJSONObject;
    function  ToolGetSummary(const Args: TJSONObject): string;
    function  ToolGetLogs(const Args: TJSONObject): string;
    function  ToolGetLog(const Args: TJSONObject): string;
    function  ToolGetLogContext(const Args: TJSONObject): string;
    function  ToolGetSelectedLogs(const Args: TJSONObject): string;
    function  GetActive: Boolean;
    function  GetUrl: string;
  public
    constructor Create(AStore: TLogStore; APort: Integer);
    destructor Destroy; override;
    function  Start: Boolean;
    function  StatusText: string;
    property Active: Boolean read GetActive;
    property Port: Integer read FPort;
    property Url: string read GetUrl;
    property LastError: string read FLastError;
  end;

// MCP server port: MCP_SERVER_PORT, or the command line switch
//   -mcpport <n>  (also -mcpport:<n>)
function McpServerPort: Integer;

implementation

uses
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  IdGlobal,
  IdSocketHandle,
  DNLog.Types,
  uConstants,
  uLogCommon;

const
  SERVER_NAME    = 'dnetlog';
  SERVER_TITLE   = 'DNetLog Server';
  SERVER_VERSION = '1.0.0';

  // Newest first. If the client asks for a version not listed here, the newest
  // one is offered (the client decides whether it can use it).
  SUPPORTED_PROTOCOL_VERSIONS: array[0..3] of string =
    ('2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05');

  JSONRPC_PARSE_ERROR      = -32700;
  JSONRPC_INVALID_REQUEST  = -32600;
  JSONRPC_METHOD_NOT_FOUND = -32601;
  JSONRPC_INVALID_PARAMS   = -32602;
  JSONRPC_INTERNAL_ERROR   = -32603;

  DEFAULT_LIMIT            = 100;
  DEFAULT_SELECTED_LIMIT   = 200;
  DEFAULT_MAX_FIELD_LENGTH = 1000;
  DEFAULT_CONTEXT          = 10;
  MAX_CONTEXT              = 200;
  MAX_IDS                  = 100;

  SERVER_INSTRUCTIONS =
    'DNetLog Server receives log messages from running applications (often mobile apps) ' +
    'over TCP/UDP and shows them in a window. These tools read the logs currently held by that window. ' +
    'Each log has: id (unique, increasing - use since_id to poll for new logs), received (server local time), ' +
    'priority (Debug, Info, Warning, Error, Exception), timestamp (client tick count in seconds - only ' +
    'comparable between logs of the same client), client (sender IP), type (TypeNr, a number the app uses ' +
    'to group related logs), message and optional binary data (hex). ' +
    'Start with get_log_summary, then use get_logs with filters.';

type
  // JSON-RPC protocol error (reported as a JSON-RPC error response)
  EMcpError = class(Exception)
  private
    FCode: Integer;
  public
    constructor Create(ACode: Integer; const AMsg: string);
    property Code: Integer read FCode;
  end;

  // Tool error (reported as a tool result with isError = true, so the model sees it)
  EToolError = class(Exception);

  TLogQuery = record
    Filter: TLogFilter;
    HasMinPriority: Boolean;
    MinPriority: TDNLogPriority;
    Description: string;
    function Matches(const Node: TLogNode): Boolean;
  end;

constructor EMcpError.Create(ACode: Integer; const AMsg: string);
begin
  inherited Create(AMsg);
  FCode := ACode;
end;

{ --- helpers --------------------------------------------------------------- }

function McpServerPort: Integer;
var
  PortStr: string;
begin
  Result := MCP_SERVER_PORT;
  if FindCmdLineSwitch('mcpport', PortStr, True, [clstValueNextParam, clstValueAppended]) then
    if not TryStrToInt(PortStr, Result) or (Result <= 0) or (Result > 65535) then
      Result := MCP_SERVER_PORT;
end;

// Browsers send Origin - only local pages may talk to the server (protection
// against DNS rebinding). Non-browser clients (CLI tools) send no Origin.
function IsAllowedOrigin(const Origin: string): Boolean;
var
  Host: string;
  p: Integer;
begin
  if Origin = '' then
    Exit(True);

  Host := Origin.Trim.ToLower;
  p := Host.IndexOf('://');
  if p < 0 then
    Exit(False);
  Host := Host.Substring(p + 3);
  p := Host.IndexOf('/');
  if p >= 0 then
    Host := Host.Substring(0, p);

  if Host.StartsWith('[') then
  begin
    p := Host.IndexOf(']');
    if p < 0 then
      Exit(False);
    Host := Host.Substring(1, p - 1);
  end else
  begin
    p := Host.LastIndexOf(':');
    if p >= 0 then
      Host := Host.Substring(0, p);
  end;

  Result := (Host = 'localhost') or (Host = '127.0.0.1') or (Host = '::1');
end;

function JsonToBytes(const Json: TJSONValue): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(Json.ToJSON([TJSONAncestor.TJSONOutputOption.EncodeBelow32]));
end;

procedure SendBody(AResponseInfo: TIdHTTPResponseInfo; Status: Integer;
  const ContentType: string; const Body: TBytes);
begin
  AResponseInfo.ResponseNo := Status;
  if ContentType <> '' then
  begin
    AResponseInfo.ContentType := ContentType;
    AResponseInfo.CharSet := 'utf-8';
  end;
  // Always a stream (possibly empty) - otherwise Indy sends a default HTML body
  AResponseInfo.ContentStream := TBytesStream.Create(Body);
  AResponseInfo.ContentLength := Length(Body);
  AResponseInfo.FreeContentStream := True;
end;

procedure SendJson(AResponseInfo: TIdHTTPResponseInfo; Status: Integer; const Json: TJSONValue);
begin
  SendBody(AResponseInfo, Status, 'application/json', JsonToBytes(Json));
end;

procedure SendText(AResponseInfo: TIdHTTPResponseInfo; Status: Integer; const Text: string);
begin
  SendBody(AResponseInfo, Status, 'text/plain', TEncoding.UTF8.GetBytes(Text));
end;

function ReadBody(ARequestInfo: TIdHTTPRequestInfo): string;
var
  Bytes: TBytes;
  Stream: TStream;
begin
  Stream := ARequestInfo.PostStream;
  if not Assigned(Stream) or (Stream.Size = 0) then
    Exit(string.Empty);
  Stream.Position := 0;
  SetLength(Bytes, Stream.Size);
  Stream.ReadBuffer(Bytes, Length(Bytes));
  Result := TEncoding.UTF8.GetString(Bytes);
end;

function RpcResponse(const Id: TJSONValue; const AResult: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  if Assigned(Id) then
    Result.AddPair('id', TJSONValue(Id.Clone))
  else
    Result.AddPair('id', TJSONNull.Create);
  Result.AddPair('result', AResult);
end;

function RpcError(const Id: TJSONValue; Code: Integer; const Msg: string): TJSONObject;
var
  Err: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('jsonrpc', '2.0');
  if Assigned(Id) then
    Result.AddPair('id', TJSONValue(Id.Clone))
  else
    Result.AddPair('id', TJSONNull.Create);
  Err := TJSONObject.Create;
  Err.AddPair('code', TJSONNumber.Create(Code));
  Err.AddPair('message', Msg);
  Result.AddPair('error', Err);
end;

{ --- tool arguments -------------------------------------------------------- }

function ArgValue(const Args: TJSONObject; const Name: string): TJSONValue;
begin
  if Assigned(Args) then
    Result := Args.GetValue(Name)
  else
    Result := nil;
  if Result is TJSONNull then
    Result := nil;
end;

function ArgStr(const Args: TJSONObject; const Name: string; const Default: string = ''): string;
var
  V: TJSONValue;
begin
  V := ArgValue(Args, Name);
  if V = nil then
    Result := Default
  else if (V is TJSONString) or (V is TJSONNumber) then
    Result := V.Value
  else
    raise EToolError.CreateFmt('Argument "%s" must be a string.', [Name]);
end;

function JsonToInt64(const V: TJSONValue; const Name: string): Int64;
var
  D: Double;
begin
  if ((V is TJSONString) or (V is TJSONNumber)) then
  begin
    if TryStrToInt64(V.Value.Trim, Result) then
      Exit;
    if TryStrToFloat(V.Value.Trim, D, TFormatSettings.Invariant) and
       (Abs(D) < 9.0e18) and (Frac(D) = 0) then
      Exit(Trunc(D));
  end;
  raise EToolError.CreateFmt('Argument "%s" must be an integer.', [Name]);
end;

function HasArg(const Args: TJSONObject; const Name: string): Boolean;
begin
  Result := ArgValue(Args, Name) <> nil;
end;

function ArgInt(const Args: TJSONObject; const Name: string; Default: Int64): Int64;
var
  V: TJSONValue;
begin
  V := ArgValue(Args, Name);
  if V = nil then
    Result := Default
  else
    Result := JsonToInt64(V, Name);
end;

function ArgBool(const Args: TJSONObject; const Name: string; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  V := ArgValue(Args, Name);
  if V = nil then
    Result := Default
  else if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean
  else if (V is TJSONString) and SameText(V.Value, 'true') then
    Result := True
  else if (V is TJSONString) and SameText(V.Value, 'false') then
    Result := False
  else
    raise EToolError.CreateFmt('Argument "%s" must be a boolean.', [Name]);
end;

function ArgIds(const Args: TJSONObject; const Name: string): TArray<Int64>;
var
  V: TJSONValue;
  Item: TJSONValue;
begin
  V := ArgValue(Args, Name);
  Result := nil;
  if V = nil then
    Exit;
  if V is TJSONArray then
  begin
    for Item in TJSONArray(V) do
      Result := Result + [JsonToInt64(Item, Name)];
  end else
    Result := [JsonToInt64(V, Name)];
end;

function TryParsePriority(const S: string; out Priority: TDNLogPriority): Boolean;
begin
  for var P := Low(TDNLogPriority) to High(TDNLogPriority) do
    if SameText(PriorityToStr(P), S.Trim) then
    begin
      Priority := P;
      Exit(True);
    end;
  Result := False;
end;

function IsAllPriority(const S: string): Boolean;
begin
  Result := (S.Trim = '') or SameText(S.Trim, 'All');
end;

{ TLogQuery }

function TLogQuery.Matches(const Node: TLogNode): Boolean;
begin
  if HasMinPriority and (Node.LogPriority < MinPriority) then
    Exit(False);
  Result := Filter.Matches(Node);
end;

function BuildQuery(Store: TLogStore; const Args: TJSONObject): TLogQuery;
var
  UI: TLogUIFilter;
  Priority, Client, TypeNr, Text, MinPriority, Desc: string;
  P: TDNLogPriority;
begin
  UI := Default(TLogUIFilter);
  if ArgBool(Args, 'use_ui_filter', False) then
  begin
    Store.BeginRead;
    try
      UI := Store.UIFilter;
    finally
      Store.EndRead;
    end;
  end;

  Priority    := ArgStr(Args, 'priority', UI.Priority);
  Client      := ArgStr(Args, 'client',   UI.Client);
  TypeNr      := ArgStr(Args, 'type_nr',  UI.TypeNr);
  Text        := ArgStr(Args, 'text',     UI.Text);
  MinPriority := ArgStr(Args, 'min_priority');

  if not IsAllPriority(Priority) and not TryParsePriority(Priority, P) then
    raise EToolError.CreateFmt('Unknown priority "%s". Use All, Debug, Info, Warning, Error or Exception.', [Priority]);

  Result.HasMinPriority := not IsAllPriority(MinPriority);
  if Result.HasMinPriority and not TryParsePriority(MinPriority, Result.MinPriority) then
    raise EToolError.CreateFmt('Unknown min_priority "%s". Use Debug, Info, Warning, Error or Exception.', [MinPriority]);

  Result.Filter := TLogFilter.Create(Priority, Client, TypeNr, Text);

  Desc := '';
  if not IsAllPriority(Priority) then Desc := Desc + Format(' priority=%s', [Priority]);
  if Result.HasMinPriority then Desc := Desc + Format(' min_priority=%s', [MinPriority]);
  if Client <> '' then Desc := Desc + Format(' client=%s', [Client]);
  if TypeNr.Trim <> '' then Desc := Desc + Format(' type_nr="%s"', [TypeNr]);
  if Text <> '' then Desc := Desc + Format(' text="%s"', [Text]);
  if Desc = '' then
    Result.Description := 'none'
  else
    Result.Description := Desc.Trim;
end;

{ --- formatting ------------------------------------------------------------ }

function Truncated(const S: string; MaxLen: Integer): string;
begin
  if (MaxLen > 0) and (S.Length > MaxLen) then
    Result := S.Substring(0, MaxLen) + Format('...[+%d chars]', [S.Length - MaxLen])
  else
    Result := S;
end;

// One log per line - line breaks and tabs are escaped
function OneLine(const S: string): string;
begin
  Result := S.Replace(#13#10, '\n').Replace(#10, '\n').Replace(#13, '\n').Replace(#9, '\t');
end;

function FormatLogLine(const Node: TLogNode; MaxLen: Integer; IncludeData: Boolean): string;
begin
  Result := Format('#%d %s %s ts=%s client=%s type=%d | %s',
    [Node.LogId, Node.LogReceivedAtString, PriorityToStr(Node.LogPriority).ToUpper,
     Node.LogTimestampString, Node.LogClient, Node.LogTypeNr,
     OneLine(Truncated(Node.LogMessage, MaxLen))]);
  if IncludeData and (Length(Node.LogDataRaw) > 0) then
    Result := Result + Format(' | data[%d B]: %s', [Length(Node.LogDataRaw), Truncated(Node.LogData, MaxLen)]);
end;

procedure AppendLogFull(sb: TStringBuilder; const Node: TLogNode);
begin
  sb.AppendFormat('#%d', [Node.LogId]).AppendLine;
  sb.Append('  received:  ').Append(Node.LogReceivedAtString).AppendLine;
  sb.Append('  priority:  ').Append(PriorityToStr(Node.LogPriority)).AppendLine;
  sb.Append('  timestamp: ').Append(Node.LogTimestampString).Append(' s (client tick count)').AppendLine;
  sb.Append('  client:    ').Append(Node.LogClient).AppendLine;
  sb.Append('  type_nr:   ').Append(Node.LogTypeNr).AppendLine;
  sb.AppendFormat('  message (%d chars):', [Node.LogMessage.Length]).AppendLine;
  sb.Append(Node.LogMessage).AppendLine;
  if Length(Node.LogDataRaw) > 0 then
  begin
    sb.AppendFormat('  data (%d bytes, hex):', [Length(Node.LogDataRaw)]).AppendLine;
    sb.Append(Node.LogData).AppendLine;
  end else
    sb.Append('  data: none').AppendLine;
end;

function LimitArg(const Args: TJSONObject; const Name: string; Default, Max: Integer): Integer;
begin
  Result := EnsureRange(ArgInt(Args, Name, Default), 0, Max);
end;

{ --- tool definitions ------------------------------------------------------ }

function Prop(const AType, ADesc: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', AType);
  Result.AddPair('description', ADesc);
end;

function PriorityProp(const ADesc: string; WithAll: Boolean): TJSONObject;
var
  Enum: TJSONArray;
begin
  Result := Prop('string', ADesc);
  Enum := TJSONArray.Create;
  if WithAll then
    Enum.Add('All');
  for var P := Low(TDNLogPriority) to High(TDNLogPriority) do
    Enum.Add(PriorityToStr(P));
  Result.AddPair('enum', Enum);
end;

procedure AddFilterProps(Props: TJSONObject);
begin
  Props.AddPair('priority', PriorityProp('Only logs with exactly this priority.', True));
  Props.AddPair('min_priority', PriorityProp('Only logs with this priority or higher ' +
    '(Debug < Info < Warning < Error < Exception), e.g. Warning = warnings, errors and exceptions.', False));
  Props.AddPair('client', Prop('string', 'Client IP prefix (case-sensitive), e.g. "192.168.1.15".'));
  Props.AddPair('type_nr', Prop('string', 'TypeNr values and ranges separated by space, comma or semicolon, ' +
    'e.g. "5", "1-3, 7", "-10--5".'));
  Props.AddPair('text', Prop('string', 'Substring searched in the message (case-insensitive) ' +
    'and in the binary data hex string (case-sensitive, format "0A 1B").'));
  Props.AddPair('use_ui_filter', Prop('boolean', 'Start from the filter currently set in the DNetLog Server window ' +
    '(what the user sees). priority/client/type_nr/text arguments override single fields. Default false.'));
end;

procedure AddOutputProps(Props: TJSONObject);
begin
  Props.AddPair('max_field_length', Prop('integer', Format('Truncate message and data to this many characters ' +
    '(0 = no limit). Default %d. Use get_log for the full content.', [DEFAULT_MAX_FIELD_LENGTH])));
  Props.AddPair('include_data', Prop('boolean', 'Include binary data (hex). Default true.'));
end;

function MakeTool(const Name, Title, Desc: string; Props: TJSONObject;
  const Required: array of string): TJSONObject;
var
  Schema, Annotations: TJSONObject;
  Req: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('title', Title);
  Result.AddPair('description', Desc);

  Schema := TJSONObject.Create;
  Schema.AddPair('type', 'object');
  Schema.AddPair('properties', Props);
  if Length(Required) > 0 then
  begin
    Req := TJSONArray.Create;
    for var s in Required do
      Req.Add(s);
    Schema.AddPair('required', Req);
  end;
  Result.AddPair('inputSchema', Schema);

  Annotations := TJSONObject.Create;
  Annotations.AddPair('readOnlyHint', TJSONBool.Create(True));
  Annotations.AddPair('openWorldHint', TJSONBool.Create(False));
  Result.AddPair('annotations', Annotations);
end;

{ TLogMcpServer }

constructor TLogMcpServer.Create(AStore: TLogStore; APort: Integer);
begin
  inherited Create;
  FStore := AStore;
  FPort  := APort;
  FHttp  := TIdHTTPServer.Create(nil);
  FHttp.DefaultPort    := APort;
  FHttp.ParseParams    := False;  // keep the body in PostStream whatever the content type
  FHttp.KeepAlive      := True;
  FHttp.ServerSoftware := 'DNetLog MCP Server';
  FHttp.OnCommandGet   := HttpCommand;
  FHttp.OnCommandOther := HttpCommand;
end;

destructor TLogMcpServer.Destroy;
begin
  if Assigned(FHttp) then
  begin
    try
      FHttp.Active := False;
    except
      // closing the app - nothing useful to do
    end;
    FreeAndNil(FHttp);
  end;
  inherited;
end;

procedure TLogMcpServer.AddBinding(const IP: string; IPv6: Boolean);
var
  Binding: TIdSocketHandle;
begin
  Binding := FHttp.Bindings.Add;
  Binding.IP := IP;
  Binding.Port := FPort;
  if IPv6 then
    Binding.IPVersion := TIdIPVersion.Id_IPv6
  else
    Binding.IPVersion := TIdIPVersion.Id_IPv4;
end;

function TLogMcpServer.Start: Boolean;
begin
  FLastError := '';
  // Localhost only - IPv4 and IPv6 ("localhost" may resolve to ::1)
  try
    FHttp.Bindings.Clear;
    AddBinding('127.0.0.1', False);
    AddBinding('::1', True);
    FHttp.Active := True;
  except
    // Maybe no IPv6 - try IPv4 only
    try
      FHttp.Active := False;
      FHttp.Bindings.Clear;
      AddBinding('127.0.0.1', False);
      FHttp.Active := True;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        try
          FHttp.Active := False;
        except
        end;
      end;
    end;
  end;
  Result := FHttp.Active;
end;

function TLogMcpServer.GetActive: Boolean;
begin
  Result := Assigned(FHttp) and FHttp.Active;
end;

function TLogMcpServer.GetUrl: string;
begin
  Result := Format('http://127.0.0.1:%d%s', [FPort, MCP_PATH]);
end;

function TLogMcpServer.StatusText: string;
begin
  if Active then
    Result := 'MCP: ' + Url
  else
    Result := Format('MCP: off (port %d: %s)', [FPort, FLastError]);
end;

procedure TLogMcpServer.HttpCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  Msg: TJSONValue;
  Response: TJSONObject;
  Responses: TJSONArray;
  Item: TJSONValue;
begin
  try
    if not IsAllowedOrigin(ARequestInfo.RawHeaders.Values['Origin']) then
    begin
      SendText(AResponseInfo, 403, 'Forbidden origin');
      Exit;
    end;

    if not (SameText(ARequestInfo.Document, MCP_PATH) or SameText(ARequestInfo.Document, MCP_PATH + '/')) then
    begin
      SendText(AResponseInfo, 404, Format('Not found. The MCP endpoint is %s', [MCP_PATH]));
      Exit;
    end;

    // No server-initiated SSE stream (GET) and no sessions (DELETE)
    if ARequestInfo.CommandType <> hcPOST then
    begin
      AResponseInfo.CustomHeaders.Values['Allow'] := 'POST';
      SendText(AResponseInfo, 405, 'Method not allowed');
      Exit;
    end;

    Msg := TJSONValue.ParseJSONValue(ReadBody(ARequestInfo));
    if Msg = nil then
    begin
      Response := RpcError(nil, JSONRPC_PARSE_ERROR, 'Parse error');
      try
        SendJson(AResponseInfo, 400, Response);
      finally
        Response.Free;
      end;
      Exit;
    end;

    try
      if Msg is TJSONArray then
      begin
        // JSON-RPC batch (older protocol versions)
        Responses := TJSONArray.Create;
        try
          for Item in TJSONArray(Msg) do
          begin
            Response := HandleMessage(Item);
            if Assigned(Response) then
              Responses.AddElement(Response);
          end;
          if Responses.Count = 0 then
            SendBody(AResponseInfo, 202, '', nil)
          else
            SendJson(AResponseInfo, 200, Responses);
        finally
          Responses.Free;
        end;
      end else
      begin
        Response := HandleMessage(Msg);
        if Assigned(Response) then
          try
            SendJson(AResponseInfo, 200, Response);
          finally
            Response.Free;
          end
        else
          // Notification or response - accepted, no body
          SendBody(AResponseInfo, 202, '', nil);
      end;
    finally
      Msg.Free;
    end;
  except
    on E: Exception do
    begin
      Response := RpcError(nil, JSONRPC_INTERNAL_ERROR, E.Message);
      try
        SendJson(AResponseInfo, 500, Response);
      finally
        Response.Free;
      end;
    end;
  end;
end;

// Returns nil for notifications and for responses sent by the client.
function TLogMcpServer.HandleMessage(const Msg: TJSONValue): TJSONObject;
var
  Obj, Params: TJSONObject;
  Id, MethodValue, ParamsValue, ResultValue: TJSONValue;
begin
  if not (Msg is TJSONObject) then
    Exit(RpcError(nil, JSONRPC_INVALID_REQUEST, 'Invalid request'));

  Obj := TJSONObject(Msg);
  MethodValue := Obj.GetValue('method');
  Id := Obj.GetValue('id');

  if MethodValue = nil then
    Exit(nil);  // a response from the client - we never send requests, ignore
  if Id = nil then
    Exit(nil);  // notification (notifications/initialized, notifications/cancelled, ...)

  if not (MethodValue is TJSONString) then
    Exit(RpcError(Id, JSONRPC_INVALID_REQUEST, 'Invalid request: method must be a string'));

  ParamsValue := Obj.GetValue('params');
  if ParamsValue is TJSONObject then
    Params := TJSONObject(ParamsValue)
  else
    Params := nil;

  try
    ResultValue := HandleRequest(MethodValue.Value, Params);
    // Unknown method is not raised as an exception: clients probe for optional methods
    // (e.g. server/discover), which would break into the debugger on every connect.
    if ResultValue = nil then
      Result := RpcError(Id, JSONRPC_METHOD_NOT_FOUND, 'Method not found: ' + MethodValue.Value)
    else
      Result := RpcResponse(Id, ResultValue);
  except
    on E: EMcpError do
      Result := RpcError(Id, E.Code, E.Message);
    on E: Exception do
      Result := RpcError(Id, JSONRPC_INTERNAL_ERROR, E.Message);
  end;
end;

function TLogMcpServer.HandleRequest(const Method: string; const Params: TJSONObject): TJSONValue;
begin
  if Method = 'initialize' then
    Result := Initialize(Params)
  else if Method = 'ping' then
    Result := TJSONObject.Create
  else if Method = 'tools/list' then
    Result := ToolsList
  else if Method = 'tools/call' then
    Result := CallTool(Params)
  else
    Result := nil;  // method not found - HandleMessage answers with JSONRPC_METHOD_NOT_FOUND
end;

function TLogMcpServer.Initialize(const Params: TJSONObject): TJSONObject;
var
  Requested, Version: string;
  Capabilities, Tools, Info: TJSONObject;
begin
  Requested := '';
  if Assigned(Params) then
    Params.TryGetValue<string>('protocolVersion', Requested);

  Version := SUPPORTED_PROTOCOL_VERSIONS[0];
  for var v in SUPPORTED_PROTOCOL_VERSIONS do
    if v = Requested then
      Version := v;

  Result := TJSONObject.Create;
  Result.AddPair('protocolVersion', Version);

  Capabilities := TJSONObject.Create;
  Tools := TJSONObject.Create;
  Tools.AddPair('listChanged', TJSONBool.Create(False));
  Capabilities.AddPair('tools', Tools);
  Result.AddPair('capabilities', Capabilities);

  Info := TJSONObject.Create;
  Info.AddPair('name', SERVER_NAME);
  Info.AddPair('title', SERVER_TITLE);
  Info.AddPair('version', SERVER_VERSION);
  Result.AddPair('serverInfo', Info);

  Result.AddPair('instructions', SERVER_INSTRUCTIONS);
end;

function TLogMcpServer.ToolsList: TJSONObject;
var
  Tools: TJSONArray;
  Props: TJSONObject;
begin
  Tools := TJSONArray.Create;

  Tools.AddElement(MakeTool('get_log_summary', 'Log summary',
    'Overview of the logs held by DNetLog Server: total count, counts per priority, per client (IP) ' +
    'and per TypeNr, id and time range, the filter currently set in the window and how many rows ' +
    'the user has selected. Call this first.',
    TJSONObject.Create, []));

  Props := TJSONObject.Create;
  AddFilterProps(Props);
  Props.AddPair('limit', Prop('integer', Format('Max logs to return, default %d, max %d.', [DEFAULT_LIMIT, MCP_MAX_LIMIT])));
  Props.AddPair('since_id', Prop('integer', 'Only logs with id > since_id, returned oldest first ' +
    '(use the next since_id from a previous call to get new logs).'));
  Props.AddPair('before_id', Prop('integer', 'Only logs with id < before_id (use it to page back to older logs).'));
  AddOutputProps(Props);
  Tools.AddElement(MakeTool('get_logs', 'Get logs',
    'Returns logs matching the filters, one per line: ' +
    '"#id received PRIORITY ts=<client time [s]> client=<ip> type=<TypeNr> | message | data[n B]: hex". ' +
    'Line breaks in messages are shown as \n. Without since_id it returns the newest matching logs ' +
    '(in chronological order); with since_id the oldest logs after that id.',
    Props, []));

  Props := TJSONObject.Create;
  Props.AddPair('ids', Prop('array', Format('Log ids (max %d).', [MAX_IDS])));
  Props.GetValue<TJSONObject>('ids').AddPair('items', TJSONObject.Create(TJSONPair.Create('type', 'integer')));
  Tools.AddElement(MakeTool('get_log', 'Get log details',
    'Full, untruncated details of the given logs (multi-line message, complete binary data).',
    Props, ['ids']));

  Props := TJSONObject.Create;
  Props.AddPair('id', Prop('integer', 'Log id.'));
  Props.AddPair('before', Prop('integer', Format('Logs before it, default %d, max %d.', [DEFAULT_CONTEXT, MAX_CONTEXT])));
  Props.AddPair('after', Prop('integer', Format('Logs after it, default %d, max %d.', [DEFAULT_CONTEXT, MAX_CONTEXT])));
  Props.AddPair('same_client', Prop('boolean', 'Only logs from the same client as the given log. Default true.'));
  AddOutputProps(Props);
  Tools.AddElement(MakeTool('get_log_context', 'Get log context',
    'Logs received just before and after the given log (no other filters) - what happened around an error.',
    Props, ['id']));

  Props := TJSONObject.Create;
  Props.AddPair('limit', Prop('integer', Format('Max logs to return, default %d, max %d.', [DEFAULT_SELECTED_LIMIT, MCP_MAX_LIMIT])));
  Props.AddPair('since_id', Prop('integer', 'Only selected logs with id > since_id ' +
    '(use the since_id from a previous call to get the next page).'));
  AddOutputProps(Props);
  Tools.AddElement(MakeTool('get_selected_logs', 'Get selected logs',
    'Logs the user has selected in the DNetLog Server window, oldest first. Use it when the user refers to ' +
    '"these logs", "the selected rows" or "this error". If more are selected than returned, ' +
    'page with since_id.',
    Props, []));

  Result := TJSONObject.Create;
  Result.AddPair('tools', Tools);
end;

function TLogMcpServer.CallTool(const Params: TJSONObject): TJSONObject;
var
  Name, Text: string;
  Args: TJSONObject;
  ArgsValue: TJSONValue;
  IsError: Boolean;
  Content: TJSONArray;
  Item: TJSONObject;
begin
  if not Assigned(Params) or not Params.TryGetValue<string>('name', Name) then
    raise EMcpError.Create(JSONRPC_INVALID_PARAMS, 'Missing tool name');

  ArgsValue := Params.GetValue('arguments');
  if ArgsValue is TJSONObject then
    Args := TJSONObject(ArgsValue)
  else
    Args := nil;

  IsError := False;
  try
    if Name = 'get_log_summary' then
      Text := ToolGetSummary(Args)
    else if Name = 'get_logs' then
      Text := ToolGetLogs(Args)
    else if Name = 'get_log' then
      Text := ToolGetLog(Args)
    else if Name = 'get_log_context' then
      Text := ToolGetLogContext(Args)
    else if Name = 'get_selected_logs' then
      Text := ToolGetSelectedLogs(Args)
    else
      raise EMcpError.Create(JSONRPC_INVALID_PARAMS, 'Unknown tool: ' + Name);
  except
    on E: EToolError do
    begin
      Text := E.Message;
      IsError := True;
    end;
  end;

  Item := TJSONObject.Create;
  Item.AddPair('type', 'text');
  Item.AddPair('text', Text);
  Content := TJSONArray.Create;
  Content.AddElement(Item);

  Result := TJSONObject.Create;
  Result.AddPair('content', Content);
  Result.AddPair('isError', TJSONBool.Create(IsError));
end;

{ --- tools ----------------------------------------------------------------- }

function TLogMcpServer.ToolGetSummary(const Args: TJSONObject): string;
var
  Total, UIMatching: Int64;
  PerPriority: array[TDNLogPriority] of Int64;
  Clients: TDictionary<string, Int64>;
  Types: TDictionary<Integer, Int64>;
  UI: TLogUIFilter;
  UIFilter: TLogFilter;
  SelCount: Integer;
  First, Last: TLogNode;
  Count: Int64;
  sb: TStringBuilder;
  ClientKeys: TArray<string>;
  TypeKeys: TArray<Integer>;
begin
  FillChar(PerPriority, SizeOf(PerPriority), 0);
  UIMatching := 0;
  Clients := TDictionary<string, Int64>.Create;
  Types := TDictionary<Integer, Int64>.Create;
  sb := TStringBuilder.Create;
  try
    FStore.BeginRead;
    try
      Total := FStore.Count;
      UI := FStore.UIFilter;
      UIFilter := TLogFilter.Create(UI.Priority, UI.Client, UI.TypeNr, UI.Text);
      SelCount := Length(FStore.SelectedIds);
      if Total > 0 then
      begin
        First := FStore.Node(0)^;
        Last  := FStore.Node(Total - 1)^;
      end;
      for var i := 0 to Total - 1 do
      begin
        var N := FStore.Node(i);
        Inc(PerPriority[N.LogPriority]);
        if not Clients.TryGetValue(N.LogClient, Count) then
          Count := 0;
        Clients.AddOrSetValue(N.LogClient, Count + 1);
        if not Types.TryGetValue(N.LogTypeNr, Count) then
          Count := 0;
        Types.AddOrSetValue(N.LogTypeNr, Count + 1);
        if UIFilter.Matches(N^) then
          Inc(UIMatching);
      end;
    finally
      FStore.EndRead;
    end;

    sb.AppendFormat('Logs: %d', [Total]).AppendLine;
    if Total = 0 then
    begin
      sb.Append('No logs received yet (or the log was cleared). Logs are sent by apps using DNetLog ' +
        Format('to port %d of this computer.', [SERVER_PORT])).AppendLine;
    end else
    begin
      sb.AppendFormat('Ids: %d .. %d', [First.LogId, Last.LogId]).AppendLine;
      sb.AppendFormat('Received: %s .. %s', [First.LogReceivedAtString, Last.LogReceivedAtString]).AppendLine;
      sb.Append('Per priority:');
      for var P := Low(TDNLogPriority) to High(TDNLogPriority) do
        sb.AppendFormat(' %s=%d', [PriorityToStr(P), PerPriority[P]]);
      sb.AppendLine;

      sb.Append('Per client:').AppendLine;
      ClientKeys := Clients.Keys.ToArray;
      TArray.Sort<string>(ClientKeys);
      for var k in ClientKeys do
        sb.AppendFormat('  %s: %d', [k, Clients[k]]).AppendLine;

      sb.Append('Per TypeNr:').AppendLine;
      TypeKeys := Types.Keys.ToArray;
      TArray.Sort<Integer>(TypeKeys);
      for var k in TypeKeys do
        sb.AppendFormat('  %d: %d', [k, Types[k]]).AppendLine;
    end;

    if UI.IsEmpty then
      sb.Append('Window filter: none (all logs visible)').AppendLine
    else
      sb.AppendFormat('Window filter: priority=%s client="%s" type_nr="%s" text="%s" - %d logs visible',
        [UI.Priority, UI.Client, UI.TypeNr, UI.Text, UIMatching]).AppendLine;
    sb.AppendFormat('Selected in window: %d', [SelCount]).AppendLine;

    Result := sb.ToString;
  finally
    sb.Free;
    Clients.Free;
    Types.Free;
  end;
end;

function TLogMcpServer.ToolGetLogs(const Args: TJSONObject): string;
var
  Query: TLogQuery;
  Limit, MaxLen, StartIdx, EndIdx, i: Integer;
  IncludeData, Forward, HasSince, HasBefore, HasMore: Boolean;
  SinceId, BeforeId, StoreFirstId, StoreLastId, NextSinceId: Int64;
  StoreCount: Integer;
  Found: TList<TLogNode>;
  sb: TStringBuilder;
begin
  Query       := BuildQuery(FStore, Args);
  Limit       := LimitArg(Args, 'limit', DEFAULT_LIMIT, MCP_MAX_LIMIT);
  MaxLen      := ArgInt(Args, 'max_field_length', DEFAULT_MAX_FIELD_LENGTH);
  IncludeData := ArgBool(Args, 'include_data', True);
  HasSince    := HasArg(Args, 'since_id');
  HasBefore   := HasArg(Args, 'before_id');
  SinceId     := ArgInt(Args, 'since_id', 0);
  BeforeId    := ArgInt(Args, 'before_id', 0);
  Forward     := HasSince;
  HasMore     := False;
  StoreFirstId := 0;
  StoreLastId  := 0;

  Found := TList<TLogNode>.Create;
  sb := TStringBuilder.Create;
  try
    FStore.BeginRead;
    try
      StoreCount := FStore.Count;
      if StoreCount > 0 then
      begin
        StoreFirstId := FStore.Node(0).LogId;
        StoreLastId  := FStore.Node(StoreCount - 1).LogId;
      end;

      if HasSince then
        StartIdx := FStore.LowerBound(SinceId + 1)
      else
        StartIdx := 0;
      if HasBefore then
        EndIdx := FStore.LowerBound(BeforeId)
      else
        EndIdx := StoreCount;

      if Forward then
      begin
        i := StartIdx;
        while i < EndIdx do
        begin
          if Query.Matches(FStore.Node(i)^) then
          begin
            if Found.Count >= Limit then
            begin
              HasMore := True;
              Break;
            end;
            Found.Add(FStore.Node(i)^);
          end;
          Inc(i);
        end;
      end else
      begin
        i := EndIdx - 1;
        while i >= StartIdx do
        begin
          if Query.Matches(FStore.Node(i)^) then
          begin
            if Found.Count >= Limit then
            begin
              HasMore := True;
              Break;
            end;
            Found.Add(FStore.Node(i)^);
          end;
          Dec(i);
        end;
        Found.Reverse;
      end;
    finally
      FStore.EndRead;
    end;

    // Header
    if Found.Count > 0 then
      sb.AppendFormat('Returned %d logs (oldest first), ids %d .. %d.',
        [Found.Count, Found.First.LogId, Found.Last.LogId])
    else
      sb.Append('No matching logs.');
    if StoreCount > 0 then
      sb.AppendFormat(' Server holds %d logs (ids %d .. %d).', [StoreCount, StoreFirstId, StoreLastId])
    else
      sb.Append(' Server holds no logs.');
    sb.AppendLine;
    sb.Append('Filter: ').Append(Query.Description).AppendLine;

    if HasMore and not Forward then
      sb.AppendFormat('More older matching logs exist - call again with before_id=%d.', [Found.First.LogId]).AppendLine;

    NextSinceId := -1;
    if Forward and HasMore then
    begin
      sb.AppendFormat('More newer matching logs exist - call again with since_id=%d.', [Found.Last.LogId]).AppendLine;
      NextSinceId := -2;
    end else
    if not HasBefore then
      NextSinceId := Max(StoreLastId, IfThen(HasSince, SinceId, 0));
    if NextSinceId >= 0 then
      sb.AppendFormat('To get logs that arrive later, call again with since_id=%d.', [NextSinceId]).AppendLine;

    if Found.Count > 0 then
      sb.AppendLine;
    for var N in Found do
      sb.Append(FormatLogLine(N, MaxLen, IncludeData)).AppendLine;

    Result := sb.ToString;
  finally
    sb.Free;
    Found.Free;
  end;
end;

function TLogMcpServer.ToolGetLog(const Args: TJSONObject): string;
var
  Ids, Missing: TArray<Int64>;
  Found: TList<TLogNode>;
  Idx: Integer;
  sb: TStringBuilder;
begin
  Ids := ArgIds(Args, 'ids');
  if Length(Ids) = 0 then
    Ids := ArgIds(Args, 'id');
  if Length(Ids) = 0 then
    raise EToolError.Create('Argument "ids" is required.');
  if Length(Ids) > MAX_IDS then
    raise EToolError.CreateFmt('Too many ids (%d), max %d.', [Length(Ids), MAX_IDS]);

  Missing := nil;
  Found := TList<TLogNode>.Create;
  sb := TStringBuilder.Create;
  try
    FStore.BeginRead;
    try
      for var Id in Ids do
      begin
        Idx := FStore.IndexOfId(Id);
        if Idx >= 0 then
          Found.Add(FStore.Node(Idx)^)
        else
          Missing := Missing + [Id];
      end;
    finally
      FStore.EndRead;
    end;

    for var N in Found do
    begin
      AppendLogFull(sb, N);
      sb.AppendLine;
    end;
    if Length(Missing) > 0 then
    begin
      sb.Append('Not found (wrong id or the log was cleared):');
      for var Id in Missing do
        sb.Append(' ').Append(Id);
      sb.AppendLine;
    end;
    Result := sb.ToString;
  finally
    sb.Free;
    Found.Free;
  end;
end;

function TLogMcpServer.ToolGetLogContext(const Args: TJSONObject): string;
var
  Id: Int64;
  Before, After, MaxLen, Idx, i, n: Integer;
  SameClient, IncludeData: Boolean;
  Client: string;
  Prev, Next: TList<TLogNode>;
  Target: TLogNode;
  sb: TStringBuilder;
begin
  if not HasArg(Args, 'id') then
    raise EToolError.Create('Argument "id" is required.');
  Id          := ArgInt(Args, 'id', 0);
  Before      := LimitArg(Args, 'before', DEFAULT_CONTEXT, MAX_CONTEXT);
  After       := LimitArg(Args, 'after', DEFAULT_CONTEXT, MAX_CONTEXT);
  SameClient  := ArgBool(Args, 'same_client', True);
  MaxLen      := ArgInt(Args, 'max_field_length', DEFAULT_MAX_FIELD_LENGTH);
  IncludeData := ArgBool(Args, 'include_data', True);

  Prev := TList<TLogNode>.Create;
  Next := TList<TLogNode>.Create;
  sb := TStringBuilder.Create;
  try
    FStore.BeginRead;
    try
      Idx := FStore.IndexOfId(Id);
      if Idx < 0 then
        raise EToolError.CreateFmt('Log #%d not found (wrong id or the log was cleared).', [Id]);
      Target := FStore.Node(Idx)^;
      Client := Target.LogClient;

      i := Idx - 1;
      n := 0;
      while (i >= 0) and (n < Before) do
      begin
        if not SameClient or (FStore.Node(i).LogClient = Client) then
        begin
          Prev.Add(FStore.Node(i)^);
          Inc(n);
        end;
        Dec(i);
      end;
      Prev.Reverse;

      i := Idx + 1;
      n := 0;
      while (i < FStore.Count) and (n < After) do
      begin
        if not SameClient or (FStore.Node(i).LogClient = Client) then
        begin
          Next.Add(FStore.Node(i)^);
          Inc(n);
        end;
        Inc(i);
      end;
    finally
      FStore.EndRead;
    end;

    sb.AppendFormat('Context of log #%d: %d before, %d after', [Id, Prev.Count, Next.Count]);
    if SameClient then
      sb.AppendFormat(' (only client %s)', [Client]);
    sb.Append('. The log itself is marked with ">>".').AppendLine.AppendLine;
    for var L in Prev do
      sb.Append('   ').Append(FormatLogLine(L, MaxLen, IncludeData)).AppendLine;
    sb.Append('>> ').Append(FormatLogLine(Target, MaxLen, IncludeData)).AppendLine;
    for var L in Next do
      sb.Append('   ').Append(FormatLogLine(L, MaxLen, IncludeData)).AppendLine;

    Result := sb.ToString;
  finally
    sb.Free;
    Prev.Free;
    Next.Free;
  end;
end;

function TLogMcpServer.ToolGetSelectedLogs(const Args: TJSONObject): string;
var
  Ids: TArray<Int64>;
  Limit, MaxLen, Idx, Skipped: Integer;
  IncludeData, HasSince, HasMore: Boolean;
  SinceId: Int64;
  Found: TList<TLogNode>;
  MinTs, MaxTs: Cardinal;
  sb: TStringBuilder;
begin
  Limit       := LimitArg(Args, 'limit', DEFAULT_SELECTED_LIMIT, MCP_MAX_LIMIT);
  MaxLen      := ArgInt(Args, 'max_field_length', DEFAULT_MAX_FIELD_LENGTH);
  IncludeData := ArgBool(Args, 'include_data', True);
  HasSince    := HasArg(Args, 'since_id');
  SinceId     := ArgInt(Args, 'since_id', 0);
  HasMore     := False;
  Skipped     := 0;

  Found := TList<TLogNode>.Create;
  sb := TStringBuilder.Create;
  try
    FStore.BeginRead;
    try
      Ids := FStore.SelectedIds;  // sorted ascending
      for var Id in Ids do
      begin
        if HasSince and (Id <= SinceId) then
        begin
          Inc(Skipped);
          Continue;
        end;
        Idx := FStore.IndexOfId(Id);
        if Idx < 0 then
          Continue;  // cleared meanwhile
        if Found.Count >= Limit then
        begin
          HasMore := True;
          Break;
        end;
        Found.Add(FStore.Node(Idx)^);
      end;
    finally
      FStore.EndRead;
    end;

    if Length(Ids) = 0 then
      Exit('No rows are selected in the DNetLog Server window.');

    sb.AppendFormat('Selected in window: %d logs', [Length(Ids)]);
    if Found.Count = 0 then
      sb.AppendFormat(', none with id > %d', [SinceId])
    else if HasSince or HasMore then
      sb.AppendFormat(', showing %d .. %d of them (ids %d .. %d)',
        [Skipped + 1, Skipped + Found.Count, Found.First.LogId, Found.Last.LogId]);
    sb.Append('.').AppendLine;
    if HasMore then
      sb.AppendFormat('More selected logs - call again with since_id=%d.', [Found.Last.LogId]).AppendLine;

    if Found.Count = 1 then
    begin
      sb.AppendLine;
      AppendLogFull(sb, Found.First);
    end else
    if Found.Count > 1 then
    begin
      MinTs := Cardinal.MaxValue;
      MaxTs := Cardinal.MinValue;
      for var N in Found do
      begin
        if N.LogTimestamp < MinTs then
          MinTs := N.LogTimestamp;
        if N.LogTimestamp > MaxTs then
          MaxTs := N.LogTimestamp;
      end;
      sb.Append('Client time span of shown logs: ').Append(FormatDeltaTime(MinTs, MaxTs)).AppendLine;
      sb.AppendLine;
      for var N in Found do
        sb.Append(FormatLogLine(N, MaxLen, IncludeData)).AppendLine;
    end;

    Result := sb.ToString;
  finally
    sb.Free;
    Found.Free;
  end;
end;

end.

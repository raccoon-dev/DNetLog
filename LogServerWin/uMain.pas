unit uMain;

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.ImageList,
  System.UITypes,
  System.Actions,
  System.IOUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Menus,
  Vcl.Buttons,
  Vcl.ActnList,
  Vcl.Clipbrd,
  Vcl.ExtDlgs,
  Vcl.ComCtrls,
  Vcl.Imaging.pngimage,
  Vcl.BaseImageCollection,
  Vcl.ImageCollection,
  Vcl.VirtualImageList,
  Vcl.ImgList,
  VirtualTrees,
  VirtualTrees.Types,
  VirtualTrees.BaseAncestorVCL,
  VirtualTrees.BaseTree,
  VirtualTrees.AncestorVCL,
  IdException,
  DNLog.Types,
  DNLog.Server;

type
  PLogNode = ^TLogNode;
  TLogNode = record
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
  end;

  TCLientLogMessage = record
    ClientIP: string;
    DNLogMessage: TDNLogMessage;
    constructor Create(const ClientIP: string; const DNLogMessage: TDNLogMessage);
  end;

  TOnProcessLogs = procedure(const Logs: TArray<TCLientLogMessage>) of object;

  TLogUpdateThread = class(TThread)
  private
    FLogs: TThreadList<TCLientLogMessage>;
    FOnProcessLogs: TOnProcessLogs;
    function Min(Value1, Value2: Integer): Integer; inline;
  public
    procedure Execute; override;
    property Logs: TThreadList<TCLientLogMessage> read FLogs;
    property OnProcessLogs: TOnProcessLogs read FOnProcessLogs write FOnProcessLogs;
  end;

  TfrmMain = class(TForm)
    pnlFilters: TPanel;
    vList: TVirtualStringTree;
    chkAutoScroll: TCheckBox;
    lblPriority: TLabel;
    lblClient: TLabel;
    lblTypeNr: TLabel;
    lblFilter: TLabel;
    cbPriority: TComboBox;
    cbClient: TComboBox;
    edtFilter: TEdit;
    pmnuMain: TPopupMenu;
    mClearLog: TMenuItem;
    N1: TMenuItem;
    mCopyLog: TMenuItem;
    mSaveLog: TMenuItem;
    alMain: TActionList;
    actLogClear: TAction;
    actLogCopy: TAction;
    actLogSave: TAction;
    dlgSave: TSaveTextFileDialog;
    tmrFilter: TTimer;
    btnFiltersClear: TSpeedButton;
    cbTypeNr: TComboBox;
    sbMain: TStatusBar;
    mCopyImgLog: TMenuItem;
    mSaveImgLog: TMenuItem;
    actLogImgCopy: TAction;
    actLogImgSave: TAction;
    dlgSaveImg: TSavePictureDialog;
    pnlDetails: TPanel;
    edtMessage: TEdit;
    edtData: TEdit;
    mCopyMessage: TMenuItem;
    actMessageCopy: TAction;
    vilType: TVirtualImageList;
    icType: TImageCollection;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure vListGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vListGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean;
      var ImageIndex: TImageIndex);
    procedure vListFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure pmnuMainPopup(Sender: TObject);
    procedure actLogClearExecute(Sender: TObject);
    procedure actLogCopyExecute(Sender: TObject);
    procedure actLogSaveExecute(Sender: TObject);
    procedure tmrFilterTimer(Sender: TObject);
    procedure cbPriorityCloseUp(Sender: TObject);
    procedure edtTypeNrChange(Sender: TObject);
    procedure btnFiltersClearClick(Sender: TObject);
    procedure vListAddToSelection(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure vListGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle;
      var HintText: string);
    procedure actLogImgCopyExecute(Sender: TObject);
    procedure actLogImgSaveExecute(Sender: TObject);
    procedure actMessageCopyExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    FServer: TDNLogServer;
    FLogUpdateThread: TLogUpdateThread;
    function  FillNode(const Node: PVirtualNode; const LogMessage: TCLientLogMessage): PLogNode;
    procedure OnLogReceived(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage);
    procedure LogRowToString(AData: PLogNode; StringBuilder: TStringBuilder; const ASeparator: String; const AAddNewLine: Boolean; const AGetHeader: Boolean = False);
    procedure ExportCSV(StringBuilder: TStringBuilder);
    procedure FilterLog(Priority, Client, TypeNr, Filter: string);
    function  OnFilterLog(Node: PVirtualNode; Priority, Client, TypeNr, Filter: string): Boolean;
    procedure SetNodeVisible(Node: PVirtualNode; SetVisible: Boolean);
    function  BytesToStr(Bytes: TBytes): string;
    function  GetLogBitmap: TBitmap;
    function  BitmapToPng(ABitmap: TBitmap): TPNGImage;
    procedure OnLogsProcess(const Logs: TArray<TCLientLogMessage>);
  public
    { Public declarations }
    procedure StartFilter;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uConstants;

const
  MAX_EDIT_TEXT_LENGTH = 32767;

{$R *.dfm}

procedure TfrmMain.actLogClearExecute(Sender: TObject);
begin
  FLogUpdateThread.Logs.Clear;
  vList.Clear;
  edtMessage.Text := '';
  edtData.Text    := '';
end;

procedure TfrmMain.actLogCopyExecute(Sender: TObject);
var
  Node: PVirtualNode;
  Data: PLogNode;
  enm: TVTVirtualNodeEnumeration;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try

    if vList.SelectedCount > 1 then
      enm := vList.SelectedNodes
    else
      enm := vList.Nodes;

    for Node in enm do
    begin
      Data := vList.GetNodeData(Node);
      if Assigned(Data) then
        LogRowToString(Data, sb, '    ', true);
    end;

    Clipboard.AsText := sb.ToString;

  finally
    sb.Free;
  end;
end;

procedure TfrmMain.actLogImgCopyExecute(Sender: TObject);
var
  bmp: TBitmap;
  png: TPNGImage;
  MyFormat : Word;
  AData : THandle;
  APalette : HPALETTE;
begin
  bmp := GetLogBitmap;
  if Assigned(bmp) then
    try
      png := BitmapToPng(bmp);
      if Assigned(png) then
        try
          png.SaveToClipboardFormat(MyFormat, AData, APalette);
          ClipBoard.SetAsHandle(MyFormat, AData);
        finally
          png.Free;
        end;
    finally
      bmp.Free;
    end;
end;

procedure TfrmMain.actLogImgSaveExecute(Sender: TObject);
var
  FName: string;
  bmp: TBitmap;
  png: TPNGImage;
begin
  FName := SAVE_FILE_PREFIX + FormatDateTime(SAVE_FILE_DATE, Now);
  if dlgSaveImg.FilterIndex = FILE_PNG then
    dlgSaveImg.FileName := FName + EXT_PNG
  else
  if dlgSaveImg.FilterIndex = FILE_BMP then
    dlgSaveImg.FileName := FName + EXT_BMP;

  if dlgSaveImg.Execute then
  begin
    FName := dlgSaveImg.FileName;
    bmp := GetLogBitmap;
    if Assigned(bmp) then
      try
        if dlgSaveImg.FilterIndex = FILE_PNG then
        begin
          if not TPath.GetExtension(FName).ToLower.Equals(EXT_PNG) then
            FName := FName + EXT_PNG;

          png := BitmapToPng(bmp);
          if Assigned(png) then
            try
              png.SaveToFile(FName);
            finally
              png.Free;
            end;
        end else
        if dlgSaveImg.FilterIndex = FILE_BMP then
        begin
          if not TPath.GetExtension(FName).ToLower.Equals(EXT_BMP) then
            FName := FName + EXT_BMP;
          bmp.SaveToFile(FName);
        end;
      finally
        bmp.Free;
      end;
  end;
end;

procedure TfrmMain.actLogSaveExecute(Sender: TObject);
var
  FName: string;
  sb: TStringBuilder;
  sl: TStringList;
begin
  FName := SAVE_FILE_PREFIX + FormatDateTime(SAVE_FILE_DATE, Now);
  if dlgSave.FilterIndex = FILE_CSV then
    dlgSave.FileName := FName + EXT_CSV
  else
    dlgSave.FileName := FName + EXT_TXT; // We don't support anythig except csv, but maybe someday...

  if dlgSave.Execute then
  begin
    FName := dlgSave.FileName;
    if dlgSave.FilterIndex = FILE_CSV then
    begin
      if not TPath.GetExtension(FName).ToLower.Equals(EXT_CSV) then
        FName := FName + EXT_CSV;

      sb := TStringBuilder.Create;
      sl := TStringList.Create;
      try
        ExportCSV(sb);
        sl.Text := sb.ToString;
        sl.SaveToFile(FName);
      finally
        sb.Free;
        sl.Free;
      end;
    end;
  end;
end;

procedure TfrmMain.actMessageCopyExecute(Sender: TObject);
begin
  var Node := vList.FocusedNode;
  if not Assigned(Node) then
  begin
    Clipboard.AsText := '';
    Exit;
  end;

  var Data: PLogNode := vList.GetNodeData(Node);
  Clipboard.AsText := Data.LogMessage;
end;

function TfrmMain.BitmapToPng(ABitmap: TBitmap): TPNGImage;
begin
  if Assigned(ABitmap) then
  begin
    Result := TPNGImage.Create;
    Result.Assign(ABitmap);
  end else
    Result := nil;
end;

procedure TfrmMain.btnFiltersClearClick(Sender: TObject);
begin
  cbPriority.ItemIndex := 0;
  cbClient.Text  := string.Empty;
  cbTypeNr.Text  := string.Empty;
  edtFilter.Text := string.Empty;
  StartFilter;
end;

function TfrmMain.BytesToStr(Bytes: TBytes): string;
var
  sb: TStringBuilder;
  i: Integer;
begin
  sb := TStringBuilder.Create;
  try
    for i := Low(Bytes) to High(Bytes) do
    begin
      sb.Append(IntToHex(Bytes[i] ,2));
      if i < High(Bytes) then
        sb.Append(' ');
    end;
    Result := sb.ToString;
  finally
    sb.Free;
  end;
end;

procedure TfrmMain.cbPriorityCloseUp(Sender: TObject);
begin
  StartFilter;
end;

procedure TfrmMain.edtTypeNrChange(Sender: TObject);
begin
  StartFilter;
end;

procedure TfrmMain.ExportCSV(StringBuilder: TStringBuilder);
var
  Node: PVirtualNode;
  Data: PLogNode;
  enm: TVTVirtualNodeEnumeration;
begin
  LogRowToString(nil, StringBuilder, #9, true, true);

  if vList.SelectedCount > 1 then
    enm := vList.SelectedNodes
  else
    enm := vList.Nodes;

  for Node in enm do
  begin
    Data := vList.GetNodeData(Node);
    if Assigned(Data) then
      LogRowToString(Data, StringBuilder, #9, true);
  end;
end;

function TfrmMain.FillNode(const Node: PVirtualNode;
  const LogMessage: TCLientLogMessage): PLogNode;
begin
  Result := PLogNode(vList.GetNodeData(Node));
  if not Assigned(Result) then
    Exit;

  Result.LogPriority        := LogMessage.DNLogMessage.LogPriority;
  Result.LogTimestamp       := LogMessage.DNLogMessage.LogTimestamp;
  Result.LogTimestampString := IntToStr(Result.LogTimestamp);
  Result.LogClient          := LogMessage.ClientIP;
  Result.LogTypeNr          := LogMessage.DNLogMessage.LogTypeNr;
  Result.LogTypeNrString    := IntToStr(Result.LogTypeNr);
  Result.LogMessage         := LogMessage.DNLogMessage.LogMessage;
  Result.LogMessageLC       := Result.LogMessage.ToLower;
  SetLength(Result.LogDataRaw, Length(LogMessage.DNLogMessage.LogData));
  System.Move(LogMessage.DNLogMessage.LogData[0], Result.LogDataRaw[0], Length(LogMessage.DNLogMessage.LogData));
  Result.LogData            := BytesToStr(Result.LogDataRaw);
end;

procedure TfrmMain.FilterLog(Priority, Client, TypeNr, Filter: string);
var
  Node: PVirtualNode;
begin
  vList.BeginUpdate;
  try
  for Node in vList.Nodes do
    OnFilterLog(Node, Priority, Client, TypeNr, Filter);
  finally
    vList.EndUpdate;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FLogUpdateThread := TLogUpdateThread.Create(True);
  FLogUpdateThread.FreeOnTerminate := True;
  FLogUpdateThread.OnProcessLogs := OnLogsProcess;
  FLogUpdateThread.Start;

  vList.RootNodecount := 0;
  vList.NodeDatasize  := SizeOf(TLogNode);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FServer) then
    FreeAndNil(FServer);
  FLogUpdateThread.Terminate;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  try
    FServer := TDNLogServer.Create;
    FServer.OnLogReceived := OnLogReceived;
  except
    on e: EIdCouldNotBindSocket do
    begin
      MessageDlg(Format('Can''t bind to the port %d.%sAnother log server instance is running?', [SERVER_PORT, sLineBreak]), mtError, [mbOK], 0);
      Close;
    end;
    on e: Exception do
    begin
      raise;
    end;
  end;
end;

function TfrmMain.GetLogBitmap: TBitmap;
var
  DC: HDC;
begin
  Result := TBitmap.Create;

  DC :=GetWindowDC(vList.Handle);
  Result.Width  :=vList.Width;
  Result.Height :=vList.Height;
  with Result do
    BitBlt(Canvas.Handle, 0, 0, Width, Height, DC, 0, 0, SrcCopy);

  ReleaseDC(vList.Handle, DC);
end;

procedure TfrmMain.LogRowToString(AData: PLogNode;
  StringBuilder: TStringBuilder; const ASeparator: String; const AAddNewLine,
  AGetHeader: Boolean);
begin
  if AGetHeader then
  begin
    StringBuilder.Append('Priority').Append(ASeparator)
                 .Append('Timestamp').Append(ASeparator)
                 .Append('Client').Append(ASeparator)
                 .Append('TypeNr').Append(ASeparator)
                 .Append('Message').Append(ASeparator)
                 .Append('Data');
  end else
  begin
    case AData.LogPriority of
      prDebug    : StringBuilder.Append('Debug').Append(ASeparator);
      prInfo     : StringBuilder.Append('Info').Append(ASeparator);
      prWarning  : StringBuilder.Append('Warning').Append(ASeparator);
      prError    : StringBuilder.Append('Error').Append(ASeparator);
      prException: StringBuilder.Append('Exception').Append(ASeparator);
    else
      StringBuilder.Append(string.Empty).Append(ASeparator);
    end;
    StringBuilder.Append(AData.LogTimestampString).Append(ASeparator)
                 .Append(AData.LogClient).Append(ASeparator)
                 .Append(AData.LogTypeNrString).Append(ASeparator)
                 .Append(AData.LogMessage).Append(ASeparator)
                 .Append(AData.LogData);
  end;

  if AAddNewLine then
    StringBuilder.AppendLine;
end;

procedure TfrmMain.pmnuMainPopup(Sender: TObject);
begin
  if vList.SelectedCount > 1 then
  begin
    actMessageCopy.Visible := False;
    actLogCopy.Caption     := 'Copy Selected to Clipboard';
    actLogSave.Caption     := 'Save Selected to File';
  end else
  begin
    actMessageCopy.Visible := True;
    actLogCopy.Caption     := 'Copy Logs to Clipboard';
    actLogSave.Caption     := 'Save Logs to File';
  end;
end;

procedure TfrmMain.SetNodeVisible(Node: PVirtualNode; SetVisible: Boolean);
begin
  vList.IsFiltered[Node] := not SetVisible;
end;

procedure TfrmMain.StartFilter;
begin
  if tmrFilter.Enabled then
    tmrFilter.Enabled := False;
  tmrFilter.Enabled := True;
end;

procedure TfrmMain.tmrFilterTimer(Sender: TObject);
begin
  tmrFilter.Enabled := False;

  FilterLog(cbPriority.Text, cbClient.Text, cbTypeNr.Text, edtFilter.Text);
end;

procedure TfrmMain.vListAddToSelection(Sender: TBaseVirtualTree;
  Node: PVirtualNode);
var
  n: PVirtualNode;
  d: PLogNode;
  min, max: Cardinal;
begin
  if Sender.SelectedCount > 1 then
  begin
    edtMessage.Text := '';
    edtData.Text    := '';
    sbMain.Panels[SBAR_SEL_COUNT].Text := Format('Selected %d rows', [Sender.SelectedCount]);
    min := Cardinal.MaxValue;
    max := Cardinal.MinValue;
    for n in Sender.SelectedNodes do
    begin
      d := Sender.GetNodeData(n);
      if Assigned(d) then
        if d.LogTimestamp < min then
          min := d.LogTimestamp else
        if d.LogTimestamp > max then
          max := d.LogTimestamp;
      sbMain.Panels[SBAR_SEL_TIME].Text := Format('∆ time = %d [ms]', [max - min]);
    end;
  end else
  begin
    sbMain.Panels[SBAR_SEL_COUNT].Text := string.Empty;
    sbMain.Panels[SBAR_SEL_TIME].Text := string.Empty;
    if Assigned(Node) then
    begin
      d := Sender.GetNodeData(Node);
      if Assigned(d) then
      begin
        edtMessage.Text := d.LogMessage.Substring(0, MAX_EDIT_TEXT_LENGTH);
        edtData.Text    := d.LogData.Substring(0, MAX_EDIT_TEXT_LENGTH);
      end;
    end else
    begin
      edtMessage.Text := '';
      edtData.Text    := '';
    end;
  end;
end;

procedure TfrmMain.vListFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  d: PLogNode;
begin
  d := Sender.GetNodeData(Node);
  if Assigned(d) then
    Finalize(d^);
end;

procedure TfrmMain.vListGetHint(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; var LineBreakStyle: TVTTooltipLineBreakStyle;
  var HintText: string);
var
  d: PLogNode;
begin
  if Column in [COL_MESSAGE, COL_DATA] then
  begin
    d := Sender.GetNodeData(Node);
    if Assigned(d) then
      if Column = COL_MESSAGE then
        HintText := d.LogMessage else
      if Column = COL_DATA then
        HintText := d.LogData
      else
        HintText := string.Empty;
  end else
    HintText := string.Empty;
end;

procedure TfrmMain.vListGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: TImageIndex);
var
  d: PLogNode;
begin
  if Column = COL_PRIORITY then
  begin
    d := Sender.GetNodeData(Node);
    if not Assigned(d) then
      Exit;

    if Kind in [TVTImageKind.ikNormal, TVTImageKind.ikSelected] then
      case d.LogPriority of
        prDebug    : ImageIndex := IMG_DEBUG;
        prInfo     : ImageIndex := IMG_INFO;
        prWarning  : ImageIndex := IMG_WARNING;
        prError    : ImageIndex := IMG_ERROR;
        prException: ImageIndex := IMG_EXCEPTION;
      else
        ImageIndex := IMG_EMPTY;
      end;
  end;
end;

procedure TfrmMain.vListGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  d: PLogNode;
begin
  d := Sender.GetNodeData(Node);
  if not Assigned(d) then
    Exit;

  case Column of
    COL_TIMESTAMP: CellText := d.LogTimestampString;
    COL_CLIENT:    CellText := d.LogClient;
    COL_TYPENR:    CellText := d.LogTypeNrString;
    COL_MESSAGE:   CellText := d.LogMessage;
    COL_DATA:      CellText := d.LogData;
  else
    CellText := string.Empty;
  end;
end;

function TfrmMain.OnFilterLog(Node: PVirtualNode; Priority, Client, TypeNr,
  Filter: string): Boolean;
var
  Data: PLogNode;
  bVisible: Boolean;
  Nr: Integer;
begin
  Priority := Priority.ToLower;

  Result := False;
  if ((Priority = '') or Priority.Equals('all')) and Client.IsEmpty and TypeNr.IsEmpty and Filter.IsEmpty then
    SetNodeVisible(Node, True) else
  begin
    Data := vList.GetNodeData(Node);

    if not Priority.Equals('all') then
    begin
      case Data.LogPriority of
        TDNLogPriority.prDebug    : bVisible := Priority.Equals('debug');
        TDNLogPriority.prInfo     : bVisible := Priority.Equals('info');
        TDNLogPriority.prWarning  : bVisible := Priority.Equals('warning');
        TDNLogPriority.prError    : bVisible := Priority.Equals('error');
        TDNLogPriority.prException: bVisible := Priority.Equals('exception');
      else
        bVisible := True;
      end;
      if not bVisible then
      begin
        SetNodeVisible(Node, False);
        Result := True;
        Exit;
      end;
    end;

    if not Client.IsEmpty then
      if not Data.LogClient.StartsWith(Client) then
      begin
        SetNodeVisible(Node, False);
        Result := True;
        Exit;
      end;

    if not TypeNr.IsEmpty and TryStrToInt(TypeNr, Nr) then
      if Data.LogTypeNr <> Nr then
      begin
        SetNodeVisible(Node, False);
        Result := True;
        Exit;
      end;

    if not Filter.IsEmpty then
      if not Data.LogMessageLC.Contains(Filter.ToLower) and not Data.LogData.Contains(Filter) then
      begin
        SetNodeVisible(Node, False);
        Result := True;
        Exit;
      end;

    SetNodeVisible(Node, True);
  end;
end;

procedure TfrmMain.OnLogReceived(Sender: TObject; const ClientIP: string;
  const LogMessage: TDNLogMessage);
begin
  var Queue := FLogUpdateThread.Logs.LockList;
  Queue.Add(TCLientLogMessage.Create(ClientIP, LogMessage));
  FLogUpdateThread.Logs.UnlockList;
end;

procedure TfrmMain.OnLogsProcess(const Logs: TArray<TCLientLogMessage>);
var
  Node, Nod: PVirtualNode;
  Data: PLogNode;
begin
  vList.BeginUpdate;
  try
    for var Idx := Low(Logs) to High(Logs) do
    begin
      if FLogUpdateThread.Terminated then
        Exit;

      vList.RootNodeCount := vList.RootNodeCount + 1;
      Node := vList.GetLast;
      if Assigned(Node) then
        Data := FillNode(Node, Logs[Idx])
      else
        Exit;

      if FLogUpdateThread.Terminated then
        Exit;

      if not Assigned(Data) then
        Continue;

      OnFilterLog(Node, cbPriority.Text, cbClient.Text, cbTypeNr.Text, edtFilter.Text);
      if cbClient.Items.IndexOf(Data.LogClient) < 0 then
        cbClient.Items.Append(Data.LogClient);

      if cbTypeNr.Items.IndexOf(Data.LogTypeNrString) < 0 then
        cbTypeNr.Items.Append(Data.LogTypeNrString);

      if Idx >= High(Logs) then
      begin
        if chkAutoScroll.Checked then
        begin
          vList.FocusedNode := Node;
          for Nod in vList.SelectedNodes do
            vList.Selected[Nod] := False;
          vList.Selected[Node] := True;
          vList.ScrollIntoView(Node, false);
        end;
      end;

    end;
  finally
    vList.EndUpdate;
  end;
end;

{ TLogUpdateThread }

procedure TLogUpdateThread.Execute;
begin
  inherited;
  FLogs := TThreadList<TCLientLogMessage>.Create;
  try

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
        FLogs.UnlockList;
    end;

  finally
    FLogs.Free;
  end;
end;

function TLogUpdateThread.Min(Value1, Value2: Integer): Integer;
begin
  if Value1 < Value2 then
    Result := Value1
  else
    Result := Value2;
end;

{ TCLientLogMessage }

constructor TCLientLogMessage.Create(const ClientIP: string;
  const DNLogMessage: TDNLogMessage);
begin
  Self.ClientIP := ClientIP;
  Self.DNLogMessage := DNLogMessage;
end;

end.

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
  uLogStats,
  uLogCommon,
  DNLog.Types,
  DNLog.Server;

type
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
    pnlStats: TPanel;
    lblStatsTitle: TLabel;
    lblStatsTotal: TLabel;
    lblStatsDebug: TLabel;
    lblStatsInfo: TLabel;
    lblStatsWarning: TLabel;
    lblStatsError: TLabel;
    lblStatsException: TLabel;
    lblStatsThroughput: TLabel;
    lblStatsClientsHdr: TLabel;
    lblStatsClients: TLabel;
    lblStatsTypesHdr: TLabel;
    lblStatsTypes: TLabel;
    tmrThroughput: TTimer;
    procedure tmrThroughputTimer(Sender: TObject);
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
    FSelectionTimer: TTimer;
    FStats: TLogStats;
    procedure UpdateStatsDisplay;
    procedure SelectionTimerTimer(Sender: TObject);
    function  FillNode(const Node: PVirtualNode; const LogMessage: TCLientLogMessage): PLogNode;
    procedure OnLogReceived(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage);
    procedure ExportCSV(StringBuilder: TStringBuilder);
    procedure FilterLog(Priority, Client, TypeNr, Filter: string);
    procedure ApplyNodeFilter(Node: PVirtualNode; const Filter: TLogFilter);
    procedure SetNodeVisible(Node: PVirtualNode; SetVisible: Boolean);
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
  cbClient.Items.Clear;
  cbTypeNr.Items.Clear;
  edtMessage.Text := '';
  edtData.Text    := '';
  FStats.Clear;
  UpdateStatsDisplay;
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
        AppendLogRow(sb, Data^, '    ');
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
  if dlgSaveImg.FilterIndex = IMAGE_FILE_PNG then
    dlgSaveImg.FileName := FName + EXT_PNG
  else
  if dlgSaveImg.FilterIndex = IMAGE_FILE_BMP then
    dlgSaveImg.FileName := FName + EXT_BMP;

  if dlgSaveImg.Execute then
  begin
    FName := dlgSaveImg.FileName;
    bmp := GetLogBitmap;
    if Assigned(bmp) then
      try
        if dlgSaveImg.FilterIndex = IMAGE_FILE_PNG then
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
        if dlgSaveImg.FilterIndex = IMAGE_FILE_BMP then
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
  if dlgSave.FilterIndex = TEXT_FILE_CSV then
    dlgSave.FileName := FName + EXT_CSV
  else
    dlgSave.FileName := FName + EXT_TXT; // We don't support anythig except csv, but maybe someday...

  if dlgSave.Execute then
  begin
    FName := dlgSave.FileName;
    if dlgSave.FilterIndex = TEXT_FILE_CSV then
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
  AppendLogHeader(StringBuilder, #9);

  if vList.SelectedCount > 1 then
    enm := vList.SelectedNodes
  else
    enm := vList.Nodes;

  for Node in enm do
  begin
    Data := vList.GetNodeData(Node);
    if Assigned(Data) then
      AppendLogRow(StringBuilder, Data^, #9);
  end;
end;

function TfrmMain.FillNode(const Node: PVirtualNode;
  const LogMessage: TCLientLogMessage): PLogNode;
begin
  Result := PLogNode(vList.GetNodeData(Node));
  if not Assigned(Result) then
    Exit;

  FillLogNode(Result^, LogMessage);
end;

procedure TfrmMain.FilterLog(Priority, Client, TypeNr, Filter: string);
var
  Node: PVirtualNode;
  LogFilter: TLogFilter;
begin
  LogFilter := TLogFilter.Create(Priority, Client, TypeNr, Filter);
  vList.BeginUpdate;
  try
    for Node in vList.Nodes do
      ApplyNodeFilter(Node, LogFilter);
  finally
    vList.EndUpdate;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  FLogUpdateThread := TLogUpdateThread.Create(True);
  FLogUpdateThread.FreeOnTerminate := False;
  FLogUpdateThread.OnProcessLogs := OnLogsProcess;
  FLogUpdateThread.Start;

  FSelectionTimer := TTimer.Create(Self);
  FSelectionTimer.Enabled := False;
  FSelectionTimer.Interval := 100;
  FSelectionTimer.OnTimer := SelectionTimerTimer;

  FStats := TLogStats.Create;

  vList.RootNodecount := 0;
  vList.NodeDatasize  := SizeOf(TLogNode);

  UpdateStatsDisplay;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FServer) then
    FreeAndNil(FServer);
  FLogUpdateThread.Terminate;
  FLogUpdateThread.WaitFor;
  FreeAndNil(FLogUpdateThread);
  FreeAndNil(FStats);
end;

procedure TfrmMain.UpdateStatsDisplay;
begin
  lblStatsTotal.Caption := Format('Total: %d', [FStats.Total]);
  lblStatsDebug.Caption := Format('Debug: %d', [FStats.Debug]);
  lblStatsInfo.Caption := Format('Info: %d', [FStats.Info]);
  lblStatsWarning.Caption := Format('Warning: %d', [FStats.Warning]);
  lblStatsError.Caption := Format('Error: %d', [FStats.Error]);
  lblStatsException.Caption := Format('Exception: %d', [FStats.Exception]);
  lblStatsClients.Caption := FStats.GetClientsText;
  lblStatsTypes.Caption := FStats.GetTypesText;

  // Update throughput during processing
  FStats.UpdateThroughput;
  lblStatsThroughput.Caption := Format('%.0f logs/s', [FStats.GetThroughput]);
end;

procedure TfrmMain.tmrThroughputTimer(Sender: TObject);
begin
  FStats.UpdateThroughput;
  lblStatsThroughput.Caption := Format('%.0f logs/s', [FStats.GetThroughput]);
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  // OnShow can fire more than once (e.g. after the window is re-created) -
  // creating a second server would fail to bind the port and close the app.
  if Assigned(FServer) then
    Exit;
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
  d: PLogNode;
begin
  if Sender.SelectedCount > 1 then
  begin
    // Multiple selection - update count immediately, defer time calculation
    edtMessage.Text := '';
    edtData.Text    := '';
    sbMain.Panels[SBAR_SEL_COUNT].Text := Format('Selected %d rows', [Sender.SelectedCount]);
    sbMain.Panels[SBAR_SEL_TIME].Text := 'Calculating...';
    // Reset timer to calculate delta time after selection is complete
    FSelectionTimer.Enabled := False;
    FSelectionTimer.Enabled := True;
  end else
  begin
    // Single selection - show details immediately
    FSelectionTimer.Enabled := False;
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

procedure TfrmMain.SelectionTimerTimer(Sender: TObject);
var
  n: PVirtualNode;
  d: PLogNode;
  min, max: Cardinal;
begin
  FSelectionTimer.Enabled := False;

  if vList.SelectedCount <= 1 then
    Exit;

  min := Cardinal.MaxValue;
  max := Cardinal.MinValue;
  for n in vList.SelectedNodes do
  begin
    d := vList.GetNodeData(n);
    if Assigned(d) then
    begin
      if d.LogTimestamp < min then
        min := d.LogTimestamp;
      if d.LogTimestamp > max then
        max := d.LogTimestamp;
    end;
  end;
  sbMain.Panels[SBAR_SEL_TIME].Text := FormatDeltaTime(min, max);
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

procedure TfrmMain.ApplyNodeFilter(Node: PVirtualNode; const Filter: TLogFilter);
var
  Data: PLogNode;
begin
  Data := vList.GetNodeData(Node);
  if Assigned(Data) then
    SetNodeVisible(Node, Filter.Matches(Data^));
end;

procedure TfrmMain.OnLogReceived(Sender: TObject; const ClientIP: string;
  const LogMessage: TDNLogMessage);
begin
  FLogUpdateThread.AddLog(ClientIP, LogMessage);
end;

procedure TfrmMain.OnLogsProcess(const Logs: TArray<TCLientLogMessage>);
var
  Node, Nod, LastNode, LastOldNode: PVirtualNode;
  Data: PLogNode;
  LogFilter: TLogFilter;
  ClientSet, TypeNrSet: TDictionary<string, Boolean>;
  WasAtBottom: Boolean;
begin
  if Length(Logs) = 0 then
    Exit;

  // Prepare filter once for the whole batch
  LogFilter := TLogFilter.Create(cbPriority.Text, cbClient.Text, cbTypeNr.Text, edtFilter.Text);

  // Build sets of existing clients/types for O(1) lookup
  ClientSet := TDictionary<string, Boolean>.Create;
  TypeNrSet := TDictionary<string, Boolean>.Create;
  try
    for var i := 0 to cbClient.Items.Count - 1 do
      ClientSet.AddOrSetValue(cbClient.Items[i], True);
    for var i := 0 to cbTypeNr.Items.Count - 1 do
      TypeNrSet.AddOrSetValue(cbTypeNr.Items[i], True);

    // Remember last node before adding new ones (O(1) way to find first new node)
    LastOldNode := vList.GetLast;

    // Check if user was at bottom (for auto-scroll decision)
    WasAtBottom := (LastOldNode = nil) or (vList.BottomNode = LastOldNode);

    vList.BeginUpdate;
    try

      // Add all nodes at once
      vList.RootNodeCount := vList.RootNodeCount + Cardinal(Length(Logs));

      // Get first new node in O(1)
      if Assigned(LastOldNode) then
        Node := vList.GetNextSibling(LastOldNode)
      else
        Node := vList.GetFirst;

      LastNode := nil;
      for var Idx := Low(Logs) to High(Logs) do
      begin
        if FLogUpdateThread.Terminated or not Assigned(Node) then
          Exit;

        Data := FillNode(Node, Logs[Idx]);
        if Assigned(Data) then
        begin
          FStats.AddLog(Data.LogPriority, Data.LogClient, Data.LogTypeNr);
          SetNodeVisible(Node, LogFilter.Matches(Data^));

          if not ClientSet.ContainsKey(Data.LogClient) then
          begin
            ClientSet.Add(Data.LogClient, True);
            cbClient.Items.Append(Data.LogClient);
          end;

          if not TypeNrSet.ContainsKey(Data.LogTypeNrString) then
          begin
            TypeNrSet.Add(Data.LogTypeNrString, True);
            cbTypeNr.Items.Append(Data.LogTypeNrString);
          end;
        end;

        LastNode := Node;
        Node := vList.GetNextSibling(Node);
      end;

      // Auto-scroll only if checkbox is checked AND user was at bottom
      if chkAutoScroll.Checked and WasAtBottom and Assigned(LastNode) then
      begin
        vList.FocusedNode := LastNode;
        for Nod in vList.SelectedNodes do
          vList.Selected[Nod] := False;
        vList.Selected[LastNode] := True;
        vList.ScrollIntoView(LastNode, False);
      end;

    finally
      vList.EndUpdate;
    end;

    UpdateStatsDisplay;
  finally
    ClientSet.Free;
    TypeNrSet.Free;
  end;
end;

end.

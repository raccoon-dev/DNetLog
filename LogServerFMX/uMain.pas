unit uMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Rtti,
  System.IOUtils,
  System.ImageList,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.DialogService,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.ComboEdit,
  FMX.ListBox,
  FMX.Layouts,
  FMX.Menus,
  FMX.ImgList,
  FMX.Platform,
  IdException,
  uLogStats,
  uLogCommon,
  uLogView,
  DNLog.Types,
  DNLog.Server;

type
  TfrmMain = class(TForm)
    pnlFilters: TPanel;
    layPriority: TLayout;
    lblPriority: TLabel;
    cbPriority: TComboBox;
    layClient: TLayout;
    lblClient: TLabel;
    cbClient: TComboEdit;
    layTypeNr: TLayout;
    lblTypeNr: TLabel;
    cbTypeNr: TComboEdit;
    layFilter: TLayout;
    layFilterHeader: TLayout;
    lblFilter: TLabel;
    chkAutoScroll: TCheckBox;
    layFilterEdit: TLayout;
    edtFilter: TEdit;
    btnFiltersClear: TSpeedButton;
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
    layBottom: TLayout;
    edtMessage: TEdit;
    edtData: TEdit;
    sbMain: TStatusBar;
    lblSelCount: TLabel;
    lblSelTime: TLabel;
    pmnuMain: TPopupMenu;
    mClearLog: TMenuItem;
    N1: TMenuItem;
    mCopyMessage: TMenuItem;
    mCopyLog: TMenuItem;
    mSaveLog: TMenuItem;
    mCopyImgLog: TMenuItem;
    mSaveImgLog: TMenuItem;
    dlgSave: TSaveDialog;
    dlgSaveImg: TSaveDialog;
    tmrFilter: TTimer;
    tmrThroughput: TTimer;
    ilType: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tmrThroughputTimer(Sender: TObject);
    procedure tmrFilterTimer(Sender: TObject);
    procedure cbPriorityChange(Sender: TObject);
    procedure edtFilterChange(Sender: TObject);
    procedure btnFiltersClearClick(Sender: TObject);
    procedure pmnuMainPopup(Sender: TObject);
    procedure actLogClearExecute(Sender: TObject);
    procedure actMessageCopyExecute(Sender: TObject);
    procedure actLogCopyExecute(Sender: TObject);
    procedure actLogSaveExecute(Sender: TObject);
    procedure actLogImgCopyExecute(Sender: TObject);
    procedure actLogImgSaveExecute(Sender: TObject);
  private
    vList: TLogView;
    FServer: TDNLogServer;
    FLogUpdateThread: TLogUpdateThread;
    FSelectionTimer: TTimer;
    FStats: TLogStats;
    procedure CreateLogView;
    procedure UpdateStatsDisplay;
    procedure SelectionTimerTimer(Sender: TObject);
    procedure vListSelectionChange(Sender: TObject);
    procedure OnLogReceived(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage);
    procedure OnLogsProcess(const Logs: TArray<TCLientLogMessage>);
    procedure ForEachExportNode(const Proc: TLogNodeProc);
    procedure ExportCSV(StringBuilder: TStringBuilder);
    function  BuildFilter: TLogFilter;
    function  GetLogBitmap: TBitmap;
    procedure SetClipboardValue(const Value: TValue);
  public
    procedure StartFilter;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uConstants;

const
  MAX_EDIT_TEXT_LENGTH = 32767;

{$R *.fmx}

{ TfrmMain }

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

  for var lbl in TArray<TLabel>.Create(lblStatsTitle, lblStatsClientsHdr, lblStatsTypesHdr) do
  begin
    lbl.StyledSettings := lbl.StyledSettings - [TStyledSetting.Style];
    lbl.TextSettings.Font.Style := [TFontStyle.fsBold];
  end;

  CreateLogView;
  UpdateStatsDisplay;
end;

procedure TfrmMain.CreateLogView;
begin
  vList := TLogView.Create(Self);
  vList.Align := TAlignLayout.Client;
  vList.Images := ilType;
  vList.PopupMenu := pmnuMain;
  vList.OnSelectionChange := vListSelectionChange;

  // Colors matching the Win10ModernSlateGray FMX style and the VCL vList colors
  vList.ColorBackground         := $FF4B5A62;
  vList.ColorAlternate          := $FF53646D;
  vList.ColorText               := TAlphaColors.White;
  vList.ColorSelection          := $FF7DACA8;
  vList.ColorSelectionUnfocused := $FF37474F;
  vList.ColorSelectionText      := TAlphaColors.White;
  vList.ColorGridLine           := $FF37474F;
  vList.ColorHeader             := $FF37474F;
  vList.ColorHeaderText         := TAlphaColors.White;
  vList.ColorBorder             := $FF263238;
  vList.Font.Size := 13;

  vList.PriorityImages[prDebug]     := IMG_DEBUG;
  vList.PriorityImages[prInfo]      := IMG_INFO;
  vList.PriorityImages[prWarning]   := IMG_WARNING;
  vList.PriorityImages[prError]     := IMG_ERROR;
  vList.PriorityImages[prException] := IMG_EXCEPTION;

  // Same order as COL_* constants
  vList.AddColumn('',            lfPriority,   32,  32,  32, TTextAlign.Center,  False, False);
  vList.AddColumn('Timestamp',   lfTimestamp, 100, 100, 150, TTextAlign.Center);
  vList.AddColumn('Client',      lfClient,    120, 120, 200, TTextAlign.Center);
  vList.AddColumn('Type Nr',     lfTypeNr,     64,  64, 120, TTextAlign.Center);
  vList.AddColumn('Message',     lfMessage,   200, 200,   0, TTextAlign.Leading, True,  True, True);
  vList.AddColumn('Binary Data', lfData,      200,  64,   0, TTextAlign.Leading, False, True, True);

  vList.Parent := Self;
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

procedure TfrmMain.FormShow(Sender: TObject);
begin
  // OnShow can fire more than once - creating a second server would fail to
  // bind the port and close the app.
  if Assigned(FServer) then
    Exit;
  try
    FServer := TDNLogServer.Create;
    FServer.OnLogReceived := OnLogReceived;
  except
    on e: EIdCouldNotBindSocket do
    begin
      TDialogService.MessageDialog(
        Format('Can''t bind to the port %d.%sAnother log server instance is running?', [SERVER_PORT, sLineBreak]),
        TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0,
        procedure(const AResult: TModalResult)
        begin
          TThread.ForceQueue(nil, procedure
          begin
            Close;
          end);
        end);
    end;
  end;
end;

{ --- statistics ------------------------------------------------------------ }

procedure TfrmMain.UpdateStatsDisplay;
begin
  lblStatsTotal.Text     := Format('Total: %d', [FStats.Total]);
  lblStatsDebug.Text     := Format('Debug: %d', [FStats.Debug]);
  lblStatsInfo.Text      := Format('Info: %d', [FStats.Info]);
  lblStatsWarning.Text   := Format('Warning: %d', [FStats.Warning]);
  lblStatsError.Text     := Format('Error: %d', [FStats.Error]);
  lblStatsException.Text := Format('Exception: %d', [FStats.Exception]);
  lblStatsClients.Text   := FStats.GetClientsText;
  lblStatsTypes.Text     := FStats.GetTypesText;

  FStats.UpdateThroughput;
  lblStatsThroughput.Text := Format('%.0f logs/s', [FStats.GetThroughput]);
end;

procedure TfrmMain.tmrThroughputTimer(Sender: TObject);
begin
  FStats.UpdateThroughput;
  lblStatsThroughput.Text := Format('%.0f logs/s', [FStats.GetThroughput]);
end;

{ --- filtering ------------------------------------------------------------- }

procedure TfrmMain.StartFilter;
begin
  if tmrFilter.Enabled then
    tmrFilter.Enabled := False;
  tmrFilter.Enabled := True;
end;

procedure TfrmMain.tmrFilterTimer(Sender: TObject);
begin
  tmrFilter.Enabled := False;
  var Filter := BuildFilter;
  vList.ApplyFilter(
    function(const Node: TLogNode): Boolean
    begin
      Result := Filter.Matches(Node);
    end);
end;

procedure TfrmMain.cbPriorityChange(Sender: TObject);
begin
  StartFilter;
end;

procedure TfrmMain.edtFilterChange(Sender: TObject);
begin
  StartFilter;
end;

procedure TfrmMain.btnFiltersClearClick(Sender: TObject);
begin
  cbPriority.ItemIndex := 0;
  cbClient.Text  := string.Empty;
  cbTypeNr.Text  := string.Empty;
  edtFilter.Text := string.Empty;
  StartFilter;
end;

function TfrmMain.BuildFilter: TLogFilter;
var
  Priority: string;
begin
  if cbPriority.ItemIndex >= 0 then
    Priority := cbPriority.Items[cbPriority.ItemIndex]
  else
    Priority := string.Empty;
  Result := TLogFilter.Create(Priority, cbClient.Text, cbTypeNr.Text, edtFilter.Text);
end;

{ --- receiving logs -------------------------------------------------------- }

procedure TfrmMain.OnLogReceived(Sender: TObject; const ClientIP: string;
  const LogMessage: TDNLogMessage);
begin
  FLogUpdateThread.AddLog(ClientIP, LogMessage);
end;

procedure TfrmMain.OnLogsProcess(const Logs: TArray<TCLientLogMessage>);
var
  Node: TLogNode;
  Filter: TLogFilter;
  ClientSet, TypeNrSet: TDictionary<string, Boolean>;
  WasAtBottom: Boolean;
begin
  if Length(Logs) = 0 then
    Exit;

  Filter := BuildFilter;

  // Sets of existing clients/types for O(1) lookup
  ClientSet := TDictionary<string, Boolean>.Create;
  TypeNrSet := TDictionary<string, Boolean>.Create;
  try
    for var i := 0 to cbClient.Items.Count - 1 do
      ClientSet.AddOrSetValue(cbClient.Items[i], True);
    for var i := 0 to cbTypeNr.Items.Count - 1 do
      TypeNrSet.AddOrSetValue(cbTypeNr.Items[i], True);

    // Was the user at the bottom of the list (for auto-scroll decision)
    WasAtBottom := vList.IsAtBottom;

    vList.BeginUpdate;
    try
      for var Idx := Low(Logs) to High(Logs) do
      begin
        if FLogUpdateThread.Terminated then
          Break;

        FillLogNode(Node, Logs[Idx]);
        FStats.AddLog(Node.LogPriority, Node.LogClient, Node.LogTypeNr);
        vList.AddNode(Node, Filter.Matches(Node));

        if not ClientSet.ContainsKey(Node.LogClient) then
        begin
          ClientSet.Add(Node.LogClient, True);
          cbClient.Items.Add(Node.LogClient);
        end;

        if not TypeNrSet.ContainsKey(Node.LogTypeNrString) then
        begin
          TypeNrSet.Add(Node.LogTypeNrString, True);
          cbTypeNr.Items.Add(Node.LogTypeNrString);
        end;
      end;

      // Auto-scroll only if checkbox is checked AND user was at bottom
      if chkAutoScroll.IsChecked and WasAtBottom then
        vList.SelectLastRow;
    finally
      vList.EndUpdate;
    end;

    UpdateStatsDisplay;
  finally
    ClientSet.Free;
    TypeNrSet.Free;
  end;
end;

{ --- selection ------------------------------------------------------------- }

procedure TfrmMain.vListSelectionChange(Sender: TObject);
var
  d: PLogNode;
  SelNode: TLogNode;
  Found: Boolean;
begin
  if vList.SelectedCount > 1 then
  begin
    // Multiple selection - update count immediately, defer time calculation
    edtMessage.Text := '';
    edtData.Text    := '';
    lblSelCount.Text := Format('Selected %d rows', [vList.SelectedCount]);
    lblSelTime.Text  := 'Calculating...';
    FSelectionTimer.Enabled := False;
    FSelectionTimer.Enabled := True;
    Exit;
  end;

  FSelectionTimer.Enabled := False;
  lblSelCount.Text := string.Empty;
  lblSelTime.Text  := string.Empty;

  Found := False;
  if vList.SelectedCount = 1 then
  begin
    d := vList.FocusedNode;
    if Assigned(d) and d.Selected then
    begin
      SelNode := d^;
      Found := True;
    end else
    begin
      vList.ForEachSelected(
        procedure(const Node: TLogNode)
        begin
          SelNode := Node;
        end);
      Found := True;
    end;
  end;

  if Found then
  begin
    edtMessage.Text := SelNode.LogMessage.Substring(0, MAX_EDIT_TEXT_LENGTH);
    edtData.Text    := SelNode.LogData.Substring(0, MAX_EDIT_TEXT_LENGTH);
  end else
  begin
    edtMessage.Text := '';
    edtData.Text    := '';
  end;
end;

procedure TfrmMain.SelectionTimerTimer(Sender: TObject);
var
  min, max: Cardinal;
begin
  FSelectionTimer.Enabled := False;

  if vList.SelectedCount <= 1 then
    Exit;

  min := Cardinal.MaxValue;
  max := Cardinal.MinValue;
  vList.ForEachSelected(
    procedure(const Node: TLogNode)
    begin
      if Node.LogTimestamp < min then
        min := Node.LogTimestamp;
      if Node.LogTimestamp > max then
        max := Node.LogTimestamp;
    end);
  lblSelTime.Text := FormatDeltaTime(min, max);
end;

{ --- popup menu / export --------------------------------------------------- }

procedure TfrmMain.pmnuMainPopup(Sender: TObject);
begin
  if vList.SelectedCount > 1 then
  begin
    mCopyMessage.Visible := False;
    mCopyLog.Text        := 'Copy Selected to Clipboard';
    mSaveLog.Text        := 'Save Selected to File';
  end else
  begin
    mCopyMessage.Visible := True;
    mCopyLog.Text        := 'Copy Logs to Clipboard';
    mSaveLog.Text        := 'Save Logs to File';
  end;
end;

procedure TfrmMain.actLogClearExecute(Sender: TObject);
begin
  FLogUpdateThread.Logs.Clear;
  vList.Clear;
  cbClient.Items.Clear;
  cbTypeNr.Items.Clear;
  edtMessage.Text := '';
  edtData.Text    := '';
  lblSelCount.Text := '';
  lblSelTime.Text  := '';
  FStats.Clear;
  UpdateStatsDisplay;
end;

procedure TfrmMain.SetClipboardValue(const Value: TValue);
var
  Svc: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Svc.SetClipboard(Value);
end;

procedure TfrmMain.actMessageCopyExecute(Sender: TObject);
var
  d: PLogNode;
begin
  d := vList.FocusedNode;
  if Assigned(d) then
    SetClipboardValue(d.LogMessage)
  else
    SetClipboardValue(string.Empty);
end;

// Selected nodes if more than one is selected, otherwise all visible nodes.
procedure TfrmMain.ForEachExportNode(const Proc: TLogNodeProc);
begin
  if vList.SelectedCount > 1 then
    vList.ForEachSelected(Proc)
  else
    vList.ForEachVisible(Proc);
end;

procedure TfrmMain.actLogCopyExecute(Sender: TObject);
var
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    ForEachExportNode(
      procedure(const Node: TLogNode)
      begin
        AppendLogRow(sb, Node, '    ');
      end);
    SetClipboardValue(sb.ToString);
  finally
    sb.Free;
  end;
end;

procedure TfrmMain.ExportCSV(StringBuilder: TStringBuilder);
begin
  AppendLogHeader(StringBuilder, #9);
  ForEachExportNode(
    procedure(const Node: TLogNode)
    begin
      AppendLogRow(StringBuilder, Node, #9);
    end);
end;

procedure TfrmMain.actLogSaveExecute(Sender: TObject);
var
  FName: string;
  sb: TStringBuilder;
begin
  FName := SAVE_FILE_PREFIX + FormatDateTime(SAVE_FILE_DATE, Now);
  if dlgSave.FilterIndex = TEXT_FILE_CSV then
    dlgSave.FileName := FName + EXT_CSV
  else
    dlgSave.FileName := FName + EXT_TXT;

  if not dlgSave.Execute then
    Exit;

  FName := dlgSave.FileName;
  if dlgSave.FilterIndex = TEXT_FILE_CSV then
  begin
    if not TPath.GetExtension(FName).ToLower.Equals(EXT_CSV) then
      FName := FName + EXT_CSV;

    sb := TStringBuilder.Create;
    try
      ExportCSV(sb);
      TFile.WriteAllText(FName, sb.ToString, TEncoding.UTF8);
    finally
      sb.Free;
    end;
  end;
end;

function TfrmMain.GetLogBitmap: TBitmap;
begin
  Result := vList.MakeScreenshot;
end;

procedure TfrmMain.actLogImgCopyExecute(Sender: TObject);
var
  bmp: TBitmap;
begin
  bmp := GetLogBitmap;
  if Assigned(bmp) then
    try
      SetClipboardValue(TValue.From<TBitmap>(bmp));
    finally
      bmp.Free;
    end;
end;

procedure TfrmMain.actLogImgSaveExecute(Sender: TObject);
var
  FName, Ext: string;
  bmp: TBitmap;
begin
  FName := SAVE_FILE_PREFIX + FormatDateTime(SAVE_FILE_DATE, Now);
  if dlgSaveImg.FilterIndex = IMAGE_FILE_BMP then
    dlgSaveImg.FileName := FName + EXT_BMP
  else
    dlgSaveImg.FileName := FName + EXT_PNG;

  if not dlgSaveImg.Execute then
    Exit;

  if dlgSaveImg.FilterIndex = IMAGE_FILE_BMP then
    Ext := EXT_BMP
  else
    Ext := EXT_PNG;

  FName := dlgSaveImg.FileName;
  if not TPath.GetExtension(FName).ToLower.Equals(Ext) then
    FName := FName + Ext;

  bmp := GetLogBitmap;
  if Assigned(bmp) then
    try
      // FMX picks the codec by file extension
      bmp.SaveToFile(FName);
    finally
      bmp.Free;
    end;
end;

end.

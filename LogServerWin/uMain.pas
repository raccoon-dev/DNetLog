unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, VirtualTrees, Vcl.ExtCtrls,
  System.ImageList, Vcl.ImgList, DNLog.Types, DNLog.Server, System.UITypes,
  Vcl.StdCtrls, Vcl.Menus, Vcl.Buttons, System.Actions, Vcl.ActnList, Vcl.Clipbrd,
  Vcl.ExtDlgs, System.IOUtils, Vcl.ComCtrls;

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

type
  TfrmMain = class(TForm)
    pnlFilters: TPanel;
    vList: TVirtualStringTree;
    ilType: TImageList;
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
  private
    { Private declarations }
    FServer: TDNLogServer;
    procedure _OnLogReceived(Sender: TObject; const ClientIP: string; const LogMessage: TDNLogMessage);
    procedure LogRowToString(AData: PLogNode; StringBuilder: TStringBuilder; const ASeparator: String; const AAddNewLine: Boolean; const AGetHeader: Boolean = False);
    procedure ExportCSV(StringBuilder: TStringBuilder);
    procedure FilterLog(Priority, Client, TypeNr, Filter: string);
    function _FilterLog(Node: PVirtualNode; Priority, Client, TypeNr, Filter: string): Boolean;
    procedure SetNodeVisible(Node: PVirtualNode; SetVisible: Boolean);
    function  BytesToStr(Bytes: TBytes): string;
  public
    { Public declarations }
    procedure StartFilter;
  end;

var
  frmMain: TfrmMain;

implementation

const
  COL_PRIORITY  = 0;
  COL_TIMESTAMP = 1;
  COL_CLIENT    = 2;
  COL_TYPENR    = 3;
  COL_MESSAGE   = 4;
  COL_DATA      = 5;

  IMG_EMPTY   = -1;
  IMG_DEBUG   = 0;
  IMG_INFO    = 1;
  IMG_WARNING = 2;
  IMG_ERROR   = 3;

  FILE_CSV = 1;

  SBAR_SEL_COUNT = 0;
  SBAR_SEL_TIME = 1;

{$R *.dfm}

procedure TfrmMain.actLogClearExecute(Sender: TObject);
begin
  vList.BeginUpdate;
  try
    vList.Clear;
  finally
    vList.EndUpdate;
  end;
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

procedure TfrmMain.actLogSaveExecute(Sender: TObject);
var
  FName: string;
  sb: TStringBuilder;
  sl: TStringList;
begin
  if dlgSave.Execute then
  begin
    FName := dlgSave.FileName;
    if dlgSave.FilterIndex = FILE_CSV then
    begin
      if not TPath.GetExtension(FName).ToLower.Equals('.csv') then
        FName := FName + '.csv';

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

procedure TfrmMain.FilterLog(Priority, Client, TypeNr, Filter: string);
var
  Node: PVirtualNode;
begin
  vList.BeginUpdate;
  try
  for Node in vList.Nodes do
    _FilterLog(Node, Priority, Client, TypeNr, Filter);
  finally
    vList.EndUpdate;
  end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  vList.RootNodecount := 0;
  vList.NodeDatasize  := SizeOf(TLogNode);

  FServer := TDNLogServer.Create;
  FServer.OnLogReceived := _OnLogReceived;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FServer.Free;
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
      prDebug:   StringBuilder.Append('Debug').Append(ASeparator);
      prInfo:    StringBuilder.Append('Info').Append(ASeparator);
      prWarning: StringBuilder.Append('Warning').Append(ASeparator);
      prError:   StringBuilder.Append('Error').Append(ASeparator);
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
    actLogCopy.Caption := 'Copy Selected to Clipboard';
    actLogSave.Caption := 'Save Selected to File';
  end else
  begin
    actLogCopy.Caption := 'Copy Logs to Clipboard';
    actLogSave.Caption := 'Save Logs to File';
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
  end;
end;

procedure TfrmMain.vListFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  d: PLogNode;
begin
  d := Sender.GetNodeData(Node);
  if Assigned(d) then
  begin
    d.LogTimestampString := string.Empty;
    d.LogClient          := string.Empty;
    d.LogTypeNrString    := string.Empty;
    d.LogMessage         := string.Empty;
    d.LogMessageLC       := string.Empty;
    d.LogData            := string.Empty;
    SetLength(d.LogDataRaw, 0);
  end;
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
        prDebug:   ImageIndex := IMG_DEBUG;
        prInfo:    ImageIndex := IMG_INFO;
        prWarning: ImageIndex := IMG_WARNING;
        prError:   ImageIndex := IMG_ERROR;
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

function TfrmMain._FilterLog(Node: PVirtualNode; Priority, Client, TypeNr,
  Filter: string): Boolean;
var
  Data: PLogNode;
  bVisible: Boolean;
  Nr: Integer;
begin
  Priority := Priority.ToLower;

  Result := False;
  if Priority.Equals('all') and Client.IsEmpty and TypeNr.IsEmpty and Filter.IsEmpty then
    SetNodeVisible(Node, True) else
  begin
    Data := vList.GetNodeData(Node);

    if not Priority.Equals('all') then
    begin
      case Data.LogPriority of
        TDNLogPriority.prDebug:   bVisible := Priority.Equals('debug');
        TDNLogPriority.prInfo:    bVisible := Priority.Equals('info');
        TDNLogPriority.prWarning: bVisible := Priority.Equals('warning');
        TDNLogPriority.prError:   bVisible := Priority.Equals('error');
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

procedure TfrmMain._OnLogReceived(Sender: TObject; const ClientIP: string;
  const LogMessage: TDNLogMessage);
var
  Node, Nod: PVirtualNode;
  Data: PLogNode;
begin
  vList.BeginUpdate;
  try
    vList.RootNodeCount := vList.RootNodeCount + 1;
    Node := vList.GetLast;
    if Assigned(Node) then
    begin
      Data := vList.GetNodeData(Node);
      if Assigned(Data) then
      begin
        Data.LogPriority        := LogMessage.LogPriority;
        Data.LogTimestamp       := LogMessage.LogTimestamp;
        Data.LogTimestampString := IntToStr(Data.LogTimestamp);
        Data.LogClient          := ClientIP;
        Data.LogTypeNr          := LogMessage.LogTypeNr;
        Data.LogTypeNrString    := IntToStr(Data.LogTypeNr);
        Data.LogMessage         := LogMessage.LogMessage;
        Data.LogMessageLC       := Data.LogMessage.ToLower;
        SetLength(Data.LogDataRaw, Length(LogMessage.LogData));
        System.Move(LogMessage.LogData[0], Data.LogDataRaw[0], Length(LogMessage.LogData));
        Data.LogData            := BytesToStr(Data.LogDataRaw);
      end else
        Exit;
    end else
      Exit;

    if cbClient.Items.IndexOf(Data.LogClient) < 0 then
      cbClient.Items.Append(Data.LogClient);

    if cbTypeNr.Items.IndexOf(Data.LogTypeNrString) < 0 then
      cbTypeNr.Items.Append(Data.LogTypeNrString);

    if not _FilterLog(Node, cbPriority.Text, cbClient.Text, cbTypeNr.Text, edtFilter.Text) then
      if chkAutoScroll.Checked then
      begin
        vList.FocusedNode := Node;
        for Nod in vList.SelectedNodes do
          vList.Selected[Nod] := False;
        vList.Selected[Node] := True;
        vList.ScrollIntoView(Node, false);
      end;
  finally
    vList.EndUpdate;
  end;
end;

end.

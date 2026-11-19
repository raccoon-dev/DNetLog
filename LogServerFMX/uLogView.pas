unit uLogView;

// Lightweight virtual log list for FMX - a replacement for TVirtualStringTree
// used by the VCL server.
//
// - Nodes are kept in a flat array; only rows inside the viewport are painted,
//   so hundreds of thousands of logs are not a problem.
// - Filtering is done by rebuilding the list of visible rows (FRows), nodes are
//   never removed.
// - Selection and focus are stored per node (not per row), so they survive
//   re-filtering. Nodes hidden by a filter are deselected.
// - Multi-selection: Ctrl+Click, Shift+Click, mouse drag, Shift+arrows, Ctrl+A.
// - Columns can be resized by dragging header borders. One column can be
//   AutoSize - it takes all the remaining width (like hoAutoResize in VST).
//
// PLogNode pointers returned by this control point into a dynamic array, so they
// are valid only until the next AddNode/Clear call. Do not store them.

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Math,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.TextLayout,
  FMX.StdCtrls,
  FMX.ImgList,
  DNLog.Types,
  uLogCommon;

type
  TLogField = (lfPriority, lfTimestamp, lfClient, lfTypeNr, lfMessage, lfData);

  TLogNodeProc = reference to procedure(const Node: TLogNode);
  TLogNodePredicate = reference to function(const Node: TLogNode): Boolean;

  TLogColumn = class
  public
    Caption: string;
    Field: TLogField;
    Width: Single;
    MinWidth: Single;
    MaxWidth: Single;   // 0 = no limit
    Alignment: TTextAlign;
    AutoSize: Boolean;  // takes the remaining width of the control
    Resizable: Boolean;
    ShowHint: Boolean;  // show full cell text as a hint
  end;

  TLogView = class(TControl)
  private const
    TEXT_PADDING      = 4;
    RESIZE_GRIP       = 4;
    MAX_DISPLAY_CHARS = 512;  // longer cell texts are cut before layouting
    MAX_HINT_CHARS    = 4096;
    WHEEL_ROWS        = 3;
  private
    FNodes: TArray<TLogNode>;
    FCount: Integer;
    FRows: TArray<Integer>;      // node indices of visible rows, ascending
    FRowCount: Integer;
    FSelectedCount: Integer;
    FLastSelected: Integer;      // node index - allows O(1) clear of single selection
    FFocused: Integer;           // node index, -1 = none
    FAnchor: Integer;            // node index, -1 = none (start of Shift range)
    FTopRow: Integer;
    FColumns: TObjectList<TLogColumn>;
    FColLeft: TArray<Single>;
    FColWidth: TArray<Single>;
    FImages: TCustomImageList;
    FScrollBar: TScrollBar;
    FLayout: TTextLayout;
    FFont: TFont;
    FRowHeight: Single;
    FHeaderHeight: Single;
    FResizeCol: Integer;
    FResizeStartX: Single;
    FResizeStartWidth: Single;
    FResizeStartNextWidth: Single;
    FMouseSelecting: Boolean;
    FDragRow: Integer;
    FUpdatingScroll: Boolean;
    FHintNode: Integer;
    FHintCol: Integer;
    FOnSelectionChange: TNotifyEvent;
    FColorBackground: TAlphaColor;
    FColorAlternate: TAlphaColor;
    FColorText: TAlphaColor;
    FColorSelection: TAlphaColor;
    FColorSelectionUnfocused: TAlphaColor;
    FColorSelectionText: TAlphaColor;
    FColorGridLine: TAlphaColor;
    FColorHeader: TAlphaColor;
    FColorHeaderText: TAlphaColor;
    FColorBorder: TAlphaColor;
    function GetPageRows: Integer;
    function GetContentWidth: Single;
    function GetFocusedNode: PLogNode;
    function GetNode(Index: Integer): PLogNode;
    procedure SetImages(const Value: TCustomImageList);
    procedure SetTopRow(Value: Integer);
    procedure SetRowHeight(const Value: Single);
    procedure SetHeaderHeight(const Value: Single);
    procedure ScrollBarChange(Sender: TObject);
    procedure UpdateScrollBar;
    procedure CalcColumns;
    function  ColumnBorderAt(X: Single): Integer;
    function  ColumnAt(X: Single): Integer;
    function  RowAt(Y: Single): Integer;
    function  RowNear(NodeIndex: Integer): Integer;
    procedure SetNodeSelected(NodeIndex: Integer; Value: Boolean);
    procedure SelectRows(RowA, RowB: Integer);
    procedure SelectSingleNode(NodeIndex: Integer);
    procedure MoveFocus(NewRow: Integer; Shift: TShiftState);
    procedure DoSelectionChange;
    procedure UpdateHint(X, Y: Single);
    function  CellText(const Node: TLogNode; Field: TLogField): string;
    function  DisplayText(const S: string): string;
    procedure DrawText(const R: TRectF; const Text: string; Align: TTextAlign; Color: TAlphaColor);
    procedure PaintHeader(W: Single);
    procedure PaintRows(W: Single);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure DoEndUpdate; override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoMouseLeave; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single); override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    // Image index for every priority (column with Field = lfPriority).
    PriorityImages: array[TDNLogPriority] of TImageIndex;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function  AddColumn(const ACaption: string; AField: TLogField; AWidth, AMinWidth, AMaxWidth: Single;
                        AAlignment: TTextAlign; AAutoSize: Boolean = False; AResizable: Boolean = True;
                        AShowHint: Boolean = False): TLogColumn;

    procedure Clear;
    // Adds a copy of Node. Repaints immediately unless inside BeginUpdate/EndUpdate.
    function  AddNode(const Node: TLogNode; Visible: Boolean): Integer;
    // Rebuilds visible rows. Predicate = nil shows everything.
    procedure ApplyFilter(const Predicate: TLogNodePredicate);

    procedure ClearSelection;
    procedure SelectAll;
    // Selects and focuses the last visible row, scrolls to the bottom.
    procedure SelectLastRow;
    // Calls Proc for every visible node (top to bottom).
    procedure ForEachVisible(const Proc: TLogNodeProc);
    // Calls Proc for every selected node (top to bottom).
    procedure ForEachSelected(const Proc: TLogNodeProc);

    function  IsAtBottom: Boolean;
    procedure ScrollToBottom;
    procedure ScrollRowIntoView(Row: Integer);

    property Columns: TObjectList<TLogColumn> read FColumns;
    property Count: Integer read FCount;
    property RowCount: Integer read FRowCount;
    property SelectedCount: Integer read FSelectedCount;
    property FocusedNode: PLogNode read GetFocusedNode;
    property Nodes[Index: Integer]: PLogNode read GetNode;
    property TopRow: Integer read FTopRow write SetTopRow;
    property PageRows: Integer read GetPageRows;
    property Font: TFont read FFont;
    property Images: TCustomImageList read FImages write SetImages;
    property RowHeight: Single read FRowHeight write SetRowHeight;
    property HeaderHeight: Single read FHeaderHeight write SetHeaderHeight;

    property ColorBackground: TAlphaColor read FColorBackground write FColorBackground;
    property ColorAlternate: TAlphaColor read FColorAlternate write FColorAlternate;
    property ColorText: TAlphaColor read FColorText write FColorText;
    property ColorSelection: TAlphaColor read FColorSelection write FColorSelection;
    property ColorSelectionUnfocused: TAlphaColor read FColorSelectionUnfocused write FColorSelectionUnfocused;
    property ColorSelectionText: TAlphaColor read FColorSelectionText write FColorSelectionText;
    property ColorGridLine: TAlphaColor read FColorGridLine write FColorGridLine;
    property ColorHeader: TAlphaColor read FColorHeader write FColorHeader;
    property ColorHeaderText: TAlphaColor read FColorHeaderText write FColorHeaderText;
    property ColorBorder: TAlphaColor read FColorBorder write FColorBorder;

    // Fired once per user action (click, key, drag step) or SelectLastRow.
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
  end;

implementation

{ TLogView }

constructor TLogView.Create(AOwner: TComponent);
var
  p: TDNLogPriority;
begin
  inherited;
  CanFocus     := True;
  TabStop      := True;
  HitTest      := True;
  ClipChildren := True;
  ShowHint     := True;

  FColumns := TObjectList<TLogColumn>.Create(True);
  FFont := TFont.Create;
  FFont.Size := 12;
  FLayout := TTextLayoutManager.DefaultTextLayout.Create;

  FRowHeight    := 20;
  FHeaderHeight := 28;
  FFocused      := -1;
  FAnchor       := -1;
  FLastSelected := -1;
  FResizeCol    := -1;
  FDragRow      := -1;
  FHintNode     := -1;
  FHintCol      := -1;

  for p := Low(TDNLogPriority) to High(TDNLogPriority) do
    PriorityImages[p] := Ord(p);

  FColorBackground         := TAlphaColors.White;
  FColorAlternate          := $FFF4F6F7;
  FColorText               := $FF1E272C;
  FColorSelection          := $FF7DADA8;  // same as VCL FocusedSelectionColor
  FColorSelectionUnfocused := $FFB0BEC5;
  FColorSelectionText      := TAlphaColors.White;
  FColorGridLine           := $FFDDE2E5;
  FColorHeader             := $FFECEFF1;
  FColorHeaderText         := $FF37474F;
  FColorBorder             := $FFB0BEC5;

  FScrollBar := TScrollBar.Create(Self);
  FScrollBar.Stored      := False;
  FScrollBar.Locked      := True;
  FScrollBar.Orientation := TOrientation.Vertical;
  FScrollBar.Align       := TAlignLayout.Right;
  FScrollBar.Width       := 16;
  FScrollBar.Margins.Top := FHeaderHeight;
  FScrollBar.SmallChange := 1;
  FScrollBar.CanFocus    := False;
  FScrollBar.OnChange    := ScrollBarChange;
  FScrollBar.Parent      := Self;
end;

destructor TLogView.Destroy;
begin
  FLayout.Free;
  FFont.Free;
  FColumns.Free;
  inherited;
end;

function TLogView.AddColumn(const ACaption: string; AField: TLogField; AWidth,
  AMinWidth, AMaxWidth: Single; AAlignment: TTextAlign; AAutoSize, AResizable,
  AShowHint: Boolean): TLogColumn;
begin
  Result := TLogColumn.Create;
  Result.Caption   := ACaption;
  Result.Field     := AField;
  Result.Width     := AWidth;
  Result.MinWidth  := AMinWidth;
  Result.MaxWidth  := AMaxWidth;
  Result.Alignment := AAlignment;
  Result.AutoSize  := AAutoSize;
  Result.Resizable := AResizable;
  Result.ShowHint  := AShowHint;
  FColumns.Add(Result);
  Repaint;
end;

{ --- data ------------------------------------------------------------------ }

procedure TLogView.Clear;
begin
  FNodes := nil;
  FRows  := nil;
  FCount := 0;
  FRowCount := 0;
  FSelectedCount := 0;
  FLastSelected := -1;
  FFocused := -1;
  FAnchor  := -1;
  FTopRow  := 0;
  FHintNode := -1;
  Hint := '';
  UpdateScrollBar;
  Repaint;
end;

function TLogView.AddNode(const Node: TLogNode; Visible: Boolean): Integer;
begin
  if FCount = Length(FNodes) then
    SetLength(FNodes, Max(1024, FCount * 2));
  Result := FCount;
  FNodes[Result] := Node;
  FNodes[Result].Selected := False;
  Inc(FCount);

  if Visible then
  begin
    if FRowCount = Length(FRows) then
      SetLength(FRows, Max(1024, FRowCount * 2));
    FRows[FRowCount] := Result;
    Inc(FRowCount);
  end;

  if not IsUpdating then
  begin
    UpdateScrollBar;
    Repaint;
  end;
end;

procedure TLogView.ApplyFilter(const Predicate: TLogNodePredicate);
var
  i: Integer;
  OldFocusedRow: Integer;
  FocusedWasInView: Boolean;
begin
  OldFocusedRow := -1;
  if FFocused >= 0 then
    OldFocusedRow := RowNear(FFocused);
  FocusedWasInView := (OldFocusedRow >= FTopRow) and (OldFocusedRow < FTopRow + PageRows);

  SetLength(FRows, Max(1024, FCount));
  FRowCount := 0;
  for i := 0 to FCount - 1 do
    if not Assigned(Predicate) or Predicate(FNodes[i]) then
    begin
      FRows[FRowCount] := i;
      Inc(FRowCount);
    end else
    if FNodes[i].Selected then
      SetNodeSelected(i, False);

  // Keep the focused node in view if it is still visible
  if (FFocused >= 0) and (RowNear(FFocused) >= 0) and (FRows[RowNear(FFocused)] = FFocused) then
  begin
    if FocusedWasInView then
      SetTopRow(RowNear(FFocused) - (OldFocusedRow - FTopRow))
    else
      ScrollRowIntoView(RowNear(FFocused));
  end;

  UpdateScrollBar;
  Repaint;
  DoSelectionChange;
end;

function TLogView.GetNode(Index: Integer): PLogNode;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := @FNodes[Index]
  else
    Result := nil;
end;

function TLogView.GetFocusedNode: PLogNode;
begin
  Result := GetNode(FFocused);
end;

procedure TLogView.ForEachVisible(const Proc: TLogNodeProc);
var
  r: Integer;
begin
  for r := 0 to FRowCount - 1 do
    Proc(FNodes[FRows[r]]);
end;

procedure TLogView.ForEachSelected(const Proc: TLogNodeProc);
var
  i, Left: Integer;
begin
  Left := FSelectedCount;
  i := 0;
  while (Left > 0) and (i < FCount) do
  begin
    if FNodes[i].Selected then
    begin
      Proc(FNodes[i]);
      Dec(Left);
    end;
    Inc(i);
  end;
end;

{ --- selection ------------------------------------------------------------- }

procedure TLogView.SetNodeSelected(NodeIndex: Integer; Value: Boolean);
begin
  if FNodes[NodeIndex].Selected = Value then
    Exit;
  FNodes[NodeIndex].Selected := Value;
  if Value then
  begin
    Inc(FSelectedCount);
    FLastSelected := NodeIndex;
  end else
    Dec(FSelectedCount);
end;

procedure TLogView.ClearSelection;
var
  i: Integer;
begin
  if FSelectedCount = 0 then
    Exit;

  if (FSelectedCount = 1) and (FLastSelected >= 0) and (FLastSelected < FCount)
     and FNodes[FLastSelected].Selected then
    SetNodeSelected(FLastSelected, False)
  else
    for i := 0 to FCount - 1 do
      FNodes[i].Selected := False;

  FSelectedCount := 0;
  FLastSelected := -1;
end;

procedure TLogView.SelectAll;
var
  r: Integer;
begin
  for r := 0 to FRowCount - 1 do
    SetNodeSelected(FRows[r], True);
  DoSelectionChange;
end;

procedure TLogView.SelectRows(RowA, RowB: Integer);
var
  r: Integer;
begin
  ClearSelection;
  if RowA > RowB then
  begin
    r := RowA;
    RowA := RowB;
    RowB := r;
  end;
  RowA := Max(RowA, 0);
  RowB := Min(RowB, FRowCount - 1);
  for r := RowA to RowB do
    SetNodeSelected(FRows[r], True);
end;

procedure TLogView.SelectSingleNode(NodeIndex: Integer);
begin
  ClearSelection;
  SetNodeSelected(NodeIndex, True);
  FAnchor := NodeIndex;
  FFocused := NodeIndex;
end;

procedure TLogView.SelectLastRow;
begin
  if FRowCount = 0 then
    Exit;
  SelectSingleNode(FRows[FRowCount - 1]);
  ScrollToBottom;
  DoSelectionChange;
end;

procedure TLogView.DoSelectionChange;
begin
  Repaint;
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self);
end;

{ --- geometry / scrolling -------------------------------------------------- }

function TLogView.GetPageRows: Integer;
begin
  Result := Max(1, Trunc((Height - FHeaderHeight) / FRowHeight));
end;

function TLogView.GetContentWidth: Single;
begin
  Result := Width;
  if FScrollBar.Visible then
    Result := Result - FScrollBar.Width;
end;

procedure TLogView.SetRowHeight(const Value: Single);
begin
  if Value <= 0 then
    Exit;
  FRowHeight := Value;
  UpdateScrollBar;
  Repaint;
end;

procedure TLogView.SetHeaderHeight(const Value: Single);
begin
  FHeaderHeight := Max(0, Value);
  FScrollBar.Margins.Top := FHeaderHeight;
  UpdateScrollBar;
  Repaint;
end;

procedure TLogView.SetImages(const Value: TCustomImageList);
begin
  if FImages = Value then
    Exit;
  if Assigned(FImages) then
    FImages.RemoveFreeNotification(Self);
  FImages := Value;
  if Assigned(FImages) then
    FImages.FreeNotification(Self);
  Repaint;
end;

procedure TLogView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FImages) then
    FImages := nil;
end;

procedure TLogView.UpdateScrollBar;
var
  Page: Integer;
begin
  Page := PageRows;
  FTopRow := EnsureRange(FTopRow, 0, Max(0, FRowCount - Page));

  FUpdatingScroll := True;
  try
    FScrollBar.Max          := Max(FRowCount, Page);
    FScrollBar.ViewportSize := Page;
    FScrollBar.Value        := FTopRow;
    FScrollBar.Enabled      := FRowCount > Page;
  finally
    FUpdatingScroll := False;
  end;
end;

procedure TLogView.ScrollBarChange(Sender: TObject);
begin
  if FUpdatingScroll then
    Exit;
  FTopRow := EnsureRange(Round(FScrollBar.Value), 0, Max(0, FRowCount - PageRows));
  Repaint;
end;

procedure TLogView.SetTopRow(Value: Integer);
begin
  Value := EnsureRange(Value, 0, Max(0, FRowCount - PageRows));
  if Value = FTopRow then
    Exit;
  FTopRow := Value;
  UpdateScrollBar;
  Repaint;
end;

procedure TLogView.ScrollRowIntoView(Row: Integer);
begin
  if Row < FTopRow then
    SetTopRow(Row)
  else
  if Row >= FTopRow + PageRows then
    SetTopRow(Row - PageRows + 1);
end;

function TLogView.IsAtBottom: Boolean;
begin
  Result := FTopRow + PageRows >= FRowCount;
end;

procedure TLogView.ScrollToBottom;
begin
  SetTopRow(FRowCount - PageRows);
end;

procedure TLogView.Resize;
begin
  inherited;
  UpdateScrollBar;
end;

procedure TLogView.DoEndUpdate;
begin
  inherited;
  UpdateScrollBar;
  Repaint;
end;

procedure TLogView.CalcColumns;
var
  i, AutoIdx: Integer;
  Fixed, x, W: Single;
  c: TLogColumn;
begin
  SetLength(FColLeft, FColumns.Count);
  SetLength(FColWidth, FColumns.Count);

  AutoIdx := -1;
  Fixed := 0;
  for i := 0 to FColumns.Count - 1 do
  begin
    c := FColumns[i];
    if c.AutoSize and (AutoIdx < 0) then
      AutoIdx := i
    else
      Fixed := Fixed + c.Width;
  end;

  W := GetContentWidth;
  x := 0;
  for i := 0 to FColumns.Count - 1 do
  begin
    c := FColumns[i];
    FColLeft[i] := x;
    if i = AutoIdx then
      FColWidth[i] := Max(c.MinWidth, W - Fixed)
    else
      FColWidth[i] := c.Width;
    x := x + FColWidth[i];
  end;
end;

function TLogView.ColumnBorderAt(X: Single): Integer;
var
  i: Integer;
begin
  for i := 0 to FColumns.Count - 1 do
    if FColumns[i].Resizable and (Abs(X - (FColLeft[i] + FColWidth[i])) <= RESIZE_GRIP) then
      Exit(i);
  Result := -1;
end;

function TLogView.ColumnAt(X: Single): Integer;
var
  i: Integer;
begin
  for i := 0 to FColumns.Count - 1 do
    if (X >= FColLeft[i]) and (X < FColLeft[i] + FColWidth[i]) then
      Exit(i);
  Result := -1;
end;

function TLogView.RowAt(Y: Single): Integer;
begin
  if Y < FHeaderHeight then
    Exit(-1);
  Result := FTopRow + Trunc((Y - FHeaderHeight) / FRowHeight);
  if Result >= FRowCount then
    Result := -1;
end;

// Row of the node, or the nearest following visible row if the node is hidden.
// -1 if there are no rows.
function TLogView.RowNear(NodeIndex: Integer): Integer;
var
  lo, hi, mid: Integer;
begin
  if FRowCount = 0 then
    Exit(-1);
  lo := 0;
  hi := FRowCount - 1;
  while lo < hi do
  begin
    mid := (lo + hi) div 2;
    if FRows[mid] < NodeIndex then
      lo := mid + 1
    else
      hi := mid;
  end;
  Result := lo;
end;

{ --- painting -------------------------------------------------------------- }

function TLogView.CellText(const Node: TLogNode; Field: TLogField): string;
begin
  case Field of
    lfTimestamp: Result := Node.LogTimestampString;
    lfClient:    Result := Node.LogClient;
    lfTypeNr:    Result := Node.LogTypeNrString;
    lfMessage:   Result := Node.LogMessage;
    lfData:      Result := Node.LogData;
  else
    Result := string.Empty;
  end;
end;

function TLogView.DisplayText(const S: string): string;
var
  i: Integer;
begin
  if S.Length > MAX_DISPLAY_CHARS then
    Result := S.Substring(0, MAX_DISPLAY_CHARS)
  else
    Result := S;
  // Single line only - like VST
  for i := 1 to Result.Length do
    if (Result[i] = #13) or (Result[i] = #10) or (Result[i] = #9) then
      Result[i] := ' ';
end;

procedure TLogView.DrawText(const R: TRectF; const Text: string; Align: TTextAlign; Color: TAlphaColor);
begin
  if (Text = '') or (R.Width <= 2 * TEXT_PADDING) then
    Exit;
  FLayout.BeginUpdate;
  try
    FLayout.TopLeft         := PointF(R.Left + TEXT_PADDING, R.Top);
    FLayout.MaxSize         := PointF(R.Width - 2 * TEXT_PADDING, R.Height);
    FLayout.HorizontalAlign := Align;
    FLayout.Color           := Color;
    FLayout.Text            := Text;
  finally
    FLayout.EndUpdate;
  end;
  FLayout.RenderLayout(Canvas);
end;

procedure TLogView.PaintHeader(W: Single);
var
  i: Integer;
  x: Single;
begin
  if FHeaderHeight <= 0 then
    Exit;

  Canvas.Fill.Color := FColorHeader;
  Canvas.FillRect(RectF(0, 0, Width, FHeaderHeight), 0, 0, [], AbsoluteOpacity);

  Canvas.Stroke.Color := FColorBorder;
  for i := 0 to FColumns.Count - 1 do
  begin
    DrawText(RectF(FColLeft[i], 0, FColLeft[i] + FColWidth[i], FHeaderHeight),
             FColumns[i].Caption, TTextAlign.Center, FColorHeaderText);
    x := Trunc(FColLeft[i] + FColWidth[i]) - 0.5;
    if x < W then
      Canvas.DrawLine(PointF(x, 4), PointF(x, FHeaderHeight - 4), AbsoluteOpacity);
  end;
  Canvas.DrawLine(PointF(0, FHeaderHeight - 0.5), PointF(Width, FHeaderHeight - 0.5), AbsoluteOpacity);
end;

procedure TLogView.PaintRows(W: Single);
var
  i, r, c, Last: Integer;
  y, x, IconSize: Single;
  P: PLogNode;
  RowR, CellR, IconR: TRectF;
  TextColor: TAlphaColor;
  Focused: Boolean;
begin
  Focused := IsFocused;
  IconSize := Min(16, FRowHeight - 2);
  Last := Min(FRowCount - 1, FTopRow + PageRows);  // +1 partial row at the bottom

  for r := FTopRow to Last do
  begin
    y := FHeaderHeight + (r - FTopRow) * FRowHeight;
    RowR := RectF(0, y, W, y + FRowHeight);
    P := @FNodes[FRows[r]];

    if P.Selected then
    begin
      if Focused then
        Canvas.Fill.Color := FColorSelection
      else
        Canvas.Fill.Color := FColorSelectionUnfocused;
      Canvas.FillRect(RowR, 0, 0, [], AbsoluteOpacity);
      TextColor := FColorSelectionText;
    end else
    begin
      if Odd(r) then
      begin
        Canvas.Fill.Color := FColorAlternate;
        Canvas.FillRect(RowR, 0, 0, [], AbsoluteOpacity);
      end;
      TextColor := FColorText;
    end;

    for c := 0 to FColumns.Count - 1 do
    begin
      CellR := RectF(FColLeft[c], y, FColLeft[c] + FColWidth[c], y + FRowHeight);
      if CellR.Left >= W then
        Break;
      if CellR.Right > W then
        CellR.Right := W;

      if FColumns[c].Field = lfPriority then
      begin
        if Assigned(FImages) and (PriorityImages[P.LogPriority] >= 0) then
        begin
          IconR := RectF(0, 0, IconSize, IconSize);
          RectCenter(IconR, CellR);
          FImages.Draw(Canvas, IconR, PriorityImages[P.LogPriority], AbsoluteOpacity);
        end;
      end else
        DrawText(CellR, DisplayText(CellText(P^, FColumns[c].Field)), FColumns[c].Alignment, TextColor);
    end;

    // Horizontal grid line
    Canvas.Stroke.Color := FColorGridLine;
    Canvas.DrawLine(PointF(0, Trunc(RowR.Bottom) - 0.5), PointF(W, Trunc(RowR.Bottom) - 0.5), AbsoluteOpacity);

    // Focus rectangle
    if Focused and (FRows[r] = FFocused) then
    begin
      Canvas.Stroke.Color := FColorHeaderText;
      Canvas.DrawRect(RectF(0.5, y + 0.5, W - 0.5, y + FRowHeight - 0.5), 0, 0, [], AbsoluteOpacity * 0.6);
    end;
  end;

  // Vertical grid lines - full height (toFullVertGridLines)
  Canvas.Stroke.Color := FColorGridLine;
  for i := 0 to FColumns.Count - 2 do
  begin
    x := Trunc(FColLeft[i] + FColWidth[i]) - 0.5;
    if x < W then
      Canvas.DrawLine(PointF(x, FHeaderHeight), PointF(x, Height), AbsoluteOpacity);
  end;
end;

procedure TLogView.Paint;
var
  W: Single;
begin
  CalcColumns;
  W := GetContentWidth;

  Canvas.Fill.Kind      := TBrushKind.Solid;
  Canvas.Stroke.Kind    := TBrushKind.Solid;
  Canvas.Stroke.Thickness := 1;

  FLayout.BeginUpdate;
  try
    FLayout.Font.Assign(FFont);
    FLayout.WordWrap      := False;
    FLayout.Trimming      := TTextTrimming.Character;
    FLayout.VerticalAlign := TTextAlign.Center;
    FLayout.Opacity       := AbsoluteOpacity;
  finally
    FLayout.EndUpdate;
  end;

  Canvas.Fill.Color := FColorBackground;
  Canvas.FillRect(LocalRect, 0, 0, [], AbsoluteOpacity);

  PaintRows(W);
  PaintHeader(W);

  Canvas.Stroke.Color := FColorBorder;
  Canvas.DrawRect(RectF(0.5, 0.5, Width - 0.5, Height - 0.5), 0, 0, [], AbsoluteOpacity);
end;

{ --- input ----------------------------------------------------------------- }

procedure TLogView.DoEnter;
begin
  inherited;
  Repaint;
end;

procedure TLogView.DoExit;
begin
  inherited;
  Repaint;
end;

procedure TLogView.DoMouseLeave;
begin
  inherited;
  FHintNode := -1;
  FHintCol := -1;
  Hint := '';
  if FResizeCol < 0 then
    Cursor := crDefault;
end;

procedure TLogView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  Row, Idx: Integer;
begin
  inherited;
  if not IsFocused then
    SetFocus;

  CalcColumns;

  // Header - column resizing
  if Y < FHeaderHeight then
  begin
    if Button = TMouseButton.mbLeft then
    begin
      FResizeCol := ColumnBorderAt(X);
      if FResizeCol >= 0 then
      begin
        FResizeStartX := X;
        FResizeStartWidth := FColWidth[FResizeCol];
        if FResizeCol < FColumns.Count - 1 then
          FResizeStartNextWidth := FColumns[FResizeCol + 1].Width
        else
          FResizeStartNextWidth := 0;
      end;
    end;
    Exit;
  end;

  Row := RowAt(Y);
  if Row < 0 then
    Exit;
  Idx := FRows[Row];

  if Button = TMouseButton.mbRight then
  begin
    // Like toRightClickSelect - keep multi-selection if clicked inside it
    if not FNodes[Idx].Selected then
      SelectSingleNode(Idx)
    else
      FFocused := Idx;
    DoSelectionChange;
    Exit;
  end;

  if Button <> TMouseButton.mbLeft then
    Exit;

  if (ssCtrl in Shift) or (ssCommand in Shift) then
  begin
    SetNodeSelected(Idx, not FNodes[Idx].Selected);
    FAnchor := Idx;
    FFocused := Idx;
  end else
  if (ssShift in Shift) and (FAnchor >= 0) then
  begin
    SelectRows(RowNear(FAnchor), Row);
    FFocused := Idx;
  end else
  begin
    SelectSingleNode(Idx);
    FMouseSelecting := True;
    FDragRow := Row;
  end;
  DoSelectionChange;
end;

procedure TLogView.MouseMove(Shift: TShiftState; X, Y: Single);
var
  Delta, NewW: Single;
  c, NextCol: TLogColumn;
  r: Integer;
begin
  inherited;

  // Column resizing
  if FResizeCol >= 0 then
  begin
    Delta := X - FResizeStartX;
    c := FColumns[FResizeCol];
    if c.AutoSize then
    begin
      // Auto-size column takes the rest - resize its right neighbour instead
      if FResizeCol < FColumns.Count - 1 then
      begin
        NextCol := FColumns[FResizeCol + 1];
        NewW := Max(NextCol.MinWidth, FResizeStartNextWidth - Delta);
        if NextCol.MaxWidth > 0 then
          NewW := Min(NewW, NextCol.MaxWidth);
        NextCol.Width := NewW;
      end;
    end else
    begin
      NewW := Max(c.MinWidth, FResizeStartWidth + Delta);
      if c.MaxWidth > 0 then
        NewW := Min(NewW, c.MaxWidth);
      c.Width := NewW;
    end;
    Repaint;
    Exit;
  end;

  // Drag selection
  if FMouseSelecting and (ssLeft in Shift) and (FRowCount > 0) then
  begin
    if Y < FHeaderHeight then
    begin
      SetTopRow(FTopRow - 1);
      r := FTopRow;
    end else
    if Y >= Height then
    begin
      SetTopRow(FTopRow + 1);
      r := Min(FRowCount - 1, FTopRow + PageRows - 1);
    end else
    begin
      r := FTopRow + Trunc((Y - FHeaderHeight) / FRowHeight);
      r := Min(r, FRowCount - 1);
    end;
    if (r <> FDragRow) and (FAnchor >= 0) then
    begin
      FDragRow := r;
      SelectRows(RowNear(FAnchor), r);
      FFocused := FRows[r];
      DoSelectionChange;
    end;
    Exit;
  end;

  CalcColumns;
  if (Y < FHeaderHeight) and (ColumnBorderAt(X) >= 0) then
    Cursor := crSizeWE
  else
    Cursor := crDefault;

  UpdateHint(X, Y);
end;

procedure TLogView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  inherited;
  FResizeCol := -1;
  FMouseSelecting := False;
  FDragRow := -1;
end;

procedure TLogView.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  if Handled then
    Exit;
  if WheelDelta > 0 then
    SetTopRow(FTopRow - WHEEL_ROWS)
  else
  if WheelDelta < 0 then
    SetTopRow(FTopRow + WHEEL_ROWS);
  Handled := True;
end;

procedure TLogView.UpdateHint(X, Y: Single);
var
  Row, Col, Idx: Integer;
  s: string;
begin
  Row := RowAt(Y);
  Col := ColumnAt(X);
  if (Row < 0) or (Col < 0) or not FColumns[Col].ShowHint then
  begin
    if FHintNode >= 0 then
    begin
      FHintNode := -1;
      FHintCol := -1;
      Hint := '';
    end;
    Exit;
  end;

  Idx := FRows[Row];
  if (Idx = FHintNode) and (Col = FHintCol) then
    Exit;
  FHintNode := Idx;
  FHintCol := Col;
  s := CellText(FNodes[Idx], FColumns[Col].Field);
  if s.Length > MAX_HINT_CHARS then
    s := s.Substring(0, MAX_HINT_CHARS) + '...';
  Hint := s;
end;

procedure TLogView.MoveFocus(NewRow: Integer; Shift: TShiftState);
begin
  if FRowCount = 0 then
    Exit;
  NewRow := EnsureRange(NewRow, 0, FRowCount - 1);
  if (ssShift in Shift) and (FAnchor >= 0) then
  begin
    SelectRows(RowNear(FAnchor), NewRow);
    FFocused := FRows[NewRow];
  end else
    SelectSingleNode(FRows[NewRow]);
  ScrollRowIntoView(NewRow);
  DoSelectionChange;
end;

procedure TLogView.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  Cur: Integer;
begin
  inherited;
  if Key = 0 then
    Exit;

  if FFocused >= 0 then
    Cur := RowNear(FFocused)
  else
    Cur := -1;

  case Key of
    vkUp:    MoveFocus(Cur - 1, Shift);
    vkDown:  MoveFocus(Cur + 1, Shift);
    vkPrior: MoveFocus(Cur - PageRows, Shift);
    vkNext:  MoveFocus(Cur + PageRows, Shift);
    vkHome:  MoveFocus(0, Shift);
    vkEnd:   MoveFocus(FRowCount - 1, Shift);
  else
    if ((Key = vkA) or (KeyChar = 'a') or (KeyChar = 'A')) and
       ((ssCtrl in Shift) or (ssCommand in Shift)) then
      SelectAll
    else
      Exit;
  end;
  Key := 0;
  KeyChar := #0;
end;

end.

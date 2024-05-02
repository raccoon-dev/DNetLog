unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.DialogService.Async,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo;

const
  TEST_TIME = 3; // [sec]

type TThreadTest = class(TThread)
  strict private
    procedure Sleep; inline;
  protected
    procedure Execute; override;
end;

type
  TfrmMain = class(TForm)
    btnTest: TButton;
    tmrTest: TTimer;
    Layout1: TLayout;
    MemoLog: TMemo;
    ProgressBarQueue: TProgressBar;
    TimerQueue: TTimer;
    procedure tmrTestTimer(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
    procedure TimerQueueTimer(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    thrTest: TThreadTest;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  DNLog.Client, DNLog.Types, DNLog.Thread;

const
  DELAY_COUNT = 500; // X * 1000

{$R *.fmx}

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  if not _Log.Active then
  begin
    _Log.i('This message will not be send');
    TDialogServiceAsync.ShowMessage('Logs are disabled.');
    Exit;
  end;

  btnTest.Enabled := False;
  ProgressBarQueue.Value := 0;
  ProgressBarQueue.Max := 100;
  TimerQueue.Enabled := True;
  MemoLog.Lines.Append('----------' + sLineBreak + 'Test started...');
  tmrTest.Interval := TEST_TIME * 1000;

  thrTest := TThreadTest.Create(True);

  tmrTest.Enabled := True;
  thrTest.Start;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  MemoLog.Lines.Clear;
  ProgressBarQueue.Value := 0;
end;

procedure TfrmMain.TimerQueueTimer(Sender: TObject);
begin
  var count := _Log.QueueCount;
  if count > ProgressBarQueue.Max then
    ProgressBarQueue.Max := count;
  ProgressBarQueue.Value := count;

end;

procedure TfrmMain.tmrTestTimer(Sender: TObject);
var
  SendCounter: Integer;
  str: TStringBuilder;
begin
  thrTest.Terminate;
  tmrTest.Enabled := False;
  btnTest.Enabled := True;
  SendCounter := thrTest.WaitFor;
  thrTest.Free;

  str := TStringBuilder.Create;
  try
    str.Append('Test time: ').Append(TEST_TIME).Append(' [sec]').AppendLine
       .Append('Sent packets: ').Append(SendCounter).AppendLine
       .Append('Sent packets/sec: ').Append(SendCounter div TEST_TIME);

    MemoLog.Lines.Append(str.ToString);
  finally
    str.Free;
  end;
end;

{ TThreadTest }

procedure TThreadTest.Execute;
var
  Ctr: Cardinal;
  Data: TBytes;
  i: Integer;
  s: string;
begin
  FreeOnTerminate := False;
  Ctr := 1;

  SetLength(Data, 32);
  for i := Low(Data) to High(Data) do
    Data[i] := i + 1;

  while not Terminated do
  begin
    if (Ctr mod 5) = 1 then
      _Log.d(0, 'Debug ' + IntToStr(Ctr), Data) else
    if (Ctr mod 5) = 2 then
      _Log.i(0, 'Info ' + IntToStr(Ctr), Data) else
    if (Ctr mod 5) = 3 then
      _Log.w(0, 'Warning ' + IntToStr(Ctr), Data) else
    if (Ctr mod 5) = 4 then
      _Log.e(0, 'Error ' + IntToStr(Ctr), Data);
    if (Ctr mod 5) = 0 then
      _Log.x(0, 'Exception ' + IntToStr(Ctr), Data);
    Inc(Ctr);

    Sleep;
  end;

  SetLength(Data, 256);
  for i := Low(Data) to High(Data) do
    Data[i] := Byte(i + 1);

  s := '';
  for i := 1 to 23 do
    s := s + '1234567890'; // 230B

  _Log.i(1, 'Long message test (>255B) '{26B} + s, Data);
  _Log.i(1, 'Unicode: ' + Chr(169) + Chr(174) + Chr(920) + Chr(937) + Chr(1422) + Chr(8267));

  SetLength(Data, 0);
  SetReturnValue(Ctr - 1);
end;

procedure TThreadTest.Sleep;
begin
  for var i := 1 to DELAY_COUNT * 1000 do;
end;

end.

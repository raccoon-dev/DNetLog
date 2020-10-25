unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.DialogService.Async,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Layouts;

const
  TEST_TIME = 3; // [sec]

type TThreadTest = class(TThread)
  protected
    procedure Execute; override;
end;

type
  TfrmMain = class(TForm)
    layMain: TFlowLayout;
    btnTest: TButton;
    tmrTest: TTimer;
    procedure tmrTestTimer(Sender: TObject);
    procedure btnTestClick(Sender: TObject);
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
  DNLog.Types, DNLog.Client;

{$R *.fmx}

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  if _Log.Active then
    _Log.Active := False;
  _Log.Active := True;
  if not _Log.Active then
  begin
{$IFDEF DEBUG}
    TDialogServiceAsync.ShowMessage('Can''t open TCP/UDP socket for Log Client.');
{$ELSE}
    TDialogServiceAsync.ShowMessage('Logs are disabled in RELEASE mode.');
{$ENDIF}
    Exit;
  end;

  btnTest.Enabled := False;
  tmrTest.Interval := TEST_TIME * 1000;

  thrTest := TThreadTest.Create(True);

  tmrTest.Enabled := True;
  thrTest.Start;
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

    TDialogServiceAsync.ShowMessage(str.ToString);
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
begin
  FreeOnTerminate := False;
  Ctr := 1;

  SetLength(Data, 32);
  for i := Low(Data) to High(Data) do
    Data[i] := i + 1;

  while not Terminated do
  begin
    if (Ctr mod 4) = 1 then
      _Log.d(0, 'Debug ' + IntToStr(Ctr), Data) else
    if (Ctr mod 4) = 2 then
      _Log.i(0, 'Info ' + IntToStr(Ctr), Data) else
    if (Ctr mod 4) = 3 then
      _Log.w(0, 'Warning ' + IntToStr(Ctr), Data) else
    if (Ctr mod 4) = 0 then
      _Log.e(0, 'Error ' + IntToStr(Ctr), Data);
    Inc(Ctr);

    Sleep(2);
  end;

  SetReturnValue(Ctr - 1);
end;

end.

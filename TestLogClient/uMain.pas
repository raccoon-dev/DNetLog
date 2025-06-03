unit uMain;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.DialogService.Async,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Layouts;

const
  TEST_TIME = 3; // [sec]

type TThreadTest = class(TThread)
  protected
    function GetMaxLengthString: string;
    function GetLongUTF8String: string;
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
    thrTest: TThreadTest;
    procedure OnTerminateThread(Sender: TObject);
  public
  end;

var
  frmMain: TfrmMain;

implementation

uses
  DNLog.Types,
  DNLog.Client;

{$R *.fmx}

procedure TfrmMain.btnTestClick(Sender: TObject);
begin
  btnTest.Enabled := False;
  tmrTest.Interval := TEST_TIME * 1000;

  thrTest := TThreadTest.Create(True);
  thrTest.OnTerminate := OnTerminateThread;
  thrTest.FreeOnTerminate := True;

  tmrTest.Enabled := True;
  thrTest.Start;
end;

procedure TfrmMain.OnTerminateThread(Sender: TObject);
var
  SendCounter: Integer;
  str: TStringBuilder;
begin
  SendCounter := thrTest.ReturnValue;

  btnTest.Enabled := True;

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

procedure TfrmMain.tmrTestTimer(Sender: TObject);
begin
  tmrTest.Enabled := False;
  thrTest.Terminate;
end;

{ TThreadTest }

procedure TThreadTest.Execute;
var
  Ctr: Cardinal;
  Data: TBytes;
  s: string;
begin
  FreeOnTerminate := False;
  Ctr := 1;

  SetLength(Data, 32);
  for var i := Low(Data) to High(Data) do
    Data[i] := i + 1;

  _Log.d(2, GetMaxLengthString);
  _Log.d(2, GetLongUTF8String);

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
  end;

  SetLength(Data, 256);
  for var i := Low(Data) to High(Data) do
    Data[i] := Byte(i + 1);

  s := '';
  for var i := 1 to 23 do
    s := s + '1234567890'; // 230B

  _Log.i(1, 'Long message test (>255B) '{26B} + s, Data);
  _Log.i(1, 'Unicode test: ' + Chr(169) + Chr(174) + Chr(920) + Chr(937) + Chr(1422) + Chr(8267));

  SetLength(Data, 0);
  SetReturnValue(Ctr - 1);
end;

function TThreadTest.GetLongUTF8String: string;
begin
  Result := 'zażółć gęślą jaźń; ';
  repeat
    Result := Result + Result;
  until Length(Result) >= 65535;
  Result := Result.Remove(65535, Length(Result));
end;

function TThreadTest.GetMaxLengthString: string;
begin
  Result := '1234567890';
  repeat
    Result := Result + Result;
  until Length(Result) >= 65535;
  Result := Result.Remove(65535, Length(Result));
end;

end.

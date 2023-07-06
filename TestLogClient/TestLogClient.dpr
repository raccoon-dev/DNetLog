program TestLogClient;

uses
  System.StartUpCopy,
  FMX.Forms,
  uMain in 'uMain.pas' {frmMain},
  DNLog.Client in '..\DNetLog\DNLog.Client.pas',
  DNLog.Types in '..\DNetLog\DNLog.Types.pas',
  DNLog.Sender in '..\DNetLog\DNLog.Sender.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

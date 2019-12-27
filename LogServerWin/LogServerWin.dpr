program LogServerWin;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  DNLog.Types in '..\DNetLog\DNLog.Types.pas',
  DNLog.Server in '..\DNetLog\DNLog.Server.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

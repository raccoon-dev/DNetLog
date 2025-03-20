program LogServerWin;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  DNLog.Types in '..\DNetLog\DNLog.Types.pas',
  DNLog.Server in '..\DNetLog\DNLog.Server.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := {$IFDEF DEBUG}True{$ELSE}False{$ENDIF};
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DNetLog Server';
  TStyleManager.TrySetStyle('Windows10 SlateGray');
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

program LogServerFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Styles,
  FMX.Skia,
  uMain in 'uMain.pas' {frmMain},
  uLogView in 'uLogView.pas',
  uConstants in '..\LogServerShared\uConstants.pas',
  uLogStats in '..\LogServerShared\uLogStats.pas',
  uLogCommon in '..\LogServerShared\uLogCommon.pas',
  uLogStore in '..\LogServerShared\uLogStore.pas',
  uMcpServer in '..\LogServerShared\uMcpServer.pas',
  DNLog.Server in '..\DNetLog\DNLog.Server.pas',
  DNLog.Types in '..\DNetLog\DNLog.Types.pas';

{$R *.res}
// Dark style - FMX counterpart of the VCL 'Windows10 SlateGray' style used by LogServerWin
{$R 'LogServerFMX.Styles.res' 'LogServerFMX.Styles.rc'}

begin
  ReportMemoryLeaksOnShutdown := {$IFDEF DEBUG}True{$ELSE}False{$ENDIF};
  GlobalUseSkia := True;
  TStyleManager.TrySetStyleFromResource('WIN10MODERNSLATEGRAY');
  Application.Initialize;
  Application.Title := 'DNetLog Server';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

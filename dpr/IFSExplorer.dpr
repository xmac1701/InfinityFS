program IFSExplorer;

uses
  Forms,
  IFSE.MainForm in '..\src\Explorer\IFSE.MainForm.pas' {fmIFSEMain},
  IFS.GSS in '..\src\IFS\IFS.GSS.pas',
  IFS.Base in '..\src\IFS\IFS.Base.pas',
  IFSE.Global in '..\src\Explorer\IFSE.Global.pas',
  IFS.Stream.Compressor in '..\src\IFS\IFS.Stream.Compressor.pas',
  IFS.Stream.Encryptor in '..\src\IFS\IFS.Stream.Encryptor.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmIFSEMain, fmIFSEMain);
  Application.Run;
end.

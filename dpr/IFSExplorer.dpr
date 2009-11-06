program IFSExplorer;

uses
  Forms,
  ufmIFSEMain in '..\src\Explorer\ufmIFSEMain.pas' {fmIFSEMain},
  IFS.GSS in '..\src\IFS\IFS.GSS.pas',
  IFS.Base in '..\src\IFS\IFS.Base.pas',
  uIFSEGlobal in '..\src\Explorer\uIFSEGlobal.pas',
  IFS.StreamCodec in '..\src\IFS\IFS.StreamCodec.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfmIFSEMain, fmIFSEMain);
  Application.Run;
end.

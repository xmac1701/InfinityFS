program IFSTests;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options
  to use the console test runner.  Otherwise the GUI test runner will be used by
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  IFS.Base in '..\src\IFS\IFS.Base.pas',
  IFS.GSS in '..\src\IFS\IFS.GSS.pas',
  IFS.Stream.Compressor in '..\src\IFS\IFS.Stream.Compressor.pas',
  IFS.Stream.Encryptor in '..\src\IFS\IFS.Stream.Encryptor.pas',
  IFSTests.Main in '..\src\Tests\IFSTests.Main.pas';

{$R *.RES}

procedure RegTests();
begin
//  RegisterTests('Reserved Files and Folders', [TTestReservedFilesAndFolders.Suite]);
  RegisterTests('TifsFileAttr', [TTestFileAttr.Suite]);
end;

begin
  Application.Initialize;
  RegTests;
  if IsConsole then
    with TextTestRunner.RunRegisteredTests do
      Free
  else
    GUITestRunner.RunRegisteredTests;
end.


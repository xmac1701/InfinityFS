unit IFSExplorer.Global;

interface

uses
  Windows;

procedure Log(txt: string); inline;

implementation

procedure Log(txt: string);
begin
{$IFDEF DEBUG}
  Writeln(txt);
{$ENDIF}
end;

initialization
{$IFDEF DEBUG}
  AllocConsole;
{$ENDIF}

finalization
{$IFDEF DEBUG}
  FreeConsole;
{$ENDIF}

end.

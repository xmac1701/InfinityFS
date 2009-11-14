unit IFSTests.Main;

interface

uses
  SysUtils, Classes, TestFramework,
  IFS.Base;

type
  TTestReservedFilesAndFolders = class(TTestCase)
  published
    procedure TestFileInRezFolder;
    procedure TestFileNameRez;
    procedure TestFolderInRezFolder;
    procedure TestFolderNameRez;
  end;

  TTestFileAttr = class(TTestCase)
  published
    procedure TestAttr;
  end;

implementation

uses
  RegExpr;

{ TTestReservedFilesAndFolders }

procedure TTestReservedFilesAndFolders.TestFileInRezFolder;
begin
  CheckTrue(ExecRegExpr('/\$IFS\$', '/$IFS$/a/b/c/d'));
  CheckFalse(ExecRegExpr('/\$IFS\$', '/a/b/c/d'));

  CheckTrue(ExecRegExpr('/\$IFS\$/', '/ab/cd/$IFS$/a/b/c/d'));
  CheckFalse(ExecRegExpr('/\$IFS\$/', '/ab/cd/a/b/c/d'));
end;

procedure TTestReservedFilesAndFolders.TestFileNameRez;
begin
  CheckTrue(ExecRegExpr('\.ifsFileAttr', '/a/q/e/.ifsFileAttr'));
  CheckTrue(ExecRegExpr('\.ifsStorageAttr', '/a/q/e/.ifsStorageAttr'));

end;

procedure TTestReservedFilesAndFolders.TestFolderInRezFolder;
begin
  CheckTrue(ExecRegExpr('/\$IFS\$', '/$IFS$/a/'));
  CheckTrue(ExecRegExpr('/\$IFS\$/', '/ab/cd/$IFS$/a/c/'));

end;

procedure TTestReservedFilesAndFolders.TestFolderNameRez;
begin
  CheckTrue(ExecRegExpr('/\$IFS\$', '/abc/$IFS$/123'));

end;

{ TTestFileAttr }

procedure TTestFileAttr.TestAttr;
var
  attr: TifsFileAttr;
begin
  CheckEquals(0, SizeOf(TifsFileAttr));
  attr.Init;
  CheckEquals(0, attr.Attribute);
  attr.IsArchive := True;
  attr.IsCompressed := True;
  attr.IsHidden := True;
  CheckEquals($10022, attr.Attribute);
end;

end.

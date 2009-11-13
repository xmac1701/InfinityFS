unit IFS.GSS;

interface

uses
  Windows, SysUtils, Classes, Generics.Collections,
  IFS.Base, IOUtils,
  GpStructuredStorage;

type
  TifsGSS = class(TInfinityFS)
  strict private
    class constructor Create;
  private
    FStorage: IGpStructuredStorage;
  protected
    function GetFileAttr(const FileName: string): TifsFileAttr; override;
    function GetStorageAttr: TifsStorageAttr; override;
    function GetVersion: UInt32; override;
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; override;
    procedure InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; override;
    procedure InternalOpenStorage(Stream: TStream); overload; override;
    procedure SetFileAttr(const FileName: string; const Value: TifsFileAttr); override;
    procedure SetStorageAttr(const Value: TifsStorageAttr); override;
  public
    constructor Create; override;
    procedure CloseStorage; override;
    procedure CreateFolder(const NewFolderName: string); override;
    procedure ExportFile(const DataFile, LocalFile: string); override;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); override;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); override;
    procedure ImportFile(const LocalFile, DataFile: string); override;
    function IsIFS(const StorageFile: string): Boolean; overload; override;
    function IsIFS(Stream: TStream): Boolean; overload; override;
    property Intf: IGpStructuredStorage read FStorage;
  end;

implementation

uses
  RegExpr;

procedure GSS_Global_Init;
begin
  with TifsGSS do
  begin
    IFS_Reserved_Folders.Add('/$IFS$');

    IFS_Reserved_Files.Add('.ifsStorageAttr');
    IFS_Reserved_Files.Add('.ifsFileAttr');
  end;
end;

function ExecRegExpr(const ARegExpr, AInputStr : RegExprString): boolean;
var
  r : TRegExpr;
begin
  r := TRegExpr.Create;
  try
    r.ModifierI := True;
    r.Expression := ARegExpr;
    Result := r.Exec (AInputStr);
  finally
    r.Free;
  end;
end;

function TifsGSS.GetFileAttr(const FileName: string): TifsFileAttr;
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo[FileName];
  Result.Size := fi.Size;
  Result.Attribute := faArchive;
end;

function TifsGSS.GetStorageAttr: TifsStorageAttr;
var
  fs: TStream;
begin
// todo: get stg attr.
//  fs := InternalOpenFile('/$IFS$/StorageAttribute', fmOpenRead);
//  Result.;
end;

function TifsGSS.GetVersion: UInt32;
begin
  Result := $02000000;    // 2.0.0.0  Same to GSS version
end;

function TifsGSS.InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
begin
  Result := FStorage.OpenFile(GetFullName(FileName), Mode);
end;

procedure TifsGSS.InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead);
begin
  FStorage.Initialize(StorageFile, Mode);
  CurFolder := '/';
end;

procedure TifsGSS.InternalOpenStorage(Stream: TStream);
begin
  FStorage.Initialize(Stream);
  CurFolder := '/';
end;

procedure TifsGSS.SetFileAttr(const FileName: string; const Value: TifsFileAttr);
begin
  inherited;
end;

procedure TifsGSS.SetStorageAttr(const Value: TifsStorageAttr);
begin
  inherited;
end;

constructor TifsGSS.Create;
begin
  inherited;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

class constructor TifsGSS.Create;
begin
  inherited;

end;

procedure TifsGSS.CloseStorage;
begin
  FStorage := nil;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TifsGSS.CreateFolder(const NewFolderName: string);
begin
  FStorage.CreateFolder(GetFullName(NewFolderName));
end;

procedure TifsGSS.ExportFile(const DataFile, LocalFile: string);
var
  stmRead: TStream;
  stmWrite: TFileStream;
begin
  stmRead := FStorage.OpenFile(GetFullName(DataFile), fmOpenRead);
  stmWrite := TFileStream.Create(LocalFile, fmCreate);
  try
    stmWrite.CopyFrom(stmRead, 0); //todo:  here can be extended
  finally
    stmRead.Free;
    stmWrite.Free;
  end;
end;

procedure TifsGSS.FileTraversal(const Folder: string; Callback: TTraversalProc);
var
  AList: TStringList;
  s: string;
begin
  AList := TStringList.Create;
  try
    FStorage.FileNames(Folder, AList);
    for s in AList do
      if not IFS_Reserved_Files.Contains(s) then    // Do not process reserved files.
        Callback(s, GetFileAttr(s));
  finally
    AList.Free;
  end;  // try
end;

procedure TifsGSS.FolderTraversal(const Folder: string; Callback: TTraversalProc);
var
  AList: TStringList;
  s: string;
begin
  AList := TStringList.Create;
  try
    FStorage.FolderNames(Folder, AList);
    for s in AList do
      if not IFS_Reserved_Folders.Contains(s) then    // Do not process reserved files.
        Callback(s, GetFileAttr(s));
  finally
    AList.Free;
  end;  // try
end;

procedure TifsGSS.ImportFile(const LocalFile, DataFile: string);
var
  stmWrite: TStream;
  stmRead: TFileStream;
begin
  stmRead := TFileStream.Create(LocalFile, fmOpenRead);
  stmWrite := InternalOpenFile(DataFile, fmCreate);
  try
    stmWrite.CopyFrom(stmRead, 0);//todo: 这里可以扩展
  finally
    stmRead.Free;
    stmWrite.Free;
  end;
end;

function TifsGSS.IsIFS(const StorageFile: string): Boolean;
begin
  Result := FStorage.IsStructuredStorage(StorageFile);
end;

function TifsGSS.IsIFS(Stream: TStream): Boolean;
begin
  Result := FStorage.IsStructuredStorage(Stream);
end;

initialization
  GSS_Global_Init;

end.



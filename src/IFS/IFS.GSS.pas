unit IFS.GSS;

interface

uses
  Windows, SysUtils, Classes,
  IFS.Base,
  GpStructuredStorage;

type
  TIFS_GSS = class(TInfinityFS)
  private
    FStorage: IGpStructuredStorage;
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
    function OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream; override;
    procedure OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite); overload; override;
    procedure OpenStorage(Stream: TStream); overload; override;
  end;

implementation

constructor TIFS_GSS.Create;
begin
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TIFS_GSS.CloseStorage;
begin
  FStorage := nil;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TIFS_GSS.CreateFolder(const NewFolderName: string);
begin
  if NewFolderName[1] = '/' then
    FStorage.CreateFolder(NewFolderName)
  else
    FStorage.CreateFolder(CurFolder + NewFolderName);
end;

procedure TIFS_GSS.ExportFile(const DataFile, LocalFile: string);
var
  stmRead: TStream;
  stmWrite: TFileStream;
begin
  stmRead := FStorage.OpenFile(DataFile, fmOpenRead);
  stmWrite := TFileStream.Create(LocalFile, fmCreate);
  try
    stmWrite.CopyFrom(stmRead, stmRead.Size); //todo:  here can be extended
  finally
    stmRead.Free;
    stmWrite.Free;
  end;
end;

procedure TIFS_GSS.FileTraversal(const Folder: string; Callback: TTraversalProc);
var
  AList: TStringList;
  s: string;
begin
  AList := TStringList.Create;
  try
    FStorage.FileNames(Folder, AList);
    for s in AList do
      Callback(s);
  finally
    AList.Free;
  end;  // try
end;

procedure TIFS_GSS.FolderTraversal(const Folder: string; Callback: TTraversalProc);
var
  AList: TStringList;
  s: string;
begin
  AList := TStringList.Create;
  try
    FStorage.FolderNames(Folder, AList);
    for s in AList do
      Callback(s);
  finally
    AList.Free;
  end;  // try
end;

procedure TIFS_GSS.ImportFile(const LocalFile, DataFile: string);
var
  stmWrite: TStream;
  stmRead: TFileStream;
begin
  stmRead := TFileStream.Create(LocalFile, fmOpenRead);
  stmWrite := FStorage.OpenFile(DataFile, fmCreate);
  try
    stmWrite.CopyFrom(stmRead, stmRead.Size);//todo: 这里可以扩展
  finally
    stmRead.Free;
    stmWrite.Free;
  end;
end;

function TIFS_GSS.IsIFS(const StorageFile: string): Boolean;
begin
  Result := FStorage.IsStructuredStorage(StorageFile);
end;

function TIFS_GSS.IsIFS(Stream: TStream): Boolean;
begin
  Result := FStorage.IsStructuredStorage(Stream);
end;

function TIFS_GSS.OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream;
begin
  Result := FStorage.OpenFile(FileName, Mode);
end;

procedure TIFS_GSS.OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite);
begin
  FStorage.Initialize(StorageFile, Mode);
  CurFolder := '/';
end;

procedure TIFS_GSS.OpenStorage(Stream: TStream);
begin
  FStorage.Initialize(Stream);
  CurFolder := '/';
end;

end.

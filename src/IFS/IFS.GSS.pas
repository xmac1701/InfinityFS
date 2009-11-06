unit IFS.GSS;

interface

uses
  Windows, SysUtils, Classes,
  IFS.Base,
  GpStructuredStorage;

type
  TifsGSS = class(TInfinityFS)
  private
    FStorage: IGpStructuredStorage;
  public
    constructor Create; override;
    procedure CloseStorage; override;
    procedure CreateFolder(const NewFolderName: string); override;
    procedure ExportFile(const DataFile, LocalFile: string); override;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); override;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); override;
    function GetFileAttr(const FileName: string): TifsFileAttr; override;
    function GetFileAttrEx(const FileName: string): TifsFileAttrEx; override;
    procedure ImportFile(const LocalFile, DataFile: string); override;
    function IsIFS(const StorageFile: string): Boolean; overload; override;
    function IsIFS(Stream: TStream): Boolean; overload; override;
    function OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream; override;
    procedure OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite); overload; override;
    procedure OpenStorage(Stream: TStream); overload; override;
    property Intf: IGpStructuredStorage read FStorage;
  end;

implementation

constructor TifsGSS.Create;
begin
  FStorage := GpStructuredStorage.CreateStructuredStorage;
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
    stmWrite.CopyFrom(stmRead, stmRead.Size); //todo:  here can be extended
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
      Callback(s, GetFileAttr(s));
  finally
    AList.Free;
  end;  // try
end;

function TifsGSS.GetFileAttr(const FileName: string): TifsFileAttr;
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo[GetFullName(FileName)];
end;

function TifsGSS.GetFileAttrEx(const FileName: string): TifsFileAttrEx;
begin
  // TODO -cMM: TifsGSS.GetFileAttrEx default body inserted
end;

procedure TifsGSS.ImportFile(const LocalFile, DataFile: string);
var
  stmWrite: TStream;
  stmRead: TFileStream;
begin
  stmRead := TFileStream.Create(LocalFile, fmOpenRead);
  stmWrite := FStorage.OpenFile(GetFullName(DataFile), fmCreate);
  try
    stmWrite.CopyFrom(stmRead, stmRead.Size);//todo: 这里可以扩展
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

function TifsGSS.OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream;
begin
  Result := FStorage.OpenFile(GetFullName(FileName), Mode);
end;

procedure TifsGSS.OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite);
begin
  FStorage.Initialize(StorageFile, Mode);
  CurFolder := '/';
end;

procedure TifsGSS.OpenStorage(Stream: TStream);
begin
  FStorage.Initialize(Stream);
  CurFolder := '/';
end;

end.

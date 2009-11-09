unit IFS.GSS;

interface

uses
  Windows, SysUtils, Classes, Generics.Collections,
  IFS.Base, IFS.Stream,
  GpStructuredStorage;

type
  TifsGSS = class(TInfinityFS)
  private
    FStorage: IGpStructuredStorage;
  protected
    function GetVersion: UInt32; override;
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; override;
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
    procedure OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; override;
    procedure OpenStorage(Stream: TStream); overload; override;
    property Intf: IGpStructuredStorage read FStorage;
  end;

implementation

var
  GSS_Reserved_Files: TList<string>;

procedure Init_GSS_Global;
begin
  GSS_Reserved_Files := TList<string>.Create;
  with GSS_Reserved_Files do
  begin
    Add('.ifsFileAttrEx');
  end;
end;

constructor TifsGSS.Create;
begin
  inherited;
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
      if not GSS_Reserved_Files.Contains(s) then    // Do not process reserved files.
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
  Result.Compressor := $00;
  Result.Encryptor := $00;
end;

function TifsGSS.GetVersion: UInt32;
begin
  Result := $02000000;    // 2.0.0.0  Same to GSS version
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

function TifsGSS.InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
begin
  Result := FStorage.OpenFile(GetFullName(FileName), Mode);
end;

function TifsGSS.IsIFS(const StorageFile: string): Boolean;
begin
  Result := FStorage.IsStructuredStorage(StorageFile);
end;

function TifsGSS.IsIFS(Stream: TStream): Boolean;
begin
  Result := FStorage.IsStructuredStorage(Stream);
end;

procedure TifsGSS.OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead);
begin
  FStorage.Initialize(StorageFile, Mode);
  CurFolder := '/';
end;

procedure TifsGSS.OpenStorage(Stream: TStream);
begin
  FStorage.Initialize(Stream);
  CurFolder := '/';
end;

initialization
  Init_GSS_Global;

end.

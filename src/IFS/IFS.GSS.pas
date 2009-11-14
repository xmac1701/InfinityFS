unit IFS.GSS;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows, SysUtils, Classes, Generics.Collections,
  IFS.Base, IOUtils,
  GpStructuredStorage;

type
  TifsGSS = class(TCustomIFS)
  strict private
    class constructor Create;
  private
    FStorage: IGpStructuredStorage;
  protected
    function GetFileAttr(const FileName: string): TifsFileAttr; override;
    procedure GetStorageAttr; override;
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
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); override;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); override;
    function IsIFS(const StorageFile: string): Boolean; overload; override;
    function IsIFS(Stream: TStream): Boolean; overload; override;
    property Intf: IGpStructuredStorage read FStorage;
  end;

implementation

uses
  RegExpr;

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

class constructor TifsGSS.Create;
begin
  inherited;

  IFS_Reserved_Folder_Patterns.Add('/\$IFS\$');         // /$IFS$

end;

/// <remarks>
/// FileName must be a full name(file or folder)
/// </remarks>
function TifsGSS.GetFileAttr(const FileName: string): TifsFileAttr;
var
  fi: IGpStructuredFileInfo;
begin
  Result.Init;
  if FStorage.FolderExists(FileName) then
    Result.IsDirectory := True;

  fi := FStorage.FileInfo[FileName];
  try
    Result.Size := fi.Size;
    Result.CreationTime := StrToFloatDef(fi.Attribute['CreationTime'], 0);
    Result.LastModifyTime := StrToFloatDef(fi.Attribute['LastModifyTime'], 0);
    Result.LastAccessTime := StrToFloatDef(fi.Attribute['LastAccessTime'], 0);
    Result.Attribute := StrToIntDef(fi.Attribute['Attribute'], faArchive);
  finally
    fi := nil;
  end;
end;

procedure TifsGSS.GetStorageAttr;
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo['/'];
  try
    FStorageAttr.Compressor := Byte(fi.Attribute['Compressor'][1]);
    FStorageAttr.Encryptor := 0{Byte(fi.Attribute['Encryptor'][1])};
  finally
    fi := nil;
  end;
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
var
  stgattr: TifsStorageAttr;
begin
  FStorage.Initialize(StorageFile, Mode);
  if Mode = fmCreate then
  begin
    //todo: set init storage attr.
    stgattr.Compressor := 0;
    stgattr.Encryptor := 0;
    SetStorageAttr(stgattr);
    FStorage.CreateFolder('/$IFS$');
  end;

  CurFolder := '/';
end;

procedure TifsGSS.InternalOpenStorage(Stream: TStream);
begin
  FStorage.Initialize(Stream);
  CurFolder := '/';
end;

procedure TifsGSS.SetFileAttr(const FileName: string; const Value: TifsFileAttr);
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo[FileName];
  try
    fi.Attribute['CreationTime'] := FloatToStr(Value.CreationTime);
    fi.Attribute['LastModifyTime'] := FloatToStr(Value.LastModifyTime);
    fi.Attribute['LastAccessTime'] := FloatToStr(Value.LastAccessTime);
    fi.Attribute['Attribute'] := IntToStr(Value.Attribute);
  finally
    fi := nil;
  end;
end;

procedure TifsGSS.SetStorageAttr(const Value: TifsStorageAttr);
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo['/'];
  try
    fi.Attribute['Compressor'] := AnsiChar(Value.Compressor);
//    fi.Attribute['Encryptor'] := AnsiChar(Value.Encryptor);
  finally
    fi := nil;
  end;
end;

constructor TifsGSS.Create;
begin
  inherited;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TifsGSS.CloseStorage;
begin
  inherited;
  FStorage := nil;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TifsGSS.CreateFolder(const NewFolderName: string);
begin
  FStorage.CreateFolder(GetFullName(NewFolderName));
end;

procedure TifsGSS.FileTraversal(const Folder: string; Callback: TTraversalProc);
var
  AList: TStringList;
  s: string;
begin
//todo: check if the folder has password.
  AList := TStringList.Create;
  try
    FStorage.FileNames(Folder, AList);
    for s in AList do
      if not IsReservedFile(s) then    // Do not process reserved files.
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
//todo: check if the folder has password.
  AList := TStringList.Create;
  try
    FStorage.FolderNames(Folder, AList);
    for s in AList do
      if not IsReservedFolder(s) then    // Do not process reserved files.
        Callback(s, GetFileAttr(Folder + '/' + s));
  finally
    AList.Free;
  end;  // try
end;

function TifsGSS.IsIFS(const StorageFile: string): Boolean;
begin
  Result := FStorage.IsStructuredStorage(StorageFile);
end;

function TifsGSS.IsIFS(Stream: TStream): Boolean;
begin
  Result := FStorage.IsStructuredStorage(Stream);
end;

end.



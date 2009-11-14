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
    function GetActive: Boolean; override;
    function GetFileAttr(FileName: string): TifsFileAttr; override;
    function GetFolderAttr(FolderName: string): TifsFolderAttr; override;
    procedure GetStorageAttr; override;
    function GetVersion: UInt32; override;
    procedure InternalCreateFolder(const NewFolderName: string); override;
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenReadWrite): TStream; override;
    procedure InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenReadWrite); overload; override;
    procedure InternalOpenStorage(Stream: TStream); overload; override;
    procedure SetFileAttr(FileName: string; const Value: TifsFileAttr); override;
    procedure SetFolderAttr(FolderName: string; const Value: TifsFolderAttr); override;
    procedure SetStorageAttr(const Value: TifsStorageAttr); override;
  public
    constructor Create; override;
    procedure CloseStorage; override;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc; IncludeSystemFiles: Boolean = False); override;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc; IncludeSystemFolders: Boolean = False);
        override;
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

constructor TifsGSS.Create;
begin
  inherited;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

function TifsGSS.GetActive: Boolean;
begin
  Result := (FStorage <> nil) and (FStorage.DataSize > 0);
end;

/// <remarks>
/// FileName must be a full name(file or folder)
/// </remarks>
function TifsGSS.GetFileAttr(FileName: string): TifsFileAttr;
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

function TifsGSS.GetFolderAttr(FolderName: string): TifsFolderAttr;
begin
  Result := GetFileAttr(FolderName+'/.ifsFolderAttr');
end;

procedure TifsGSS.GetStorageAttr;
var
  fi: IGpStructuredFileInfo;
begin
  fi := FStorage.FileInfo['/'];
  try
    FStorageAttr.Compressor := Byte('Z'){Byte(fi.Attribute['Compressor'][1])};
    FStorageAttr.Encryptor := 0{Byte(fi.Attribute['Encryptor'][1])};
  finally
    fi := nil;
  end;
end;

function TifsGSS.GetVersion: UInt32;
begin
  Result := $02000000;    // 2.0.0.0  Same to GSS version
end;

function TifsGSS.InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenReadWrite): TStream;
begin
  Result := FStorage.OpenFile(GetFullName(FileName), Mode);
end;

procedure TifsGSS.InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenReadWrite);
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

procedure TifsGSS.SetFileAttr(FileName: string; const Value: TifsFileAttr);
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

procedure TifsGSS.SetFolderAttr(FolderName: string; const Value: TifsFolderAttr);
begin
  SetFileAttr(FolderName+'/.ifsFolderAttr', Value);
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

class constructor TifsGSS.Create;
begin
  inherited;

  IFS_Reserved_Folder_Patterns.Add('\$IFS\$');         // /$IFS$

end;

procedure TifsGSS.CloseStorage;
begin
  inherited;
  FStorage := nil;
  FStorage := GpStructuredStorage.CreateStructuredStorage;
end;

procedure TifsGSS.InternalCreateFolder(const NewFolderName: string);
begin
  FStorage.CreateFolder(NewFolderName);
end;

procedure TifsGSS.FileTraversal(const Folder: string; Callback: TTraversalProc; IncludeSystemFiles: Boolean = False);
var
  AList: TStringList;
  s: string;
begin
//todo: check if the folder has password.
  AList := TStringList.Create;
  try
    FStorage.FileNames(Folder, AList);
    if AList.Count > 0 then
      for s in AList do
        if not IsReservedFile(s) or IncludeSystemFiles then    // Shall we process reserved files?
          Callback(s, GetFileAttr(EnsurePathWithDelim(Folder) + s));
  finally
    AList.Free;
  end;  // try
end;

procedure TifsGSS.FolderTraversal(const Folder: string; Callback: TTraversalProc; IncludeSystemFolders: Boolean =
    False);
var
  AList: TStringList;
  s: string;
begin
//todo: check if the folder has password.
  AList := TStringList.Create;
  try
    FStorage.FolderNames(Folder, AList);
    if AList.Count > 0 then
      for s in AList do
        if not IsReservedFolder(s) or IncludeSystemFolders then    // Shall we process reserved folders?
          Callback(s, GetFileAttr(EnsurePathWithDelim(Folder) + s));
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



unit IFS.Base;

interface

uses
  Windows, SysUtils, Classes;

const
{ File extended attribute constants }
  faCompressed = $00010000;
  faEncrypted  = $00020000;

type
  /// <summary>
  /// Attributes for files in IFS.
  /// </summary>
  /// <param name="Size">Size of the file</param>
  /// <param name="CreationTime">When we created the file</param>
  /// <param name="LastModifyTime">When we last modified the file</param>
  /// <param name="LastAccessTime">When we last accessed the file</param>
  /// <param name="Compressed">Whether the file was compressed</param>
  /// <param name="IsEncrypted">Whether the file was IsEncrypted</param>
  TifsFileAttr = record
    Size: Int64;
    CreationTime: TDateTime;
    LastModifyTime: TDateTime;
    LastAccessTime: TDateTime;
    Attribute: UInt32;
    function IsArchive: Boolean; inline;
    function IsCompressed: Boolean; inline;
    function IsDirectory: Boolean; inline;
    function IsEncrypted: Boolean; inline;
    function IsHidden: Boolean; inline;
    function IsReadOnly: Boolean; inline;
    function IsSymLink: Boolean; inline;
    function IsSysFile: Boolean; inline;
  end;

type
  TifsCompressorClass = class of TifsCompressor;
  TifsCompressor = class
  public
    class function Compress(Source: TStream): TStream; virtual;
    class function Decompress(Source: TStream): TStream; virtual;
    class function ID: UInt8; virtual;
  end;

  TifsEncryptorClass = class of TifsEncryptor;
  TifsEncryptor = class
  public
    class function Decrypt(Source: TStream; Key: string): TStream; virtual;
    class function Encrypt(Source: TStream; Key: string): TStream; virtual;
    class function ID: UInt8; virtual;
  end;

type
  TTraversalProc = reference to procedure(FileName: string; Attr: TifsFileAttr);

  TRequirePasswordEvent = procedure(FileName: string; var Password: string) of object;

  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TInfinityFS = class abstract
  private
    FCurFolder: string;
    FOnPassword: TRequirePasswordEvent;
    FVersion: UInt32;
  protected
    FCompressor: TifsCompressorClass;
    FEncryptor: TifsEncryptorClass;
    FPathDelim: Char;
    procedure DoRequirePassword(const FileName: string; var Password: string);
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual; abstract;
    procedure SetCurFolder(const Value: string); virtual;
    function GetVersion: UInt32; virtual; abstract;
    procedure InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual; abstract;
    procedure InternalOpenStorage(Stream: TStream); overload; virtual; abstract;
  public
    constructor Create; virtual;
    procedure ChangeFilePassword(const OldPassword, NewPassword: string); virtual;
    procedure CloseStorage; virtual; abstract;
    procedure CreateFolder(const NewFolderName: string); virtual; abstract;
    procedure ExportFile(const DataFile, LocalFile: string); virtual; abstract;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    function GetFileAttr(const FileName: string): TifsFileAttr; virtual; abstract;
    function GetFullName(const AName: string): string;
    procedure ImportFile(const LocalFile, DataFile: string); virtual; abstract;
    function IsIFS(const StorageFile: string): Boolean; overload; virtual; abstract;
    function IsIFS(Stream: TStream): Boolean; overload; virtual; abstract;
    function OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual;
    procedure OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual;
    procedure OpenStorage(Stream: TStream); overload; virtual;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property PathDelim: Char read FPathDelim;
    property Version: UInt32 read GetVersion;
    property OnPassword: TRequirePasswordEvent read FOnPassword write FOnPassword;
  end;

  TifsFileStream = class(TMemoryStream)
  private
    FAttr: TifsFileAttr;
    FFileName: string;
    FFileSystem: TInfinityFS;
    FPassword: string;
    FProcessing: Boolean;
    FRawStream: TStream;
    procedure CheckPassword;
    procedure SetPassword(const Value: string); inline;
  protected
    procedure Decode;
    procedure Encode;
    procedure Flush;
  public
    constructor Create(FS: TInfinityFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
    destructor Destroy; override;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

procedure RegisterCompressor(Compressor: TifsCompressorClass);
procedure RegisterEncryptor(Encryptor: TifsEncryptorClass);

implementation

var
  Compressors: array of TifsCompressorClass;
  Encryptors: array of TifsEncryptorClass;

procedure RegisterCompressor(Compressor: TifsCompressorClass);
var
  i: Int32;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Compressors[i] := Compressor;
end;

procedure RegisterEncryptor(Encryptor: TifsEncryptorClass);
var
  i: Int32;
begin
  i := Length(Encryptors);
  SetLength(Encryptors, i+1);
  Encryptors[i] := Encryptor;
end;

function FindCompressor(ID: Byte): TifsCompressorClass;
var
  i: Int32;
begin
  for i := Low(Compressors) to High(Compressors) do
    if Compressors[i].ID = ID then
      Exit(Compressors[i]);
  Result := TifsCompressor;
end;

function FindEncryptor(ID: Byte): TifsEncryptorClass;
var
  i: Int32;
begin
  for i := Low(Encryptors) to High(Encryptors) do
    if Encryptors[i].ID = ID then
      Exit(Encryptors[i]);
  Result := TifsEncryptor;
end;

constructor TInfinityFS.Create;
begin
  FVersion := GetVersion;
  FPathDelim := '/';
end;

procedure TInfinityFS.ChangeFilePassword(const OldPassword, NewPassword: string);
begin
  // verify OldPassword
  // verify NewPassword
  //    if empty, kill encryption
  // update Attribute
end;

procedure TInfinityFS.DoRequirePassword(const FileName: string; var Password: string);
begin
  if Assigned(FOnPassword) then
    FOnPassword(FileName, Password);
end;

function TInfinityFS.GetFullName(const AName: string): string;
begin
  if AName[1] = FPathDelim then
    Result := AName
  else
    Result := FCurFolder + AName;
end;

function TInfinityFS.OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
begin
  Result := TifsFileStream.Create(Self, FileName, Mode);
end;

procedure TInfinityFS.OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead);
begin
  InternalOpenStorage(StorageFile, Mode);
  //todo: Check Compressor and Encryptor;
end;

procedure TInfinityFS.OpenStorage(Stream: TStream);
begin
  InternalOpenStorage(Stream);
  //todo: Check Compressor and Encryptor;
end;

procedure TInfinityFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;

{ TifsFileStream }

constructor TifsFileStream.Create(FS: TInfinityFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
begin
  inherited Create;

  FFileSystem := FS;
  FFileName := FileName;

  FProcessing := False;
  FRawStream := FS.InternalOpenFile(FileName, Mode);
  FAttr := FFileSystem.GetFileAttr(FFileName);
  CheckPassword;
  LoadFromStream(FRawStream);

  Decode;
end;

destructor TifsFileStream.Destroy;
begin
  Encode;
  Flush;

  inherited;
end;

procedure TifsFileStream.CheckPassword;
begin
  if FAttr.IsEncrypted and (FPassword = '') then
    FFileSystem.DoRequirePassword(FFileName, FPassword);
end;

/// <summary>
/// Decode process:
///   Load self to temp
///   Decompress->Decrypt (in temp)
///   Load temp to self
/// </summary>
procedure TifsFileStream.Decode;
var
  tmp: TStream;
begin
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttr.IsCompressed then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FFileSystem.FCompressor.Decompress(tmp);
    end;

    if FAttr.IsEncrypted then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FFileSystem.FEncryptor.Decrypt(tmp, FPassword);
    end;
  finally
    if tmp.Size > 0 then
      LoadFromStream(tmp);
    tmp.Free;
    FProcessing := False;
  end;
end;

/// <summary>
/// Encode process:
///   Load self to temp
///   Encrypt->Compress (in temp)
///   Load temp to self
/// </summary>
procedure TifsFileStream.Encode;
var
  tmp: TStream;
begin
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttr.IsEncrypted then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FFileSystem.FEncryptor.Encrypt(tmp, FPassword);
    end;

    if FAttr.IsCompressed then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FFileSystem.FCompressor.Compress(tmp);
    end;
  finally
    if tmp.Size > 0 then
      LoadFromStream(tmp);
    tmp.Free;
    FProcessing := False;
  end;
end;

procedure TifsFileStream.Flush;
begin
  FRawStream.Size := 0;
  FRawStream.CopyFrom(Self, 0);
  // Update AttributeEx

end;

procedure TifsFileStream.SetPassword(const Value: string);
begin
  if not FProcessing then FPassword := Value;
end;

{ TifsCompressor }

class function TifsCompressor.Compress(Source: TStream): TStream;
begin
  Result := Source;
end;

class function TifsCompressor.Decompress(Source: TStream): TStream;
begin
  Result := Source;
end;

class function TifsCompressor.ID: UInt8;
begin
  ID := $00;
end;

{ TifsEncryptor }

class function TifsEncryptor.Decrypt(Source: TStream; Key: string): TStream;
begin
  Result := Source;
end;

class function TifsEncryptor.Encrypt(Source: TStream; Key: string): TStream;
begin
  Result := Source;
end;

class function TifsEncryptor.ID: UInt8;
begin
  Result := $00;
end;

function TifsFileAttr.IsArchive: Boolean;
begin
  Result := (Attribute and faArchive) <> 0;
end;

function TifsFileAttr.IsCompressed: Boolean;
begin
  Result := (Attribute and faCompressed) <> 0;
end;

function TifsFileAttr.IsDirectory: Boolean;
begin
  Result := (Attribute and faDirectory) <> 0;
end;

function TifsFileAttr.IsEncrypted: Boolean;
begin
  Result := (Attribute and faEncrypted) <> 0;
end;

function TifsFileAttr.IsHidden: Boolean;
begin
  Result := (Attribute and faHidden) <> 0;
end;

function TifsFileAttr.IsReadOnly: Boolean;
begin
  Result := (Attribute and faReadOnly) <> 0;
end;

function TifsFileAttr.IsSymLink: Boolean;
begin
  Result := (Attribute and faSymLink) <> 0;
end;

function TifsFileAttr.IsSysFile: Boolean;
begin
  Result := (Attribute and faSysFile) <> 0;
end;

initialization
  RegisterCompressor(TifsCompressor);
  RegisterEncryptor(TifsEncryptor);

end.


unit IFS.Base;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows, SysUtils, Classes, Generics.Collections,
  AsyncCalls;

const
{ File extended attribute constants }
  faCompressed = $00010000;
  faEncrypted  = $00020000;

type
  /// <summary>
  /// Attributes for IFS.
  /// </summary>
  TifsStorageAttr = record
    Compressor: Byte;
    Encryptor: Byte;
  public
    function CompressorName: string;
    function EncryptorName: string;
  end;

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
  TifsStreamCompressor = class abstract(TObject)
  public
    class procedure Compress(Source, Target: TStream); virtual;
    class function Decompress(Source: TStream): TStream; virtual;
    class function ID: UInt8; virtual; abstract;
    class function Name: string; virtual; abstract;
  end;
  TifsStreamCompressorClass = class of TifsStreamCompressor;

  TifsStreamEncryptor = class abstract(TObject)
  public
    class function Decrypt(Source: TStream; Key: string): TStream; virtual;
    class function Encrypt(Source: TStream; Key: string): TStream; virtual;
    class function ID: UInt8; virtual; abstract;
    class function Name: string; virtual; abstract;
  end;
  TifsStreamEncryptorClass = class of TifsStreamEncryptor;

type
  TTraversalProc = reference to procedure(FileName: string; Attr: TifsFileAttr);

  TRequirePasswordEvent = procedure(FileName: string; var Password: string) of object;

  EInfinityFS = class(Exception);

  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TCustomIFS = class abstract(TObject)
  strict private
    class constructor Create;
  private
    FCurFolder: string;
    FOnRequirePassword: TRequirePasswordEvent;
    FVersion: UInt32;
  protected
    FCompressor: TifsStreamCompressorClass;
    FEncryptor: TifsStreamEncryptorClass;
    FPathDelim: Char;
  class var
    IFS_Reserved_File_Patterns: TList<string>;
    IFS_Reserved_Folder_Patterns: TList<string>;
    procedure CheckCompressor;
    procedure CheckEncryptor;
    procedure DoRequirePassword(const FileName: string; var Password: string);
    function GetFileAttr(const FileName: string): TifsFileAttr; virtual; abstract;
    function GetStorageAttr: TifsStorageAttr; virtual; abstract;
    function GetVersion: UInt32; virtual; abstract;
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual; abstract;
    procedure InternalOpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual; abstract;
    procedure InternalOpenStorage(Stream: TStream); overload; virtual; abstract;
    function IsReservedFile(const FileName: string): Boolean;
    function IsReservedFolder(const FolderName: string): Boolean;
    procedure SetCurFolder(const Value: string); virtual;
    procedure SetFileAttr(const FileName: string; const Value: TifsFileAttr); virtual; abstract;
    procedure SetStorageAttr(const Value: TifsStorageAttr); virtual; abstract;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure ChangeFilePassword(const OldPassword, NewPassword: string); virtual;
    procedure CloseStorage; virtual; abstract;
    procedure CreateFolder(const NewFolderName: string); virtual; abstract;
    procedure ExportFile(const DataFile, LocalFile: string); virtual; abstract;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    function GetFullName(const AName: string): string;
    procedure ImportFile(const LocalFile, DataFile: string); virtual; abstract;
    function IsIFS(const StorageFile: string): Boolean; overload; virtual; abstract;
    function IsIFS(Stream: TStream): Boolean; overload; virtual; abstract;
    function OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual;
    procedure OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual;
    procedure OpenStorage(Stream: TStream); overload; virtual;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property FileAttr[const FileName: string]: TifsFileAttr read GetFileAttr write SetFileAttr;
    property PathDelim: Char read FPathDelim;
    property StorageAttr: TifsStorageAttr read GetStorageAttr write SetStorageAttr;
    property Version: UInt32 read GetVersion;
    property OnRequirePassword: TRequirePasswordEvent read FOnRequirePassword write FOnRequirePassword;
  end;

  TifsFileStream = class(TMemoryStream)
  private
    FAttr: TifsFileAttr;
    FDecodeCall: IAsyncCall;
    FDecodedStream: TStream;
    FEncodeCall: IAsyncCall;
    FFileName: string;
    FMode: UInt16;
    FOwner: TCustomIFS;
    FPassword: string;
    FRawStream: TStream;
    procedure CheckPassword;
    procedure SetPassword(const Value: string); inline;
  protected
    procedure Decode(dummy: Integer = 0); virtual;
    procedure Encode(dummy: Integer = 0); virtual;
    procedure Flush; virtual;
  public
    constructor Create(Owner: TCustomIFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

procedure RegisterCompressor(CompressorClass: TifsStreamCompressorClass);
procedure RegisterEncryptor(EncryptorClass: TifsStreamEncryptorClass);

implementation

uses
  RegExpr;

{$REGION 'Compressors and Encryptors Manager'}
var
  Compressors: array of TifsStreamCompressorClass;
  Encryptors: array of TifsStreamEncryptorClass;

procedure RegisterCompressor(CompressorClass: TifsStreamCompressorClass);
var
  i: Int32;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Compressors[i] := CompressorClass;
end;

procedure RegisterEncryptor(EncryptorClass: TifsStreamEncryptorClass);
var
  i: Int32;
begin
  i := Length(Encryptors);
  SetLength(Encryptors, i+1);
  Encryptors[i] := EncryptorClass;
end;

function FindCompressor(ID: Byte): TifsStreamCompressorClass;
var
  i: Int32;
begin
  if ID = 0 then
    Result := nil
  else
  for i := Low(Compressors) to High(Compressors) do
    if Compressors[i].ID = ID then
      Exit(Compressors[i]);
  raise EInfinityFS.Create('Invalid compressor id.');
end;

function FindEncryptor(ID: Byte): TifsStreamEncryptorClass;
var
  i: Int32;
begin
  if ID = 0 then
    Result := nil
  else
  for i := Low(Encryptors) to High(Encryptors) do
    if Encryptors[i].ID = ID then
      Exit(Encryptors[i]);
  raise EInfinityFS.Create('Invalid encryptor id.');
end;
{$ENDREGION}

{$REGION 'TCustomIFS'}
constructor TCustomIFS.Create;
begin
  FVersion := GetVersion;
  FPathDelim := '/';
end;

class constructor TCustomIFS.Create;
begin
  IFS_Reserved_File_Patterns := TList<string>.Create;
  IFS_Reserved_Folder_Patterns := TList<string>.Create;
end;

destructor TCustomIFS.Destroy;
begin
  FEncryptor := nil;
  FCompressor := nil;

  inherited;
end;

procedure TCustomIFS.AfterConstruction;
begin
  CheckCompressor;
  CheckEncryptor;
end;

procedure TCustomIFS.ChangeFilePassword(const OldPassword, NewPassword: string);
begin
  // verify OldPassword
  // verify NewPassword
  //    if empty, kill encryption
  // update Attribute
end;

procedure TCustomIFS.CheckCompressor;
begin
  FCompressor := FindCompressor(StorageAttr.Compressor);
end;

procedure TCustomIFS.CheckEncryptor;
begin
  FEncryptor := FindEncryptor(StorageAttr.Encryptor);
end;

procedure TCustomIFS.DoRequirePassword(const FileName: string; var Password: string);
begin
  if Assigned(FOnRequirePassword) then
    FOnRequirePassword(FileName, Password);
end;

function TCustomIFS.GetFullName(const AName: string): string;
begin
  if AName[1] = FPathDelim then
    Result := AName
  else
    Result := FCurFolder + AName;
end;

/// <remarks>
/// FileName must be a full name.
/// </remarks>
function TCustomIFS.IsReservedFile(const FileName: string): Boolean;
var
  s: string;
  r: TRegExpr;
begin
  Result := False;
  r := TRegExpr.Create;
  try
    r.ModifierI := True;

    // Test if the file is in reserved folder
    for s in IFS_Reserved_Folder_Patterns do
    begin
      r.Expression := s;
      Result := r.Exec(FileName);
      if Result then
        raise EInfinityFS.Create('File is in reserved folder');
    end;

    // Test if the filename is reserved
    for s in IFS_Reserved_File_Patterns do
    begin
      r.Expression := s;
      Result := r.Exec(FileName);
      if Result then
        raise EInfinityFS.Create('File is reserved');
    end;
  finally
    r.Free;
  end;
end;

function TCustomIFS.IsReservedFolder(const FolderName: string): Boolean;
var
  s: string;
  r: TRegExpr;
begin
  Result := False;
  r := TRegExpr.Create;
  try
    r.ModifierI := True;

    // Test if the folder is reserved
    for s in IFS_Reserved_Folder_Patterns do
    begin
      r.Expression := s;
      Result := r.Exec(FolderName);
      if Result then
        raise EInfinityFS.Create('Folder is reserved');
    end;
  finally
    r.Free;
  end;
end;

function TCustomIFS.OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
var
  fn: string;
begin
  fn := GetFullName(FileName);
  if IsReservedFile(fn) then
    raise EInfinityFS.Create('You cannot open a reserved file, or files in reserved folders.');

  Result := TifsFileStream.Create(Self, fn, Mode);
end;

procedure TCustomIFS.OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead);
begin
  InternalOpenStorage(StorageFile, Mode);
  CheckCompressor;
  CheckEncryptor;
end;

procedure TCustomIFS.OpenStorage(Stream: TStream);
begin
  InternalOpenStorage(Stream);
  CheckCompressor;
  CheckEncryptor;
end;

procedure TCustomIFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;
{$ENDREGION}

{$REGION 'TifsFileStream' }
constructor TifsFileStream.Create(Owner: TCustomIFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
begin
  inherited Create;

  FOwner := Owner;
  FFileName := FileName;
  FMode := Mode;

  FRawStream := Owner.InternalOpenFile(FFileName, FMode);
  FAttr := FOwner.GetFileAttr(FFileName);

  CheckPassword;
  FDecodeCall := AsyncCall(Decode, 0);
end;

destructor TifsFileStream.Destroy;
begin
  Flush;
  
  inherited;
end;

procedure TifsFileStream.CheckPassword;
begin
  if FAttr.IsEncrypted and (FPassword = '') then
    FOwner.DoRequirePassword(FFileName, FPassword);
end;

/// <summary>
/// Decode process:
///   Decompress->Decrypt
/// </summary>
procedure TifsFileStream.Decode(dummy: Integer = 0);
var
  tmp: TStream;
begin
  if FOwner.FCompressor = nil then
    tmp := FRawStream
  else
    tmp := FOwner.FCompressor.Decompress(FRawStream);
      
  if FOwner.FEncryptor = nil then
    FDecodedStream := tmp
  else
    FDecodedStream := FOwner.FEncryptor.Decrypt(tmp, FPassword);

  if FDecodedStream <> tmp then
    tmp.Free;
end;

/// <summary>
/// Encode process:
///   Encrypt->Compress
/// </summary>
procedure TifsFileStream.Encode(dummy: Integer = 0);
var
  tmp: TStream;
begin
  if FOwner.FEncryptor = nil then
    tmp := FDecodedStream
  else
    tmp := FOwner.FEncryptor.Encrypt(FDecodedStream, FPassword);
      
  if FOwner.FCompressor = nil then
  begin
    if FRawStream <> tmp then
    begin
      FRawStream.Size := 0;
      FRawStream.CopyFrom(tmp, 0);
    end;
  end
  else  
    FOwner.FCompressor.Compress(tmp, FRawStream);

  if FRawStream <> tmp then
    tmp.Free;
end;

procedure TifsFileStream.Flush;
begin
  FEncodeCall := AsyncCall(Encode, 0);
  FEncodeCall.Sync;
end;

function TifsFileStream.Read(var Buffer; Count: Longint): Longint;
begin
  repeat until FDecodeCall.Finished;
  Result := inherited;
end;

function TifsFileStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  repeat until FDecodeCall.Finished;
  Result := inherited;
end;

procedure TifsFileStream.SetPassword(const Value: string);
begin
  if FDecodeCall.Finished and ((FEncodeCall = nil) or FEncodeCall.Finished) then
    FPassword := Value;
end;

function TifsFileStream.Write(const Buffer; Count: Longint): Longint;
begin
  repeat until FDecodeCall.Finished;
  Result := inherited;
end;
{$ENDREGION 'TifsFileStream'}

{$REGION 'TifsFileAttr'}
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
{$ENDREGION}

{$REGION 'TifsStorageAttr'}
function TifsStorageAttr.CompressorName: string;
begin
  Result := FindCompressor(Compressor).Name;
end;

function TifsStorageAttr.EncryptorName: string;
begin
  Result := FindEncryptor(Encryptor).Name;
end;
{$ENDREGION 'TifsStorageAttr'}

{$REGION 'TifsStreamCompressor'}
class procedure TifsStreamCompressor.Compress(Source, Target: TStream);
begin
  Source.Position := 0;
  Target.Position := 0;
end;

class function TifsStreamCompressor.Decompress(Source: TStream): TStream;
begin
  Source.Position := 0;
  Result := nil;
end;
{$ENDREGION 'TifsStreamCompressor'}

{$REGION 'TifsStreamEncryptor'}
class function TifsStreamEncryptor.Decrypt(Source: TStream; Key: string): TStream;
begin
  Source.Position := 0;
  Result := nil;
end;

class function TifsStreamEncryptor.Encrypt(Source: TStream; Key: string): TStream;
begin
  Source.Position := 0;
  Result := nil;
end;
{$ENDREGION 'TifsStreamEncryptor'}

end.


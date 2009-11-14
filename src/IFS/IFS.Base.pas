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
  /// <param name="IsCompressed">Whether the file was compressed</param>
  /// <param name="IsEncrypted">Whether the file was encrypted</param>
  TifsFileAttr = record
    Size: Int64;
    CreationTime: TDateTime;
    LastModifyTime: TDateTime;
    LastAccessTime: TDateTime;
    Attribute: UInt32;
  private
    function GetAttrBit(Index: Integer): Boolean;
    procedure SetAttrBit(Index: Integer; const Value: Boolean);
  public
    procedure Init;
    property IsReadOnly: Boolean index 0 read GetAttrBit write SetAttrBit;
    property IsHidden: Boolean index 1 read GetAttrBit write SetAttrBit;
    property IsSysFile: Boolean index 2 read GetAttrBit write SetAttrBit;
    property IsDirectory: Boolean index 4 read GetAttrBit write SetAttrBit;
    property IsArchive: Boolean index 5 read GetAttrBit write SetAttrBit;
    property IsSymLink: Boolean index 6 read GetAttrBit write SetAttrBit;
    property IsCompressed: Boolean index 16 read GetAttrBit write SetAttrBit;
    property IsEncrypted: Boolean index 17 read GetAttrBit write SetAttrBit;
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
    FAfterOpenStorage: TNotifyEvent;
    FBeforeClose: TNotifyEvent;
    FCurFolder: string;
    FOnRequirePassword: TRequirePasswordEvent;
    FVersion: UInt32;
  protected
    FCompressor: TifsStreamCompressorClass;
    FEncryptor: TifsStreamEncryptorClass;
    FPathDelim: Char;
    FStorageAttr: TifsStorageAttr;
    class var
      IFS_Reserved_File_Patterns: TList<string>;
      IFS_Reserved_Folder_Patterns: TList<string>;
    procedure CheckCompressor;
    procedure CheckEncryptor;
    procedure DoAfterOpenStorage; virtual;
    procedure DoBeforeClose; virtual;
    procedure DoRequirePassword(const FileName: string; var Password: string);
    function GetFileAttr(const FileName: string): TifsFileAttr; virtual; abstract;
    procedure GetStorageAttr; virtual; abstract;
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
    procedure CloseStorage; virtual;
    procedure CreateFolder(const NewFolderName: string); virtual; abstract;
    procedure ExportFile(const SrcFile, DstFile: string); virtual;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    function GetFullName(const AName: string): string;
    procedure ImportFile(const SrcFile, DstFile: string); virtual;
    function IsIFS(const StorageFile: string): Boolean; overload; virtual; abstract;
    function IsIFS(Stream: TStream): Boolean; overload; virtual; abstract;
    function OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual;
    procedure OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual;
    procedure OpenStorage(Stream: TStream); overload; virtual;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property FileAttr[const FileName: string]: TifsFileAttr read GetFileAttr write SetFileAttr;
    property PathDelim: Char read FPathDelim;
    property StorageAttr: TifsStorageAttr read FStorageAttr write SetStorageAttr;
    property Version: UInt32 read GetVersion;
    property AfterOpenStorage: TNotifyEvent read FAfterOpenStorage write FAfterOpenStorage;
    property BeforeClose: TNotifyEvent read FBeforeClose write FBeforeClose;
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
    Exit(nil)
  else
  begin
    for i := Low(Compressors) to High(Compressors) do
      if Compressors[i].ID = ID then
        Exit(Compressors[i]);
  end;

  raise EInfinityFS.Create('Invalid compressor id.');
end;

function FindEncryptor(ID: Byte): TifsStreamEncryptorClass;
var
  i: Int32;
begin
  if ID = 0 then
    Exit(nil)
  else
  begin
    for i := Low(Encryptors) to High(Encryptors) do
      if Encryptors[i].ID = ID then
        Exit(Encryptors[i]);
  end;

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

end;

procedure TCustomIFS.ChangeFilePassword(const OldPassword, NewPassword: string);
begin
  //todo: change password
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

procedure TCustomIFS.CloseStorage;
begin
  DoBeforeClose;
end;

procedure TCustomIFS.DoAfterOpenStorage;
begin
  GetStorageAttr;
  CheckCompressor;
  CheckEncryptor;

  if Assigned(FAfterOpenStorage) then FAfterOpenStorage(Self);
end;

procedure TCustomIFS.DoBeforeClose;
begin
  if Assigned(FBeforeClose) then FBeforeClose(Self);
end;

procedure TCustomIFS.DoRequirePassword(const FileName: string; var Password: string);
begin
  if Assigned(FOnRequirePassword) then
    FOnRequirePassword(FileName, Password);
end;

procedure TCustomIFS.ExportFile(const SrcFile, DstFile: string);
var
  src: TStream;
  dst: TFileStream;
begin
  src := InternalOpenFile(DstFile, fmOpenRead);
  dst := TFileStream.Create(SrcFile, fmCreate);
  try
    dst.CopyFrom(src, 0);
  finally
    src.Free;
    dst.Free;
  end;
end;

function TCustomIFS.GetFullName(const AName: string): string;
begin
  if AName[1] = FPathDelim then
    Result := AName
  else
    Result := FCurFolder + AName;
end;

procedure TCustomIFS.ImportFile(const SrcFile, DstFile: string);
var
  src: TFileStream;
  dst: TStream;
begin
  src := TFileStream.Create(SrcFile, fmOpenRead);
  dst := InternalOpenFile(DstFile, fmCreate);
  try
    dst.CopyFrom(src, 0);
  finally
    src.Free;
    dst.Free;
  end;
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
  DoAfterOpenStorage;
end;

procedure TCustomIFS.OpenStorage(Stream: TStream);
begin
  InternalOpenStorage(Stream);
  DoAfterOpenStorage;
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
const
  AttrConsts: array[0..31]of UInt32 =
  //          0            1          2           3            4          5          6         7
    (faReadOnly,    faHidden, faSysFile,          0, faDirectory, faArchive, faSymLink, faNormal,
  //          8
              0,           0,         0,          0,           0,         0,         0,        0,
  //         16           17
   faCompressed, faEncrypted,         0,          0,           0,         0,         0,        0,
  //         24                                                                               31
              0,           0,         0,          0,           0,         0,         0,        0);

procedure TifsFileAttr.Init;
begin
  FillChar(Self, SizeOf(TifsFileAttr), 0);
end;

function TifsFileAttr.GetAttrBit(Index: Integer): Boolean;
begin
  Result := (Attribute and AttrConsts[Index]) <> 0;
end;

procedure TifsFileAttr.SetAttrBit(Index: Integer; const Value: Boolean);
begin
  if Value then
    Attribute := Attribute or AttrConsts[Index]
  else
    Attribute := Attribute xor AttrConsts[Index];
end;
{$ENDREGION 'TifsFileAttr'}

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



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
  TifsStreamAccessor = class(TStream)
  private
  protected
    FAccessorStream: TStream;
    FDecodeCall: IAsyncCall;
    FEncodeCall: IAsyncCall;
    FOriginStream: TStream;
    procedure Decode(dummy: Integer = 0); virtual; abstract;
    procedure Encode(dummy: Integer = 0); virtual; abstract;
    procedure Flush; virtual;
  public
    constructor Create(Source: TStream); virtual;
    destructor Destroy; override;
    class function ID: UInt8; virtual;
    class function Name: string; virtual;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;
  TifsStreamAccessorClass = class of TifsStreamAccessor;

type
  TTraversalProc = reference to procedure(FileName: string; Attr: TifsFileAttr);

  TRequirePasswordEvent = procedure(FileName: string; var Password: string) of object;

  EInfinityFS = class(Exception);

  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TInfinityFS = class abstract(TObject)
  strict private
    class constructor Create;
  private
    FCurFolder: string;
    FOnPassword: TRequirePasswordEvent;
    FVersion: UInt32;
  protected
    FPathDelim: Char;
    class var IFS_Reserved_Files: TList<string>;
    class var IFS_Reserved_Folders: TList<string>;
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
    procedure SetCurFolder(const Value: string); virtual;
    procedure SetFileAttr(const FileName: string; const Value: TifsFileAttr); virtual; abstract;
    procedure SetStorageAttr(const Value: TifsStorageAttr); virtual; abstract;
  public
    constructor Create; virtual;
    destructor Destroy; override;
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
    property OnPassword: TRequirePasswordEvent read FOnPassword write FOnPassword;
  end;

  TifsFileStream = class(TStream)
  private
    FAttr: TifsFileAttr;
    FFileName: string;
    FMode: UInt16;
    FOwner: TInfinityFS;
    FPassword: string;
    FProcessing: Boolean;
    FRawStream: TStream;
    procedure CheckPassword;
    procedure SetPassword(const Value: string); inline;
  protected
    FCompressor: TifsStreamAccessor;
    FEncryptor: TifsStreamAccessor;
  public
    constructor Create(Owner: TInfinityFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

procedure RegisterCompressor(Compressor: TifsStreamAccessorClass);
procedure RegisterEncryptor(Encryptor: TifsStreamAccessorClass);

implementation

uses
  RegExpr;

{$REGION 'Compressors and Encryptors Manager'}
var
  Compressors: array of TifsStreamAccessorClass;
  Encryptors: array of TifsStreamAccessorClass;

procedure RegisterCompressor(Compressor: TifsStreamAccessorClass);
var
  i: Int32;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Compressors[i] := Compressor;
end;

procedure RegisterEncryptor(Encryptor: TifsStreamAccessorClass);
var
  i: Int32;
begin
  i := Length(Encryptors);
  SetLength(Encryptors, i+1);
  Encryptors[i] := Encryptor;
end;

function FindCompressor(ID: Byte): TifsStreamAccessorClass;
var
  i: Int32;
begin
  for i := Low(Compressors) to High(Compressors) do
    if Compressors[i].ID = ID then
      Exit(Compressors[i]);
  raise EInfinityFS.Create('Invalid compressor id.');
//  Result := TifsStreamAccessor;
end;

/// <summary>
/// Encryptor is still in experimental stage. Not ready for use.
/// </summary>
function FindEncryptor(ID: Byte): TifsStreamAccessorClass;
var
  i: Int32;
begin
{
  for i := Low(Encryptors) to High(Encryptors) do
    if Encryptors[i].ID = ID then
      Exit(Encryptors[i]);
}
  raise EInfinityFS.Create('Invalid encryptor id.');
//  Result := TifsStreamAccessor;
end;
{$ENDREGION}

{$REGION 'TInfinityFS'}
constructor TInfinityFS.Create;
begin
  FVersion := GetVersion;
  FPathDelim := '/';
end;

class constructor TInfinityFS.Create;
begin
  IFS_Reserved_Files := TList<string>.Create;
  IFS_Reserved_Folders := TList<string>.Create;
end;

destructor TInfinityFS.Destroy;
begin

  inherited;
end;

procedure TInfinityFS.ChangeFilePassword(const OldPassword, NewPassword: string);
begin
  // verify OldPassword
  // verify NewPassword
  //    if empty, kill encryption
  // update Attribute
end;

procedure TInfinityFS.CheckCompressor;
begin
  // TODO -cMM: TInfinityFS.CheckCompressor default body inserted
end;

procedure TInfinityFS.CheckEncryptor;
begin
  // TODO -cMM: TInfinityFS.CheckEncryptor default body inserted
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

function TInfinityFS.IsReservedFile(const FileName: string): Boolean;
  function EscapeRegxChars(InputString: string): string;
  begin
    Result := StringReplace(InputString, '$', '\$', [rfReplaceAll, rfIgnoreCase]);
    Result := StringReplace(Result, '.', '\.', [rfReplaceAll, rfIgnoreCase]);
  end;
var
  s: string;
  r: TRegExpr;
begin
  Result := False;
  r := TRegExpr.Create;
  try
    r.ModifierI := True;

    // Test if the file is in reserved folder
    for s in IFS_Reserved_Folders do
    begin
      r.Expression := EscapeRegxChars(s) + '/.*';
      Result := r.Exec(FileName);
      if Result then
        raise EInfinityFS.Create('Folder is reserved');
    end;

    // Test if the filename is reserved
    for s in IFS_Reserved_Files do
    begin
      r.Expression := '/.*/' + EscapeRegxChars(s);
      Result := r.Exec(FileName);
      if Result then
        raise EInfinityFS.Create('File is reserved');
    end;
  finally
    r.Free;
  end;
end;

function TInfinityFS.OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
var
  fn: string;
begin
  fn := GetFullName(FileName);
  if IsReservedFile(fn) then
    raise EInfinityFS.Create('You cannot open a reserved file, or files in reserved folders.');

  Result := TifsFileStream.Create(Self, fn, Mode);
end;

procedure TInfinityFS.OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead);
begin
  InternalOpenStorage(StorageFile, Mode);
  CheckCompressor;
  CheckEncryptor;
end;

procedure TInfinityFS.OpenStorage(Stream: TStream);
begin
  InternalOpenStorage(Stream);
  CheckCompressor;
  CheckEncryptor;
end;

procedure TInfinityFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;
{$ENDREGION}

{$REGION 'TifsFileStream' }
constructor TifsFileStream.Create(Owner: TInfinityFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
begin
  inherited Create;

  FOwner := Owner;
  FFileName := FileName;
  FMode := Mode;

  FProcessing := False;
  FRawStream := Owner.InternalOpenFile(FileName, FMode);
  FAttr := FOwner.GetFileAttr(FFileName);

  FCompressor := FindCompressor(FOwner.StorageAttr.Compressor).Create(FRawStream);
  FEncryptor := FindEncryptor(FOwner.StorageAttr.Encryptor).Create(FCompressor);

  CheckPassword;
end;

destructor TifsFileStream.Destroy;
begin
  FEncryptor.Free;
  FCompressor.Free;

  inherited;
end;

procedure TifsFileStream.CheckPassword;
begin
  if FAttr.IsEncrypted and (FPassword = '') then
    FOwner.DoRequirePassword(FFileName, FPassword);
end;

/// <summary>
/// Read(decode) process:
///   Decompress->Decrypt
/// </summary>
function TifsFileStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FEncryptor.Read(Buffer, Count);
end;

procedure TifsFileStream.SetPassword(const Value: string);
begin
  if not FProcessing then FPassword := Value;
end;

/// <summary>
/// Write(encode) process:
///   Encrypt->Compress
/// </summary>
function TifsFileStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FEncryptor.Write(Buffer, Count);
end;

{$ENDREGION}

{$REGION 'TifsStreamAccessor' }
constructor TifsStreamAccessor.Create(Source: TStream);
begin
  FOriginStream := Source;
  FAccessorStream := FOriginStream;
end;

destructor TifsStreamAccessor.Destroy;
begin
  FreeAndNil(FAccessorStream);

  inherited;
end;

procedure TifsStreamAccessor.Flush;
begin
  FEncodeCall := AsyncCall(Encode, 0);
  FEncodeCall.Sync;
end;

class function TifsStreamAccessor.ID: UInt8;
begin
  Result := $00;
end;

class function TifsStreamAccessor.Name: string;
begin
  Result := 'Null';
end;

function TifsStreamAccessor.Read(var Buffer; Count: Longint): Longint;
begin
  repeat until FDecodeCall.Finished;

  Result := FAccessorStream.Read(Buffer, Count);
end;

function TifsStreamAccessor.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  repeat until FDecodeCall.Finished;

  Result := FAccessorStream.Seek(Offset, Origin);
end;

function TifsStreamAccessor.Write(const Buffer; Count: Longint): Longint;
begin
  repeat until FDecodeCall.Finished;

  Result := FAccessorStream.Write(Buffer, Count);
end;
{$ENDREGION}

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
{$ENDREGION}

end.



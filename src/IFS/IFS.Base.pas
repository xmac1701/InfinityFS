unit IFS.Base;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows, SysUtils, Classes, Generics.Collections;

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
  TifsTransportStream = class abstract(TStream)
  protected
    FStream: TStream;
  public
    constructor Create(Source: TStream); virtual;
    class function ID: UInt8; virtual; abstract;
    class function Name: string; virtual; abstract;
  end;
  TifsTransportStreamClass = class of TifsTransportStream;

type
  TTraversalProc = reference to procedure(FileName: string; Attr: TifsFileAttr);

  TRequirePasswordEvent = procedure(FileName: string; var Password: string) of object;

  EInfinityFS = class(Exception);

  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TInfinityFS = class abstract
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
    class constructor Create;
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
    FCompressor: TifsTransportStream;
    FEncryptor: TifsTransportStream;
    procedure Decode;
    procedure Encode;
    procedure Flush;
  public
    constructor Create(Owner: TInfinityFS; const FileName: string; const Mode: UInt16 = fmOpenRead);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

procedure RegisterCompressor(Compressor: TifsTransportStreamClass);
procedure RegisterEncryptor(Encryptor: TifsTransportStreamClass);

implementation

uses
  RegExpr;

{$REGION 'Compressors and Encryptors Manager'}
var
  Compressors: array of TifsTransportStreamClass;
  Encryptors: array of TifsTransportStreamClass;

procedure RegisterCompressor(Compressor: TifsTransportStreamClass);
var
  i: Int32;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Compressors[i] := Compressor;
end;

procedure RegisterEncryptor(Encryptor: TifsTransportStreamClass);
var
  i: Int32;
begin
  i := Length(Encryptors);
  SetLength(Encryptors, i+1);
  Encryptors[i] := Encryptor;
end;

function FindCompressor(ID: Byte): TifsTransportStreamClass;
var
  i: Int32;
begin
  for i := Low(Compressors) to High(Compressors) do
    if Compressors[i].ID = ID then
      Exit(Compressors[i]);
  raise EInfinityFS.Create('Invalid compressor id.');
end;

function FindEncryptor(ID: Byte): TifsTransportStreamClass;
var
  i: Int32;
begin
  for i := Low(Encryptors) to High(Encryptors) do
    if Encryptors[i].ID = ID then
      Exit(Encryptors[i]);
  raise EInfinityFS.Create('Invalid encryptor id.');
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

  FEncryptor := FindEncryptor(FOwner.StorageAttr.Encryptor).Create(FRawStream);
  FCompressor := FindCompressor(FOwner.StorageAttr.Compressor).Create(FEncryptor);

  CheckPassword;
  //LoadFromStream(FRawStream);

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
    FOwner.DoRequirePassword(FFileName, FPassword);
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
{
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttr.IsCompressed then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FOwner.FCompressor.Decompress(tmp);
    end;

    if FAttr.IsEncrypted then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FOwner.FEncryptor.Decrypt(tmp, FPassword);
    end;
  finally
    if tmp.Size > 0 then
      LoadFromStream(tmp);
    tmp.Free;
    FProcessing := False;
  end;
}
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
{
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttr.IsEncrypted then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FOwner.FEncryptor.Encrypt(tmp, FPassword);
    end;

    if FAttr.IsCompressed then
    begin
      if tmp.Size = 0 then
        TMemoryStream(tmp).LoadFromStream(Self);
      tmp := FOwner.FCompressor.Compress(tmp);
    end;
  finally
    if tmp.Size > 0 then
      LoadFromStream(tmp);
    tmp.Free;
    FProcessing := False;
  end;
}
end;

procedure TifsFileStream.Flush;
begin
  FRawStream.Size := 0;
  FRawStream.CopyFrom(Self, 0);
  // Update AttributeEx

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

{$REGION 'TifsTransportStream' }
constructor TifsTransportStream.Create(Source: TStream);
begin
  FStream := Source;
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

initialization
  RegisterCompressor(TifsTransportStream);
  RegisterEncryptor(TifsTransportStream);

end.



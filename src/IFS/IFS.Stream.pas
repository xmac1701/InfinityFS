unit IFS.Stream;

interface

uses
  Classes, Generics.Collections, IFS.Base;

type
  TifsFileStream = class(TMemoryStream)
  private
    FAttrEx: TifsFileAttrEx;
    FFileName: string;
    FFileSystem: TInfinityFS;
    FPassword: string;
    FProcessing: Boolean;
    FRawStream: TStream;
    procedure CheckPassword;
    function GetCompressor: UInt8;
    function GetEncryptor: UInt8;
    procedure SetCompressor(const Value: Byte); inline;
    procedure SetEncryptor(const Value: Byte); inline;
    procedure SetPassword(const Value: string); inline;
  protected
    procedure Decode;
    procedure Encode;
  public
    constructor Create(FS: TInfinityFS; const FileName: string; Stream: TStream);
    destructor Destroy; override;
    property Compressor: Byte read GetCompressor write SetCompressor;
    property Encryptor: Byte read GetEncryptor write SetEncryptor;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

  TifsCompressorClass = class of TifsCompressor;
  TifsCompressor = class
  public
    class function ID: UInt8; virtual;
    class procedure Compress(Source, Target: TStream); virtual;
    class procedure Decompress(Source, Target: TStream); virtual;
  end;

  TifsEncryptorClass = class of TifsEncryptor;
  TifsEncryptor = class
  public
    class function ID: UInt8; virtual;
    class procedure Encrypt(Source, Target: TStream; Key: string); virtual;
    class procedure Decrypt(Source, Target: TStream; Key: string); virtual;
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
  i := Length(Compressors);
  SetLength(Compressors, i+1);
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

{ TifsFileStream }

procedure TifsFileStream.CheckPassword;
begin
  FAttrEx := FFileSystem.GetFileAttrEx(FFileName);
  if (FAttrEx.Encryptor > $00) and (FPassword = '') then
    FFileSystem.OnPassword(FFileName, FPassword);
end;

function TifsFileStream.GetCompressor: UInt8;
begin
  Result := FAttrEx.Compressor;
end;

function TifsFileStream.GetEncryptor: UInt8;
begin
  Result := FAttrEx.Encryptor;
end;

procedure TifsFileStream.SetCompressor(const Value: Byte);
begin
  if not FProcessing then FAttrEx.Compressor := Value;
end;

procedure TifsFileStream.SetEncryptor(const Value: Byte);
begin
  if not FProcessing then FAttrEx.Encryptor := Value;
end;

procedure TifsFileStream.SetPassword(const Value: string);
begin
  if not FProcessing then FPassword := Value;
end;

/// <summary>
/// Decode process:
///   Decompress->Decrypt
/// </summary>
procedure TifsFileStream.Decode;
var
  tmp: TMemoryStream;
begin
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttrEx.Compressor > $00 then
    begin
      if tmp.Size = 0 then
        tmp.LoadFromStream(FRawStream);
      FindCompressor(FAttrEx.Compressor).Decompress(tmp, tmp);
    end;

    if FAttrEx.Encryptor > $00 then
    begin
      if tmp.Size = 0 then
        tmp.LoadFromStream(FRawStream);
      FindEncryptor(FAttrEx.Encryptor).Decrypt(tmp, tmp, FPassword);
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
///   Encrypt->Compress
/// </summary>
procedure TifsFileStream.Encode;
var
  tmp: TMemoryStream;
begin
  FProcessing := True;
  tmp := TMemoryStream.Create;
  try
    if FAttrEx.Encryptor > $00 then
    begin
      if tmp.Size = 0 then
        tmp.LoadFromStream(FRawStream);
      FindEncryptor(FAttrEx.Encryptor).Encrypt(tmp, tmp, FPassword);
    end;

    if FAttrEx.Compressor > $00 then
    begin
      if tmp.Size = 0 then
        tmp.LoadFromStream(FRawStream);
      FindCompressor(FAttrEx.Compressor).Compress(tmp, tmp);
    end;
  finally
    if tmp.Size > 0 then
      LoadFromStream(tmp);
    tmp.Free;
    FProcessing := False;
  end;
end;

constructor TifsFileStream.Create(FS: TInfinityFS; const FileName: string; Stream: TStream);
begin
  inherited Create;

  FProcessing := False;
  FFileSystem := FS;
  FRawStream := Stream;
  FFileName := FileName;

  CheckPassword;
  Decode;
end;

destructor TifsFileStream.Destroy;
begin
  Encode;
  FRawStream.Size := 0;
  FRawStream.CopyFrom(Self, Size);
  inherited;
end;

{ TifsCompressor }

class procedure TifsCompressor.Compress(Source, Target: TStream);
begin
end;

class procedure TifsCompressor.Decompress(Source, Target: TStream);
begin
end;

class function TifsCompressor.ID: UInt8;
begin
  ID := $00;
end;

{ TifsEncryptor }

class procedure TifsEncryptor.Decrypt(Source, Target: TStream; Key: string);
begin
end;

class procedure TifsEncryptor.Encrypt(Source, Target: TStream; Key: string);
begin
end;

class function TifsEncryptor.ID: UInt8;
begin
  Result := $00;
end;

initialization
  RegisterCompressor(TifsCompressor);
  RegisterEncryptor(TifsEncryptor);

end.

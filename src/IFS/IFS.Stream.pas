unit IFS.Stream;

interface

uses
  Classes, Generics.Collections, IFS.Base;

const
  MAX_CODEC_COUNT = 16;

type
  TifsFileStream = class(TMemoryStream)
  private
    FAttrEx: TifsFileAttrEx;
    FPassword: string;
    FProcessing: Boolean;
    FRawStream: TStream;
    function GetCompressor: Byte;
    function GetEncryptor: Byte;
    procedure SetCompressor(const Value: Byte); inline;
    procedure SetEncryptor(const Value: Byte); inline;
    procedure SetPassword(const Value: string); inline;
  protected
    procedure Encode;
    procedure Decode;
  public
    constructor Create(FS: TInfinityFS; RawFileStream: TStream; AttrEx: TifsFileAttrEx);
    destructor Destroy; override;
    property Compressor: Byte read GetCompressor write SetCompressor;
    property Encryptor: Byte read GetEncryptor write SetEncryptor;
    property Password: string read FPassword write SetPassword;
    property RawStream: TStream read FRawStream;
  end;

  TifsCompressorClass = class of TifsCompressor;
  TifsCompressor = class abstract
  public
    class function ID: Byte; virtual; abstract;
    class procedure Compress(Source, Target: TStream); virtual; abstract;
    class procedure Decompress(Source, Target: TStream); virtual; abstract;
  end;

  TifsEncryptorClass = class of TifsEncryptor;
  TifsEncryptor = class abstract
  public
    class function ID: Byte; virtual; abstract;
    class procedure Encrypt(Source, Target: TStream; Key: string); virtual; abstract;
    class procedure Decrypt(Source, Target: TStream; Key: string); virtual; abstract;
  end;

procedure RegisterCompressor(Compressor: TifsCompressorClass);
procedure RegisterEncryptor(Encryptor: TifsEncryptorClass);

implementation

var
  Compressors: array of TifsCompressorClass;
  Encryptors: array of TifsEncryptorClass;

procedure RegisterCompressor(Compressor: TifsCompressorClass);
var
  i: Integer;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Compressors[i] := Compressor;
end;

procedure RegisterEncryptor(Encryptor: TifsEncryptorClass);
var
  i: Integer;
begin
  i := Length(Compressors);
  SetLength(Compressors, i+1);
  Encryptors[i] := Encryptor;
end;

function FindCompressor(ID: Byte): TifsCompressorClass;
var
  i: Integer;
begin
  for i := 1 to Length(Compressors) - 1 do
    if Compressors[i].ID = ID then
      Exit(Compressors[i]);
end;

function FindEncryptor(ID: Byte): TifsEncryptorClass;
var
  i: Integer;
begin
  for i := 1 to Length(Encryptors) - 1 do
    if Encryptors[i].ID = ID then
      Exit(Encryptors[i]);
end;

constructor TifsFileStream.Create(FS: TInfinityFS; RawFileStream: TStream; AttrEx: TifsFileAttrEx);
begin
  inherited Create;

  FProcessing := False;
  FRawStream := RawFileStream;
  FAttrEx := AttrEx;

  Decode;
end;

destructor TifsFileStream.Destroy;
begin
  Encode;
  FRawStream.Size := 0;
  FRawStream.CopyFrom(Self, Size);
  inherited;
end;

/// <summary>
/// Encode process:
///   Encrypt->Compress
/// </summary>
procedure TifsFileStream.Encode;
var
  tmp: TMemoryStream;
  coder: TifsCompressorClass;
begin
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
  end;
end;

/// <summary>
/// Decode process:
///   Decompress->Decrypt
/// </summary>
procedure TifsFileStream.Decode;
var
  tmp: TMemoryStream;
  coder: TifsCompressorClass;
begin
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
  end;
end;

function TifsFileStream.GetCompressor: Byte;
begin
  Result := FAttrEx.Compressor;
end;

function TifsFileStream.GetEncryptor: Byte;
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

initialization
  SetLength(Compressors, 1);
  SetLength(Encryptors, 1);


end.

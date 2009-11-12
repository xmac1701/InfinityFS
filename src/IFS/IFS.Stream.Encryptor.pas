unit IFS.Stream.Encryptor;

interface

uses
  Classes,
  IFS.Base,
  AES;

const
  AESBufferSize = SizeOf(TAESBuffer);

type
  TifsAESEncryptor = class(TifsStreamBridge)
  private
    FKey: string;
  public
    class constructor Create;
    constructor Create(CompressedStream: TStream; Key: string); reintroduce;
    class function ID: Byte; override;
    class function Name: string; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

implementation


{ TifsAESEncryptor }

class constructor TifsAESEncryptor.Create;
begin
  RegisterEncryptor(TifsAESEncryptor);
end;

/// <summary>
/// Encryptor faces to the compressed stream comes from the compressor.
/// </summary>
constructor TifsAESEncryptor.Create(CompressedStream: TStream; Key: string);
begin
  inherited Create(CompressedStream);
  FKey := Key;
end;

class function TifsAESEncryptor.ID: Byte;
begin
  Result := Byte('A');
end;

class function TifsAESEncryptor.Name: string;
begin
  Result := 'AES128';
end;

/// <summary>
/// Read is the decrypt procedure.
/// </summary>
function TifsAESEncryptor.Read(var Buffer; Count: Longint): Longint;
var
  StartPos, EndCount: Int64;
  Offset: Int8;
  tmp: TMemoryStream;
begin
  Result := 0;
  // 1. Decide the buffer to read.
  // if current position not in the start position of any valid AES-buffer, read from the previous buffer-block.
  StartPos := Position;
  Offset := StartPos mod AESBufferSize;
  StartPos := StartPos - Offset;
  // 2. Decide the total size to read.
  // if StartPos+Count cannot cover a entire AES-buffer, extend the EndCount to a AES-buffer's end.
  EndCount := Offset + Count + AESBufferSize - ((Offset + Count) mod AESBufferSize);

  tmp := TMemoryStream.Create;
  try
    // First write the size of total data in byte. This will make AES.DecryptStream happy.
    tmp.Write(EndCount, SizeOf(EndCount));
    tmp.CopyFrom(FStream, EndCount);
    tmp := AES.DecryptStream(tmp, FKey) as TMemoryStream;
    // OK, we got the decrypted stream. Reset position to offset, so we can pass the data that we don't want.
    tmp.Position := Offset;
    // Read the decrypted data to buffer.
    tmp.Read(Buffer, Count);
  finally
    tmp.Free;
  end;  // try
end;

function TifsAESEncryptor.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FStream.Seek(Offset, Origin);
end;

/// <summary>
/// Write is the encrypt procedure.
/// </summary>
function TifsAESEncryptor.Write(const Buffer; Count: Longint): Longint;
begin
  Result := inherited Write(Buffer, Count);
end;

end.

unit IFS.Stream.Encryptor experimental;

interface

uses
  SysUtils, Classes,
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
  StartPos: Int64;  //< The position we can start to read
  EndCount: Int64;  //< The bytes count we should read to decrypt
  Offset: Int8;     //< Offset between StartPos and current FStream.Position
  tmp: TMemoryStream;   //< Temporary stream for decrypt
begin
  StartPos := Position;
  // Correct total bytes we can read.
  if StartPos + Count > Size then
    Count := Size - StartPos;
  // Decide the buffer to read.
  // If current position is in the middle of some valid AES-buffer, set the StartPos to the start of that buffer,
  // and calculate offset.
  Offset := StartPos mod AESBufferSize;
  StartPos := StartPos - Offset;
  // Decide bytes count to read.
  // if StartPos+Count cannot cover an entire AES-buffer, extend the EndCount to that buffer's end.
  EndCount := Offset + Count + AESBufferSize - ((Offset + Count) mod AESBufferSize);

  tmp := TMemoryStream.Create;
  try
    // First write the size of total data in byte to make AES.DecryptStream happy.
    tmp.Write(EndCount, SizeOf(EndCount));
    FStream.Position := StartPos;
    tmp.CopyFrom(FStream, EndCount);
    tmp := AES.DecryptStream(tmp, FKey) as TMemoryStream;
    // OK, we got the decrypted stream. Reset position to offset, so we can ignore the needless data.
    tmp.Position := Offset;
    // Read the decrypted data to buffer.
    Result := tmp.Read(Buffer, Count);
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
var
  OldPos: Int64;
  tmp: TMemoryStream;
  buf: TBytes;
  bufLen: Int64;
begin
  OldPos := FStream.Position;
  // Prepare a buffer for decrypted data. We must write Buffer into it, then encrypt it again. And write back to FStream.
  SetLength(buf, Count);
  bufLen := Read(buf, Count);

end;

end.

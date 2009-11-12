unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base,
  ZLib{, BZip2Ex};

type
  TifsZLibCompressor = class(TifsStreamBridge)
  private
    ZComp: TZCompressionStream;
    ZDecomp: TZDecompressionStream;
  public
    class constructor Create;
    constructor Create(RawFileStream: TStream); override;
    class function ID: Byte; override;
    class function Name: string; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

implementation

{ TifsZLibCompressor }

class constructor TifsZLibCompressor.Create;
begin
  RegisterCompressor(TifsZLibCompressor);
end;

/// <summary>
/// Compressor faces to the raw file stream opened by IFS.
/// </summary>
constructor TifsZLibCompressor.Create(RawFileStream: TStream);
begin
  inherited;
  ZComp := TZCompressionStream.Create(RawFileStream, zcDefault{TZCompressionLevel(Param)});
  ZDecomp := TZDecompressionStream.Create(RawFileStream);
end;

class function TifsZLibCompressor.ID: Byte;
begin
  Result := Byte('Z');
end;

class function TifsZLibCompressor.Name: string;
begin
  Result := 'ZLib';
end;

function TifsZLibCompressor.Read(var Buffer; Count: Longint): Longint;
begin
  Result := ZDecomp.Read(Buffer, Count);
end;

function TifsZLibCompressor.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := ZDecomp.Seek(Offset, Origin);
end;

function TifsZLibCompressor.Write(const Buffer; Count: Longint): Longint;
begin
  Result := ZComp.Write(Buffer, Count);
end;

end.

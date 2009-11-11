unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base,
  ZLib{, BZip2Ex};

type
  TifsZLibCompressor = class(TifsTransportStream)
  public
    constructor Create(Source: TStream); override;
    class function Compress(Source: TStream): TStream;
    class function Decompress(Source: TStream): TStream;
    class function ID: Byte; override;
    class function Name: string; override;
    function Read(var Buffer; Count: Longint): Longint; virtual; abstract;
    function Write(const Buffer; Count: Longint): Longint; virtual; abstract;
  end;

implementation

constructor TifsZLibCompressor.Create(Source: TStream);
begin
  FStream := Source;
end;

class function TifsZLibCompressor.Compress(Source: TStream): TStream;
var
  cmp: TZCompressionStream;
  tmp: TMemoryStream;
begin
  tmp := TMemoryStream.Create;
  cmp := TZCompressionStream.Create(tmp, zcDefault{TZCompressionLevel(Param)});
  cmp.CopyFrom(Source, Source.Size);
  cmp.Free;
  Result := tmp;
end;

class function TifsZLibCompressor.Decompress(Source: TStream): TStream;
var
  decmp: TZDecompressionStream;
  tmp: TMemoryStream;
begin
  tmp := TMemoryStream.Create;
  decmp := TZDecompressionStream.Create(Source);
  tmp.CopyFrom(decmp, 0);
  decmp.Free;
  Result := tmp;
end;

{ TifsZLibCompressor }

class function TifsZLibCompressor.ID: Byte;
begin
  Result := Byte('Z');
end;

class function TifsZLibCompressor.Name: string;
begin
  Result := 'ZLib';
end;

initialization
  RegisterCompressor(TifsZLibCompressor);

end.

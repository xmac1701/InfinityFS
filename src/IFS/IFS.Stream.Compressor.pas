unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base, IFS.Stream,
  ZLib{, BZip2Ex};

type
  TifsZLibCompressor = class(TifsCompressor)
  public
    class function ID: Byte; override;
    class function Compress(Source: TStream): TStream; override;
    class function Decompress(Source: TStream): TStream; override;
  end;

implementation

{ TifsZLibCompressor }

class function TifsZLibCompressor.ID: Byte;
begin
  Result := Byte('Z');
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

initialization
  RegisterCompressor(TifsZLibCompressor);

end.

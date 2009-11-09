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
    class procedure Compress(Source, Target: TStream); override;
    class procedure Decompress(Source, Target: TStream); override;
  end;

implementation

{ TifsZLibCompressor }

class function TifsZLibCompressor.ID: Byte;
begin
  Result := Byte('Z');
end;

class procedure TifsZLibCompressor.Decompress(Source, Target: TStream);
var
  decmp: TZDecompressionStream;
  tmp: TMemoryStream;
begin
  tmp := TMemoryStream.Create;
  decmp := TZDecompressionStream.Create(Source);
  tmp.CopyFrom(decmp, 0);
  decmp.Free;
  Target := tmp;
end;

class procedure TifsZLibCompressor.Compress(Source, Target: TStream);
var
  cmp: TZCompressionStream;
  tmp: TMemoryStream;
begin
  tmp := TMemoryStream.Create;
  cmp := TZCompressionStream.Create(tmp, zcDefault{TZCompressionLevel(Param)});
  cmp.CopyFrom(Source, Source.Size);
  cmp.Free;
  Target := tmp;
end;

initialization
  RegisterCompressor(TifsZLibCompressor);

end.

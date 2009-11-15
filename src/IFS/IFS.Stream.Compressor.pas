unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base,
  BZip2Ex, ZLib;

type
  TifsBZip2Compressor = class(TifsStreamCompressor)
  strict private
    class constructor Create;
  public
    class procedure Compress(Source, Target: TStream); override;
    class function Decompress(Source: TStream): TStream; override;
    class function ID: Byte; override;
    class function Name: string; override;
  end;

  TifsZLibCompressor = class(TifsStreamCompressor)
  strict private
    class constructor Create;
  public
    class procedure Compress(Source, Target: TStream); override;
    class function Decompress(Source: TStream): TStream; override;
    class function ID: Byte; override;
    class function Name: string; override;
  end;

implementation

{ TifsBZip2Compressor }

class constructor TifsBZip2Compressor.Create;
begin
  //RegisterCompressor(TifsBZip2Compressor);
end;

class procedure TifsBZip2Compressor.Compress(Source, Target: TStream);
var
  cmp: TBZCompressionStream;
begin
  inherited;
  cmp := TBZCompressionStream.Create(bs5{TBlockSize100k(Param)}, Target);
  try
    cmp.CopyFrom(Source, Source.Size);
  finally
    cmp.Free;
  end;
end;

class function TifsBZip2Compressor.Decompress(Source: TStream): TStream;
var
  decmp: TBZDecompressionStream;
  tmp: TMemoryStream;
begin
  inherited;
  tmp := TMemoryStream.Create;
  decmp := TBZDecompressionStream.Create(Source);
  try
    tmp.CopyFrom(decmp, 0);
    Result := tmp;
  finally
    decmp.Free;
  end;
end;

class function TifsBZip2Compressor.ID: Byte;
begin
  Result := Byte('B');
end;

class function TifsBZip2Compressor.Name: string;
begin
  Result := 'BZip2';
end;

{ TifsZLibCompressor }

class constructor TifsZLibCompressor.Create;
begin
  //RegisterCompressor(TifsZLibCompressor);
end;

class procedure TifsZLibCompressor.Compress(Source, Target: TStream);
var
  cmp: TZCompressionStream;
begin
  inherited;
  cmp := TZCompressionStream.Create(Target, zcDefault{TZCompressionLevel(Param)});
  try
    cmp.CopyFrom(Source, Source.Size);
  finally
    cmp.Free;
  end;
end;

class function TifsZLibCompressor.Decompress(Source: TStream): TStream;
var
  decmp: TZDecompressionStream;
  tmp: TMemoryStream;
begin
  inherited;
  tmp := TMemoryStream.Create;
  decmp := TZDecompressionStream.Create(Source);
  try
    tmp.CopyFrom(decmp, 0);
    Result := tmp;
  finally
    decmp.Free;
  end;
end;

class function TifsZLibCompressor.ID: Byte;
begin
  Result := Byte('Z');
end;

class function TifsZLibCompressor.Name: string;
begin
  Result := 'ZLib';
end;

initialization
  RegisterCompressor(TifsBZip2Compressor);
  RegisterCompressor(TifsZLibCompressor);

end.


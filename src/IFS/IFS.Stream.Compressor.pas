unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base, IFS.Stream,
  ZLib{, BZip2Ex};

type
  TifsZLibCoder = class(TifsCoder)
  public
    class function CoderID: Byte; override;
    class procedure Encode(Source, Target: TStream; Param: LongInt); override;
    class procedure Decode(Source, Target: TStream; Param: LongInt); override;
  end;

implementation

{ TifsZLibCoder }

class function TifsZLibCoder.CoderID: Byte;
begin
  Result := $01;
end;

class procedure TifsZLibCoder.Decode(Source, Target: TStream; Param: Integer);
var
  decmp: TZDecompressionStream;
begin
  Target := TMemoryStream.Create;
  decmp := TZDecompressionStream.Create(Source);
  Target.CopyFrom(decmp, 0);
  decmp.Free;
end;

class procedure TifsZLibCoder.Encode(Source, Target: TStream; Param: Integer);
var
  cmp: TZCompressionStream;
begin
  Target := TMemoryStream.Create;
  cmp := TZCompressionStream.Create(Target, zcDefault{TZCompressionLevel(Param)});
  cmp.CopyFrom(Source, Source.Size);
  cmp.Free;
end;

initialization
  RegisterCoder(TifsZLibCoder);

end.

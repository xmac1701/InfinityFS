unit IFS.Stream.Compressor;

interface

uses
  Classes,
  IFS.Base,
  ZLib{, BZip2Ex};

type
  TifsZLibCompressor = class(TifsStreamAccessor)
  strict private
    class constructor Create;
  private
    ZComp: TZCompressionStream;
    ZDecomp: TZDecompressionStream;
  protected
    procedure Decode(dummy: Integer = 0); override;
    procedure Encode(dummy: Integer = 0); override;
  public
    constructor Create(Source: TStream); override;
    destructor Destroy; override;
    class function ID: Byte; override;
    class function Name: string; override;
  end;

implementation

uses
  AsyncCalls;

{ TifsZLibCompressor }

class constructor TifsZLibCompressor.Create;
begin
  RegisterCompressor(TifsZLibCompressor);
end;

/// <summary>
/// Compressor faces to the raw file stream opened by IFS.
/// </summary>
constructor TifsZLibCompressor.Create(Source: TStream);
begin
  inherited;

  FAccessorStream := TMemoryStream.Create;
  ZComp := TZCompressionStream.Create(FOriginStream, zcDefault{TZCompressionLevel(Param)});
  ZDecomp := TZDecompressionStream.Create(FOriginStream);

  FDecodeCall := AsyncCall(Decode, 0);
end;

destructor TifsZLibCompressor.Destroy;
begin
  Flush;
  ZComp.Free;
  ZDecomp.Free;

  inherited;
end;

procedure TifsZLibCompressor.Decode(dummy: Integer = 0);
begin
  try
    FAccessorStream.Size := 0;
    FAccessorStream.CopyFrom(ZDecomp, 0);
  except
  end;
end;

procedure TifsZLibCompressor.Encode(dummy: Integer = 0);
begin
  try
    FOriginStream.Size := 0;
    ZComp.CopyFrom(FAccessorStream, 0);
  except
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

end.

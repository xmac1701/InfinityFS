unit IFS.Stream;

interface

uses
  Classes, Generics.Collections;

const
  MAX_CODEC_COUNT = 16;

type
  TifsCodecSequence = array[1..MAX_CODEC_COUNT]of Byte;

  TifsCoderClass = class of TifsCoder;
  TifsCoder = class abstract
  public
    class function CoderID: Byte; virtual; abstract;
    class procedure Encode(Source, Target: TStream; Param: LongInt); virtual; abstract;
    class procedure Decode(Source, Target: TStream; Param: LongInt); virtual; abstract;
  end;

  TifsFileStream = class(TMemoryStream)
  private
    FCodec: TifsCodecSequence;
    FRawStream: TStream;
  protected
    procedure Encode;
    procedure Decode;
  public
    constructor Create(RawFileStream: TStream; Codec: TifsCodecSequence);
    destructor Destroy; override;
    property RawStream: TStream read FRawStream;
  end;

procedure RegisterCoder(Coder: TifsCoderClass);
function CallCoder(CoderID: Byte): TifsCoderClass;

implementation

var
  Coders: array of TifsCoderClass;

procedure RegisterCoder(Coder: TifsCoderClass);
var
  i: Integer;
begin
  i := Length(Coders);
  SetLength(Coders, i+1);
  Coders[i] := Coder;
end;

function CallCoder(CoderID: Byte): TifsCoderClass;
var
  i: Integer;
begin
  for i := 1 to Length(Coders) - 1 do
    if Coders[i].CoderID = CoderID then
      Exit(Coders[i]);
end;

constructor TifsFileStream.Create(RawFileStream: TStream; Codec: TifsCodecSequence);
begin
  inherited Create;

  FRawStream := RawFileStream;
  FCodec := Codec;
  Decode;
end;

destructor TifsFileStream.Destroy;
begin
  Encode;
  FRawStream.Size := 0;
  FRawStream.CopyFrom(Self, Size);
  inherited;
end;

procedure TifsFileStream.Encode;
var
  i: Byte;
  msIn, msOut: TMemoryStream;
  coder: TifsCoderClass;
begin
  msIn := TMemoryStream.Create;
  try
    msIn.LoadFromStream(FRawStream);
    for i:=1 to MAX_CODEC_COUNT do
    begin
      if FCodec[i] = $00 then Continue;    // The first element in codec-func-table is treated as NULL
      msIn.Position := 0;
      coder := CallCoder(FCodec[i]);
      if coder <> nil then
      begin
        CallCoder(FCodec[i]).Encode(msIn, msOut, 0);
        msIn.Free;
        msIn := msOut;
      end;
    end;
  finally
    if Assigned(msOut) then
    begin
      LoadFromStream(msOut);
      msOut.Free;
    end;
  end;
end;

procedure TifsFileStream.Decode;
var
  i: Byte;
  msIn, msOut: TMemoryStream;
  coder: TifsCoderClass;
begin
  msIn := TMemoryStream.Create;
  try
    msIn.LoadFromStream(FRawStream);
    for i:= MAX_CODEC_COUNT downto 1 do
    begin
      if FCodec[i] = $00 then Continue;    // The first element in codec-func-table is treated as NULL
      msIn.Position := 0;
      coder := CallCoder(FCodec[i]);
      if coder <> nil then
      begin
        CallCoder(FCodec[i]).Decode(msIn, msOut, 0);
        msIn.Free;
        msIn := msOut;
      end;
    end;
  finally
    if Assigned(msOut) then
    begin
      LoadFromStream(msOut);
      msOut.Free;
    end;
  end;
end;

initialization
  SetLength(Coders, 1);

end.

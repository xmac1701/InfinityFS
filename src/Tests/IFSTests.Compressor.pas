unit IFSTests.Compressor;

interface

uses
  SysUtils, Classes, TestFramework,
  IFS.Base, IFS.Stream.Compressor;

type
  TTestCompressor = class(TTestCase)
  published
    procedure TestStream;
  end;

implementation

{ TTestCompressor }

procedure TTestCompressor.TestStream;
var
  tmp: TStringStream;
  zc: TifsZLibCompressor;
  buf: TBytes;
  c: Integer;
begin
  buf := BytesOf('AAAABBBBCCCCDDDDAAAABBBBCCCCDDDDAAAABBBBCCCCDDDDAAAABBBBCCCCDDDD');
  tmp := TStringStream.Create;
  //tmp.Write(buf[1], 64);
  zc := TifsZLibCompressor.Create(tmp);
  c := zc.Write(buf, 64);
  CheckEquals(64, c);
  FillChar(buf, 64, 0);
  zc.Position := 0;
  c := zc.Read(buf, 64);
  CheckEquals(64, c);
  CheckEquals('AAAABBBBCCCCDDDDAAAABBBBCCCCDDDDAAAABBBBCCCCDDDDAAAABBBBCCCCDDDD', StringOf(buf));
  tmp.Position := 0;
end;

end.

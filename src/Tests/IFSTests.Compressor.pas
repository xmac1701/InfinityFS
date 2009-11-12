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
  buf := BytesOf('AAAABBBBCCCCDDDD');
  tmp := TStringStream.Create;
  //tmp.Write(buf[1], 16);
  zc := TifsZLibCompressor.Create(tmp);
  c := zc.Write(buf[0], 16);
  CheckEquals(16, c);
  zc.Position := 0;
  FillChar(buf, 16, 0);
  c := zc.Read(buf[0], 16);
  CheckEquals(16, c);
  CheckEquals('AAAABBBBCCCCDDDD', StringOf(buf));
  tmp.Position := 0;
end;

end.

unit IFS.Stream.Encryptor;

interface

uses
  Classes,
  IFS.Base, IFS.Stream,
  AES;

type
  TifsAESCoder = class(TifsCoder)
  public
    class function CoderID: Byte; override;
    class procedure Encode(Source, Target: TStream; Param: LongInt); override;
    class procedure Decode(Source, Target: TStream; Param: LongInt); override;
  end;

implementation

{ TifsAESCoder }

class function TifsAESCoder.CoderID: Byte;
begin
  Result := $11;
end;

class procedure TifsAESCoder.Decode(Source, Target: TStream; Param: Integer);
begin
  Target := AES.DecryptStream(Source, 'ifs');
end;

class procedure TifsAESCoder.Encode(Source, Target: TStream; Param: Integer);
begin
  Target := AES.EncryptStream(Source, 'ifs');
end;

initialization
  RegisterCoder(TifsAESCoder);

end.

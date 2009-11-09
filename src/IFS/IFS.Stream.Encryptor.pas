unit IFS.Stream.Encryptor;

interface

uses
  Classes,
  IFS.Base, IFS.Stream,
  AES;

type
  TifsAESEncryptor = class(TifsEncryptor)
  public
    class function ID: Byte; override;
    class function Encrypt(Source: TStream; Key: string): TStream; override;
    class function Decrypt(Source: TStream; Key: string): TStream; override;
  end;

implementation

{ TifsAESEncryptor }

class function TifsAESEncryptor.ID: Byte;
begin
  Result := Byte('A');
end;

class function TifsAESEncryptor.Decrypt(Source: TStream; Key: string): TStream;
begin
  Result := AES.DecryptStream(Source, Key);
end;

class function TifsAESEncryptor.Encrypt(Source: TStream; Key: string): TStream;
begin
  Result := AES.EncryptStream(Source, Key);
end;

initialization
  RegisterEncryptor(TifsAESEncryptor);

end.

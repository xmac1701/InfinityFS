unit IFS.Stream.Encryptor;

interface

uses
  Classes,
  IFS.Base,
  AES;

type
  TifsAESEncryptor = class(TifsEncryptor)
  public
    class function Decrypt(Source: TStream; Key: string): TStream; override;
    class function Encrypt(Source: TStream; Key: string): TStream; override;
    class function ID: Byte; override;
  end;

implementation

class function TifsAESEncryptor.Decrypt(Source: TStream; Key: string): TStream;
begin
  Result := AES.DecryptStream(Source, Key);
end;

class function TifsAESEncryptor.Encrypt(Source: TStream; Key: string): TStream;
begin
  Result := AES.EncryptStream(Source, Key);
end;

{ TifsAESEncryptor }

class function TifsAESEncryptor.ID: Byte;
begin
  Result := Byte('A');
end;

initialization
  RegisterEncryptor(TifsAESEncryptor);

end.

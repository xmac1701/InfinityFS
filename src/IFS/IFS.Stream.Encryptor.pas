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
    class procedure Encrypt(Source, Target: TStream; Key: string); override;
    class procedure Decrypt(Source, Target: TStream; Key: string); override;
  end;

implementation

{ TifsAESEncryptor }

class function TifsAESEncryptor.ID: Byte;
begin
  Result := Byte('A');
end;

class procedure TifsAESEncryptor.Decrypt(Source, Target: TStream; Key: string);
begin
  Target := AES.DecryptStream(Source, Key);
end;

class procedure TifsAESEncryptor.Encrypt(Source, Target: TStream; Key: string);
begin
  Target := AES.EncryptStream(Source, Key);
end;

initialization
  RegisterEncryptor(TifsAESEncryptor);

end.

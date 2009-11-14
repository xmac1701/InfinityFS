unit IFS.Stream.Encryptor;

interface

uses
  SysUtils, Classes,
  IFS.Base,
  AES;

type
  TifsAESEncryptor = class(TifsStreamEncryptor)
  strict private
    class constructor Create;
  public
    class function Decrypt(Source: TStream; Key: string): TStream; override;
    class function Encrypt(Source: TStream; Key: string): TStream; override;
    class function ID: Byte; override;
    class function Name: string; override;
  end;

implementation

{ TifsAESEncryptor }

class constructor TifsAESEncryptor.Create;
begin
  RegisterEncryptor(TifsAESEncryptor);
end;

class function TifsAESEncryptor.Decrypt(Source: TStream; Key: string): TStream;
begin
  inherited;
  Result := AES.DecryptStream(Source, Key);
end;

class function TifsAESEncryptor.Encrypt(Source: TStream; Key: string): TStream;
begin
  inherited;
  Result := AES.EncryptStream(Source, Key);
end;

class function TifsAESEncryptor.ID: Byte;
begin
  Result := Byte('A');
end;

class function TifsAESEncryptor.Name: string;
begin
  Result := 'AES';
end;

end.


unit IFS.Stream.Encryptor;

interface

uses
  Classes,
  IFS.Base,
  AES;

type
  TifsAESEncryptor = class(TifsTransportStream)
  public
    class function Decrypt(Source: TStream; Key: string): TStream;
    class function Encrypt(Source: TStream; Key: string): TStream;
    class function ID: Byte; override;
    class function Name: string; override;
    function Read(var Buffer; Count: Longint): Longint; virtual; abstract;
    function Write(const Buffer; Count: Longint): Longint; virtual; abstract;
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

class function TifsAESEncryptor.Name: string;
begin
  Result := 'AES128';
end;

initialization
  RegisterEncryptor(TifsAESEncryptor);

end.

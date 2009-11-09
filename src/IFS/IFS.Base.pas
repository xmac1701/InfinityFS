unit IFS.Base;

interface

uses
  Windows, SysUtils, Classes;

type
  /// <summary>
  /// Basic attributes for files in IFS.
  /// </summary>
  /// <param name="Size">Size of the file</param>
  /// <param name="Attribute"></param>
  TifsFileAttr = record
    Size: Int64;
    Attribute: UInt32;
    CreationTime: TDateTime;
    LastWriteTime: TDateTime;
    LastAccessTime: TDateTime;
  end;

  /// <summary>
  /// Extended attributes for files in IFS.
  /// </summary>
  /// <param name="Compressor">Indicate the compress method</param>
  /// <param name="Encryptor">Indicate the encrypt method</param>
  /// <param name="Description">A short info for the file</param>
  TifsFileAttrEx = record
    Compressor: UInt8;
    Encryptor: UInt8;
    Description: ShortString;
  end;

  TTraversalProc = reference to procedure(FileName: string; Attr: TifsFileAttr);
  TPasswordRequiredEvent = procedure(FileName: string; var Password: string) of object;

type
  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TInfinityFS = class abstract
  private
    FCurFolder: string;
    FOnPassword: TPasswordRequiredEvent;
    FPathDelim: Char;
    FVersion: UInt32;
  protected
    function GetVersion: UInt32; virtual; abstract;
    function InternalOpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream; virtual; abstract;
    procedure SetCurFolder(const Value: string); virtual;
  public
    constructor Create; virtual;
    procedure CloseStorage; virtual; abstract;
    procedure CreateFolder(const NewFolderName: string); virtual; abstract;
    procedure ExportFile(const DataFile, LocalFile: string); virtual; abstract;
    procedure FileTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    procedure FolderTraversal(const Folder: string; Callback: TTraversalProc); virtual; abstract;
    function GetFileAttr(const FileName: string): TifsFileAttr; virtual; abstract;
    function GetFileAttrEx(const FileName: string): TifsFileAttrEx; virtual; abstract;
    function GetFullName(const AName: string): string; inline;
    procedure ImportFile(const LocalFile, DataFile: string); virtual; abstract;
    function IsIFS(const StorageFile: string): Boolean; overload; virtual; abstract;
    function IsIFS(Stream: TStream): Boolean; overload; virtual; abstract;
    function OpenFile(const FileName: string; Mode: Word = fmOpenRead): TStream; virtual;
    procedure OpenStorage(const StorageFile: string; Mode: UInt16 = fmOpenRead); overload; virtual; abstract;
    procedure OpenStorage(Stream: TStream); overload; virtual; abstract;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property PathDelim: Char read FPathDelim default '/';
    property Version: UInt32 read GetVersion;
    property OnPassword: TPasswordRequiredEvent read FOnPassword write FOnPassword;
  end;

implementation

uses
  IFS.Stream;

constructor TInfinityFS.Create;
begin
  FVersion := GetVersion;
  FPathDelim := '/';
end;

function TInfinityFS.GetFullName(const AName: string): string;
begin
  if AName[1] = FPathDelim then
    Result := AName
  else
    Result := FCurFolder + Result;
end;

function TInfinityFS.OpenFile(const FileName: string; Mode: UInt16 = fmOpenRead): TStream;
begin
  Result := TifsFileStream.Create(Self, FileName, InternalOpenFile(FileName, Mode));
end;

procedure TInfinityFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;

end.

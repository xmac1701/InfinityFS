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
  /// <param name="StreamCodec">Indicates how to decode this stream.<para/>
  /// Each byte indicates a codec registered in codec-list.</param>
  TifsFileAttrEx = record
    StreamCodec: array[0..15]of Byte;
    Description: ShortString;
  end;

  TTraversalProc = reference to procedure(AFileName: string; Attr: TifsFileAttr);

type
  /// <summary>
  /// Base class definition of Infinity File System.
  /// </summary>
  TInfinityFS = class abstract
  private
    FCurFolder: string;
    FPathDelim: Char;
    FVersion: string;
    function GetVersion: string; virtual; abstract;
  protected
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
    function OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream; virtual; abstract;
    procedure OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite); overload; virtual; abstract;
    procedure OpenStorage(Stream: TStream); overload; virtual; abstract;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property PathDelim: Char read FPathDelim default '/';
    property Version: string read GetVersion;
  end;

implementation

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

procedure TInfinityFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;

end.

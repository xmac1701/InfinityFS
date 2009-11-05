unit IFS.Base;

interface

uses
  Windows, SysUtils, Classes;

type
  TTraversalProc = reference to procedure(AFolderName: string);

  TInfinityFS = class abstract
  private
    FCurFolder: string;
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
    procedure ImportFile(const LocalFile, DataFile: string); virtual; abstract;
    function IsIFS(const StorageFile: string): Boolean; overload; virtual; abstract;
    function IsIFS(Stream: TStream): Boolean; overload; virtual; abstract;
    function OpenFile(const FileName: string; Mode: Word = fmOpenReadWrite): TStream; virtual; abstract;
    procedure OpenStorage(const StorageFile: string; Mode: Word = fmOpenReadWrite); overload; virtual; abstract;
    procedure OpenStorage(Stream: TStream); overload; virtual; abstract;
    property CurFolder: string read FCurFolder write SetCurFolder;
    property Version: string read GetVersion;
  end;

implementation

constructor TInfinityFS.Create;
begin
  FVersion := GetVersion;
end;

procedure TInfinityFS.SetCurFolder(const Value: string);
begin
  FCurFolder := Value;
end;

end.

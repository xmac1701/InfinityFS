unit ufmIFSEMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, CITreeView, StdCtrls, RzCmboBx, RzButton, ExtCtrls, RzPanel, ImgList, Menus;

type
  TfmIFSEMain = class(TForm)
    RzToolbar1: TRzToolbar;
    RzToolButton1: TRzToolButton;
    RzToolButton2: TRzToolButton;
    lvFile: TListView;
    Splitter1: TSplitter;
    dlgOpen: TOpenDialog;
    imgFolderView: TImageList;
    tvFolder: TCITreeView;
    RzToolButton3: TRzToolButton;
    pmListView: TPopupMenu;
    AddFile1: TMenuItem;
    procedure AddFile1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RzToolButton1Click(Sender: TObject);
    procedure RzToolButton2Click(Sender: TObject);
    procedure RzToolButton3Click(Sender: TObject);
    procedure tvFolderChange(Sender: TObject; Node: TTreeNode);
    procedure tvFolderDeletion(Sender: TObject; Node: TTreeNode);
    procedure tvFolderExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
  private
    FCurFolderNode: TTreeNode;
    function PathFromNode(Node: TTreeNode): string;
  public
    procedure AddFolderNode(ParentNode: TTreeNode; const Folder: string);
    procedure InitFolderTree;
    procedure LoadFolder(FolderNode: TTreeNode; const Folder: string);
    procedure ShowFolder(const Folder: string);
  end;

var
  fmIFSEMain: TfmIFSEMain;

implementation

{$R *.dfm}

uses
  IFS.GSS;

var
  stg: TIFS_GSS;

procedure TfmIFSEMain.AddFile1Click(Sender: TObject);
begin
  if dlgOpen.Execute then
  begin
    stg.ImportFile(dlgOpen.FileName, stg.CurFolder+ExtractFileName(dlgOpen.FileName));
  end;
end;

procedure TfmIFSEMain.AddFolderNode(ParentNode: TTreeNode; const Folder: string);
var
  n: TTreeNode;
begin
  n := tvFolder.Items.AddChild(ParentNode, Folder);
  n.ImageIndex := 1;
  n.SelectedIndex := 1;
  tvFolder.Items.AddChild(n, 'Loading...').ImageIndex := -1;
end;

procedure TfmIFSEMain.FormCreate(Sender: TObject);
begin
  stg := TIFS_GSS.Create;
end;

procedure TfmIFSEMain.InitFolderTree;
begin
  tvFolder.Items.Clear;
  tvFolder.Items.Add(nil, '/');
end;

procedure TfmIFSEMain.LoadFolder(FolderNode: TTreeNode; const Folder: string);
begin
  //Attention: Folder must be a full-path.
  //todo: CheckLoaded(FolderNode);
  //ShowMessage(Folder);
  FolderNode.DeleteChildren;
  stg.FolderTraversal(
                      Folder,
                      procedure(s: string)
                      begin
                        AddFolderNode(FolderNode, s);
                      end
                     );
end;

function TfmIFSEMain.PathFromNode(Node: TTreeNode): string;
begin
  Result := '';
  if (Node <> nil) and (Node.Parent <> nil) then
  begin
    Result := Node.Text + tvFolder.PathDelimiter;
    while Node.Parent.AbsoluteIndex <> 0 do
    begin
      Node := Node.Parent;
      Result := Node.Text + tvFolder.PathDelimiter + Result;
    end;
  end;
  Result := '/' + Result;
end;

procedure TfmIFSEMain.RzToolButton1Click(Sender: TObject);
begin
  if dlgOpen.Execute then
  begin
    InitFolderTree;
    stg.CloseStorage;
    if not FileExists(dlgOpen.FileName) then
      stg.OpenStorage(dlgOpen.FileName, fmCreate)
    else
      stg.OpenStorage(dlgOpen.FileName, fmOpenReadWrite);
    LoadFolder(tvFolder.Items[0], '/');
  end;
end;

procedure TfmIFSEMain.RzToolButton2Click(Sender: TObject);
var
  s: string;
begin
  if InputQuery('New Folder', 'Folder Name', s) then
  begin
    stg.CreateFolder(s);
    AddFolderNode(FCurFolderNode, s);
  end;
end;

procedure TfmIFSEMain.RzToolButton3Click(Sender: TObject);
begin
  stg.CloseStorage;
end;

procedure TfmIFSEMain.ShowFolder(const Folder: string);
begin
  lvFile.Items.Clear;
  stg.FileTraversal(
                    Folder,
                    procedure(s: string)
                    begin
                      lvFile.Items.Add.Caption := s;
                    end
                   );
end;

procedure TfmIFSEMain.tvFolderChange(Sender: TObject; Node: TTreeNode);
begin
  FCurFolderNode := tvFolder.Selected;
  stg.CurFolder := PathFromNode(FCurFolderNode);
  ShowFolder(stg.CurFolder);
end;

procedure TfmIFSEMain.tvFolderDeletion(Sender: TObject; Node: TTreeNode);
begin
  //todo: Free Node.Data;
end;

procedure TfmIFSEMain.tvFolderExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
begin
  if (Node.HasChildren) and (Node.Item[0].ImageIndex = -1) then
  LoadFolder(Node, PathFromNode(Node));

end;

end.

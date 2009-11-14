unit IFSExplorer.MainForm;

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
    ExportFile1: TMenuItem;
    dlgSave: TSaveDialog;
    GetAttrs1: TMenuItem;
    Panel1: TPanel;
    cboAddress: TComboBox;
    procedure AddFile1Click(Sender: TObject);
    procedure ExportFile1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure GetAttrs1Click(Sender: TObject);
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
  // defaul for InvertCase property

    procedure InitFolderTree;
    procedure LoadFolder(FolderNode: TTreeNode; const Folder: string);
    procedure ShowFolder(const Folder: string);
  end;

var
  fmIFSEMain: TfmIFSEMain;

implementation

{$R *.dfm}

uses
  GpStructuredStorage, RegExpr,
  IFS.Base, IFS.GSS, IFSExplorer.Global;


var
  stg: TifsGSS;

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

procedure TfmIFSEMain.ExportFile1Click(Sender: TObject);
begin
  if lvFile.Selected = nil then Exit;

  if dlgSave.Execute then
    stg.ExportFile(lvFile.Selected.Caption, dlgSave.FileName);
end;

procedure TfmIFSEMain.FormCreate(Sender: TObject);
var
  rex: TRegExpr;
begin
  stg := TifsGSS.Create;
  rex := TRegExpr.Create;
{
  IFS_Reserved_Folder_Patterns.Add('/\$IFS\$');         // $IFS$

  IFS_Reserved_File_Patterns.Add('/.*/\$IFS\$/\.ifsStorageAttr/.*/');   // .ifsStorageAttr
  IFS_Reserved_File_Patterns.Add('/.*/\$IFS\$/\.ifsFileAttr/.*/');      // .ifsFileAttr
}
  if ExecRegExpr('/\$IFS\$', '/$IFS$') then
    Caption := '1';
end;

procedure TfmIFSEMain.GetAttrs1Click(Sender: TObject);
var
  fi: IGpStructuredFileInfo;
  attrs: TStringList;
  s: string;
begin
  fi := stg.Intf.FileInfo[stg.CurFolder+lvfile.Selected.Caption];
  attrs := TStringList.Create;
  fi.AttributeNames(attrs);
  Log(IntToStr(attrs.Count));
  for s in attrs do
    Log(s+#9+fi.Attribute[s]);
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
                      procedure(s: string; attr: TifsFileAttr)
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
                    procedure(s: string; attr: TifsFileAttr)
                    begin
                      lvFile.Items.Add.Caption := s;
                    end
                   );
end;

procedure TfmIFSEMain.tvFolderChange(Sender: TObject; Node: TTreeNode);
begin
  FCurFolderNode := tvFolder.Selected;
  stg.CurFolder := PathFromNode(FCurFolderNode);
  cboAddress.Text := stg.CurFolder;
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

unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ImgList;

type
  TFmSimpleReplace = class(TForm)
    BtGo: TButton;
    BtSelectDirectory: TButton;
    CbxCaseInsensitivity: TCheckBox;
    CbxConfirmation: TCheckBox;
    CbxReplaceText: TCheckBox;
    CbxSubfolders: TCheckBox;
    CmbFileType: TComboBox;
    CmbFolder: TComboBox;
    CmbReplaceText: TComboBox;
    CmbSearchText: TComboBox;
    GbxSearchContext: TGroupBox;
    GbxText: TGroupBox;
    ImageList: TImageList;
    LbFileType: TLabel;
    LbFolder: TLabel;
    LblSearchText: TLabel;
    ProgressBar: TProgressBar;
    StatusBar: TStatusBar;
    TvwResults: TTreeView;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure TvwResultsAdvancedCustomDrawItem(Sender: TCustomTreeView;
      Node: TTreeNode; State: TCustomDrawState; Stage: TCustomDrawStage;
      var PaintImages, DefaultDraw: Boolean);
    procedure BtGoClick(Sender: TObject);
    procedure BtSelectDirectoryClick(Sender: TObject);
    procedure CmbFolderChange(Sender: TObject);
    procedure CmbSearchTextChange(Sender: TObject);
    procedure CmbSearchTextKeyPress(Sender: TObject; var Key: Char);
    procedure CmbReplaceTextKeyPress(Sender: TObject; var Key: Char);
  private
    FIniFileName: TFileName;
    FGlobalLineCount: Integer;
    procedure CheckGoPossible;
    procedure UpdateComboBoxes;
  public
    procedure ProcessFile(FileName: TFileName);
  end;

var
  FmSimpleReplace: TFmSimpleReplace;

implementation

{$R *.dfm}

uses
  FileCtrl, Inifiles;

function GetNextExtension(var FileMask: string): string;
var
  DelimiterPos: Integer;
begin
  DelimiterPos := Pos(';', FileMask);
  if DelimiterPos = 0 then
  begin
    Result := Trim(FileMask);
    FileMask := '';
  end
  else
  begin
    Result := Trim(Copy(FileMask, 1, DelimiterPos - 1));
    Delete(FileMask, 1, DelimiterPos);
  end;
end;

function LowerCaseFileMask(FileName: TFileName): TFileName;
begin
  Result := '*' + LowerCase(ExtractFileExt(FileName));
end;

procedure FindFiles(FilesList: TStringList; StartDir, FileMask: string);
var
  SR     : TSearchRec;
  DirList: TStringList;
  Index  : Integer;
  Temp   : string;
  CurMask: string;
const
  COptions: Integer = FaAnyFile - FaDirectory;
begin
  if StartDir[Length(StartDir)] <> '\' then
    StartDir := StartDir + '\';

  Temp := FileMask;
  repeat
    CurMask := GetNextExtension(Temp);
    if (CurMask <> '') and (FindFirst(StartDir + CurMask, COptions, SR) = 0)
    then
      try
        repeat
          if LowerCaseFileMask(StartDir + SR.Name) = LowerCase(CurMask) then
            FilesList.Add(StartDir + SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
  until Temp = '';

  // Build a list of subdirectories
  DirList := TStringList.Create;
  try
    if FindFirst(StartDir + '*.*', FaAnyFile, SR) = 0 then
      try
        repeat
          if ((SR.Attr and FaDirectory) <> 0) and (SR.Name[1] <> '.') then
            DirList.Add(StartDir + SR.Name);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;

    // Scan the list of subdirectories
    for index := 0 to DirList.Count - 1 do
      FindFiles(FilesList, DirList[index], FileMask);
  finally
    FreeAndNil(DirList);
  end;
end;


{ TFmSimpleReplace }

procedure TFmSimpleReplace.FormCreate(Sender: TObject);
begin
  FIniFileName := ChangeFileExt(ParamStr(0), '.ini');
end;

procedure TFmSimpleReplace.FormShow(Sender: TObject);
var
  Index: Integer;
  ItemNames: TStringList;
  RecentString: string;
begin
  with TIniFile.Create(FIniFileName) do
    try
      ItemNames := TStringList.Create;
      try
        ReadSection('Recent Search Text', ItemNames);
        for Index := 0 to ItemNames.Count - 1 do
        begin
          RecentString := ReadString('Recent Search Text', ItemNames[Index], '');
          if RecentString <> '' then
            CmbSearchText.Items.Add(RecentString);
        end;

        ReadSection('Recent Replace Text', ItemNames);
        for Index := 0 to ItemNames.Count - 1 do
        begin
          RecentString := ReadString('Recent Replace Text', ItemNames[Index], '');
          if RecentString <> '' then
            CmbReplaceText.Items.Add(RecentString);
        end;

        ReadSection('Recent Folders', ItemNames);
        for Index := 0 to ItemNames.Count - 1 do
        begin
          RecentString := ReadString('Recent Folders', ItemNames[Index], '');
          if RecentString <> '' then
            CmbFolder.Items.Add(RecentString);
        end;

        ReadSection('Recent File Type', ItemNames);
        if ItemNames.Count > 0 then
          CmbFileType.Items.Clear;

        for Index := 0 to ItemNames.Count - 1 do
        begin
          RecentString := ReadString('Recent File Type', ItemNames[Index], '');
          if RecentString <> '' then
            CmbFileType.Items.Add(RecentString);
        end;
      finally
        FreeAndNil(ItemNames);
      end;

      CmbSearchText.Text := ReadString('Recent', 'Search Text',
        CmbSearchText.Text);
      CmbReplaceText.Text := ReadString('Recent', 'Replace Text',
        CmbReplaceText.Text);
      CmbFolder.Text := ReadString('Recent', 'Folder', CmbFolder.Text);
      CmbFileType.Text := ReadString('Recent', 'File Type', CmbFileType.Text);

      CbxReplaceText.Checked := ReadBool('Settings', 'Replace Text',
        CbxReplaceText.Checked);
      CbxCaseInsensitivity.Checked := ReadBool('Settings',
        'Case Insensitivity', CbxCaseInsensitivity.Checked);
      CbxConfirmation.Checked := ReadBool('Settings', 'Confirmation',
        CbxConfirmation.Checked);
      CbxSubfolders.Checked := ReadBool('Settings', 'Subfolders',
        CbxSubfolders.Checked);
    finally
      Free;
    end;

  CheckGoPossible;
end;

procedure TFmSimpleReplace.FormClose(Sender: TObject; var Action: TCloseAction);
var
  Index: Integer;
begin
  with TIniFile.Create(FIniFileName) do
    try
      EraseSection('Recent Search Text');
      for Index := 1 to CmbSearchText.Items.Count do
      begin
        WriteString('Recent Search Text', 'Item #' + IntToStr(Index),
          CmbSearchText.Items[Index]);
      end;

      EraseSection('Recent Replace Text');
      for Index := 1 to CmbReplaceText.Items.Count do
      begin
        WriteString('Recent Replace Text', 'Item #' + IntToStr(Index),
          CmbReplaceText.Items[Index]);
      end;

      EraseSection('Recent Folders');
      for Index := 1 to CmbFolder.Items.Count do
      begin
        WriteString('Recent Folders', 'Item #' + IntToStr(Index),
          CmbFolder.Items[Index]);
      end;

      EraseSection('Recent File Type');
      for Index := 1 to CmbFileType.Items.Count do
      begin
        WriteString('Recent File Type', 'Item #' + IntToStr(Index),
          CmbFileType.Items[Index]);
      end;

      WriteString('Recent', 'Search Text', CmbSearchText.Text);
      WriteString('Recent', 'Replace Text', CmbReplaceText.Text);
      WriteString('Recent', 'Folder', CmbFolder.Text);
      WriteString('Recent', 'File Type', CmbFileType.Text);

      WriteBool('Settings', 'Replace Text', CbxReplaceText.Checked);
      WriteBool('Settings', 'Case Insensitivity', CbxCaseInsensitivity.Checked);
      WriteBool('Settings', 'Confirmation', CbxConfirmation.Checked);
      WriteBool('Settings', 'Subfolders', CbxSubfolders.Checked);
    finally
      Free;
    end;
end;

procedure TFmSimpleReplace.ProcessFile(FileName: TFileName);
var
  Current      : TStringList;
  SearchText   : string;
  CompareString: string;
  LineIndex    : Integer;
  ReplaceFlags : TReplaceFlags;
  Node         : TTreeNode;
begin
  if CbxCaseInsensitivity.Checked then
    SearchText := CmbSearchText.Text
  else
    SearchText := LowerCase(CmbSearchText.Text);

  ReplaceFlags := [rfReplaceAll];
  if not CbxCaseInsensitivity.Checked then
    ReplaceFlags := ReplaceFlags + [rfIgnoreCase];

  Node := nil;
  with TStringList.Create do
    try
      LoadFromFile(FileName);

      for LineIndex := 0 to Count - 1 do
      begin
        if CbxCaseInsensitivity.Checked then
          CompareString := Strings[LineIndex]
        else
          CompareString := LowerCase(Strings[LineIndex]);

        if Pos(SearchText, CompareString) > 0 then
        begin
          if Node = nil then
          begin
            Node := TvwResults.Items.AddChild(nil, FileName);
            Node.ImageIndex := 0;
            Node.SelectedIndex := 0;
          end;

          if CbxReplaceText.Checked then
          begin
            Strings[LineIndex] := StringReplace(Strings[LineIndex], SearchText,
              CmbReplaceText.Text, ReplaceFlags);
          end;

          with TvwResults.Items.AddChild(Node, '  ' + IntToStr(LineIndex) + ': '
            + Strings[LineIndex]) do
          begin
            ImageIndex := 1;
            SelectedIndex := 1;
            Inc(FGlobalLineCount);
          end;
          if CbxConfirmation.Checked then
            Node.Expand(True);

(*
          if CbxConfirmation.Checked then
            case MessageDlg('Replace current text', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
              mrYes : Strings[LineIndex] := CompareString;
              mrCancel: Exit;
            end
          else
            Strings[LineIndex] := CompareString;
*)
        end;

      end;
      if CbxReplaceText.Checked and Assigned(Node) then
        SaveToFile(FileName);
    finally
      Free;
    end;
end;

procedure TFmSimpleReplace.TvwResultsAdvancedCustomDrawItem
  (Sender: TCustomTreeView; Node: TTreeNode; State: TCustomDrawState;
  Stage: TCustomDrawStage; var PaintImages, DefaultDraw: Boolean);
begin
  with Sender.Canvas do
    if Node.Level = 0 then
      Font.Style := Font.Style + [FsBold]
    else
      Font.Style := Font.Style - [FsBold];
end;

procedure TFmSimpleReplace.UpdateComboBoxes;
begin
  if CmbSearchText.Items.IndexOf(CmbSearchText.Text) < 0 then
  begin
    CmbSearchText.Items.Insert(0, CmbSearchText.Text);
    if CmbSearchText.Items.Count > 9 then
      CmbSearchText.Items.Delete(9);
  end;

  if CmbReplaceText.Items.IndexOf(CmbReplaceText.Text) < 0 then
  begin
    CmbReplaceText.Items.Insert(0, CmbReplaceText.Text);
    if CmbReplaceText.Items.Count > 9 then
      CmbReplaceText.Items.Delete(9);
  end;

  if CmbFolder.Items.IndexOf(CmbFolder.Text) < 0 then
  begin
    CmbFolder.Items.Insert(0, CmbFolder.Text);
    if CmbFolder.Items.Count > 9 then
      CmbFolder.Items.Delete(9);
  end;

  if CmbFileType.Items.IndexOf(CmbFileType.Text) < 0 then
  begin
    CmbFileType.Items.Insert(0, CmbFileType.Text);
    if CmbFileType.Items.Count > 9 then
      CmbFileType.Items.Delete(9);
  end;
end;

procedure TFmSimpleReplace.BtGoClick(Sender: TObject);
var
  FilesList: TStringList;
  FileIndex: Integer;
begin
  TvwResults.Items.Clear;
  ProgressBar.Position := 0;
  FGlobalLineCount := 0;

  UpdateComboBoxes;

  FilesList := TStringList.Create;
  try
    FindFiles(FilesList, CmbFolder.Text, CmbFileType.Text);

    ProgressBar.Max := FilesList.Count;
    for FileIndex := 0 to FilesList.Count - 1 do
    begin
      ProcessFile(FilesList[FileIndex]);
      ProgressBar.StepIt;
    end;
  finally
    FreeAndNil(FilesList);
  end;

  StatusBar.Panels[0].Text := 'Line Count: ' + IntToStr(FGlobalLineCount);
end;

procedure TFmSimpleReplace.BtSelectDirectoryClick(Sender: TObject);
var
  ChosenDirectory: string;
begin
  // Ask the user to select a required directory, starting with C:
  if SelectDirectory('Select a directory', 'C:\', ChosenDirectory) then
    CmbFolder.Text := ChosenDirectory;
end;

procedure TFmSimpleReplace.CmbFolderChange(Sender: TObject);
begin
  CheckGoPossible;
end;

procedure TFmSimpleReplace.CmbReplaceTextKeyPress(Sender: TObject;
  var Key: Char);
begin
  case Key of
    #13 :
      begin
        if BtGo.Enabled then
          BtGo.Click;
      end;
  end;
end;

procedure TFmSimpleReplace.CmbSearchTextChange(Sender: TObject);
begin
  CheckGoPossible;
end;

procedure TFmSimpleReplace.CmbSearchTextKeyPress(Sender: TObject;
  var Key: Char);
begin
  case Key of
    #13 :
      begin
        CmbReplaceText.Text := CmbSearchText.Text;
        CmbReplaceText.SetFocus;
        if CmbSearchText.Items.IndexOf(CmbSearchText.Text) < 0 then
        begin
          CmbSearchText.Items.Insert(0, CmbSearchText.Text);
          if CmbSearchText.Items.Count > 9 then
            CmbSearchText.Items.Delete(9);
        end;
      end;
  end;
end;

procedure TFmSimpleReplace.CheckGoPossible;
begin
  BtGo.Enabled := (CmbSearchText.Text <> '') and
    SysUtils.DirectoryExists(CmbFolder.Text);
end;

end.

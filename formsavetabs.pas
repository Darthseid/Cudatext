(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit formsavetabs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  IniFiles, CheckLst, ExtCtrls, StdCtrls,
  LazUTF8, LazFileUtils, LCLType,
  ATPanelSimple,
  proc_globdata,
  proc_miscutils,
  proc_msg;

type
  { TfmSaveTabs }

  TfmSaveTabs = class(TForm)
    btnCancel: TButton;
    btnDontSave: TButton;
    btnDontSaveKeep: TButton;
    btnSave: TButton;
    List: TCheckListBox;
    Panel1: TATPanelSimple;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
  private
    { private declarations }
    procedure DoLoadSize;
    procedure DoSaveSize;
    procedure Localize;
  public
    { public declarations }
  end;

var
  fmSaveTabs: TfmSaveTabs;

implementation

{$R *.lfm}

{ TfmSaveTabs }

procedure TfmSaveTabs.Localize;
const
  section = 'd_save_tabs';
var
  ini: TIniFile;
  fn: string;
begin
  fn:= GetAppLangFilename;
  if not FileExists(fn) then exit;
  ini:= TIniFile.Create(fn);
  try
    Caption:= ini.ReadString(section, '_', Caption);
    with btnSave do Caption:= ini.ReadString(section, 'sav', Caption);
    with btnDontSave do Caption:= ini.ReadString(section, 'no', Caption);
    with btnDontSaveKeep do Caption:= ini.ReadString(section, 'no_ses', Caption);
    with btnCancel do Caption:= msgButtonCancel;
  finally
    FreeAndNil(ini);
  end;
end;

procedure TfmSaveTabs.FormShow(Sender: TObject);
begin
  UpdateFormOnTop(Self);

  with List do
    if Items.Count>0 then
      ItemIndex:= 0;

  //btnDontSave.Visible:= not UiOps.ReopenSession;
  btnDontSaveKeep.Visible:= UiOps.ReopenSession;
end;

procedure TfmSaveTabs.DoLoadSize;
begin
  FormHistoryLoad(Self, '/dlg_savetabs', false);
end;

procedure TfmSaveTabs.DoSaveSize;
begin
  FormHistorySave(Self, '/dlg_savetabs', false);
end;

procedure TfmSaveTabs.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  C: TWinControl;
begin
  //workaround for LCL bug: Enter press on focused buttons [Dont save], [Cancel] dont work
  if (Key=VK_RETURN) and (Shift=[]) then
  begin
    C:= ActiveControl;
    if C is TButton then
      (C as TButton).Click;
    key:= 0;
    exit
  end;
end;

procedure TfmSaveTabs.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  DoSaveSize;
end;

procedure TfmSaveTabs.FormCreate(Sender: TObject);
begin
  Localize;
  DoLoadSize;
end;

end.


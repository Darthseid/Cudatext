(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit proc_globdata;

{$mode objfpc}{$H+}
{$IOChecks off}
{$ModeSwitch advancedrecords}

interface

uses
  {$ifdef windows}
  Windows,
  {$endif}
  Classes, SysUtils, Forms, Controls, Menus,
  Dialogs, Graphics,
  syncobjs,
  gqueue,
  Math,
  InterfaceBase,
  LclProc, LclType, LazFileUtils,
  FileUtil,
  IniFiles,
  Process,
  ATSynEdit,
  ATSynEdit_Keymap,
  ATSynEdit_Keymap_Init,
  ATSynEdit_Adapter_litelexer,
  ATStringProc,
  ATFlatThemes,
  ATListbox,
  ATStatusBar,
  ATScrollBar,
  at__jsonconf,
  proc_cmd,
  proc_msg,
  proc_str,
  proc_keymap_undolist,
  ec_LexerList,
  ec_SyntAnal;

type

  { TAppFileProps }

  TAppFileProps = record
    Inited: boolean;
    Exists: boolean;
    Size: Int64;
    Age: LongInt;
    class operator =(const a, b: TAppFileProps): boolean;
  end;

  TAppConsoleQueue = specialize TQueue<UnicodeString>;

var
  //ATSynEdit has range for bookmarks 0..63, 0=none
  AppBookmarkSetup: array[1..63] of
    record
      ImageIndex: integer;
      Color: TColor;
    end;
var
  AppBookmarkImagelist: TImageList = nil;
  AppApiFlatTheme: TATFlatTheme;
  AppAlwaysNewInstance: boolean = false;

var
  AppFrameList1: TFPList; //all frames - for main thread
  AppFrameList2: TFPList; //all frames - for file watcher thread
  AppFrameListDeleting: TFPList; //frames which need to be Free'd
                              //we don't free frames instantly, because watcher thread can access them

  AppEventLister: TEvent; //event set to signaled, when main thread has done AppFrameList2 updating
  AppEventWatcher: TEvent; //event set to signaled, when watcher thread is not busy

type
  TAppKeyValue = class
    Key: string;
    Value: string;
  end;

type
  { TAppKeyValues }

  TAppKeyValues = class(TFPList)
  public
    procedure Add(const AKey, AValue: string);
    function GetValue(const AKey, ADefValue: string): string;
  end;

var
  AppConfig_Detect: TAppKeyValues;
  AppConfig_DetectLine: TAppKeyValues;
  AppConfig_PGroups: TAppKeyValues;

const
  AppExtensionThemeUi = '.cuda-theme-ui';
  AppExtensionThemeSyntax = '.cuda-theme-syntax';

const
  AppDefaultMonospacedFont =
    {$ifdef windows} 
    'Consolas' 
    {$else}
      {$ifdef darwin}
      'Monaco'
      {$else}
      'Courier New'
      {$endif}
    {$endif}
    ;

type
  TUiOps = record
    VarFontName: string;
    VarFontSize: integer;
    OutputFontName: string;
    OutputFontSize: integer;
    DoubleBuffered: boolean;

    PyLibrary: string;
    PyChangeSlow: integer;
    PyInitLog: boolean;

    LexerThemes: boolean;
    LexerMenuGrouped: boolean;
    LexerDelayedParsingPause: integer;
    LexerDelayedParsingSize: integer;
    LexerPostponeUntilShown: boolean;

    ToolBarTheme: string;
    LangName: string;

    ThemeUi: string;
    ThemeSyntax: string;
    ThemeUi_Loaded: boolean;
    ThemeSyntax_Loaded: boolean;

    SidebarShow: boolean;
    SidebarOnRight: boolean;
    SidebarTheme: string;
    PictureTypes: string;
    MaxFileSizeToOpen: integer;
    MaxFileSizeForLexer: integer;
    MaxRangesForCodeTree: integer;

    AutocompleteHtml: boolean;
    AutocompleteCss: boolean;
    AutocompleteHtml_Lexers: string;
    AutocompleteCss_Lexers: string;

    AutocompleteAutoshowCharCount: integer;
    AutocompleteTriggerChars: string;
    AutocompleteCommitChars: string;
    AutocompleteCloseChars: string;
    AutocompleteAddOpeningBracket: boolean;
    AutocompleteUpDownAtEdge: integer;
    AutoCloseBrackets: string;

    ListboxCentered: boolean;
    ListboxSizeX: integer;
    ListboxSizeY: integer;
    ListboxCompleteSizeX: integer;
    ListboxCompleteSizeY: integer;
    ListboxFuzzySearch: boolean;
    ListboxHotkeyFontSizeDelta: integer;

    TabAnimation: boolean;
    TabsDisabled: boolean;
    TabVarWidth: boolean;
    TabMultiline: boolean;
    TabAngled: boolean;
    TabFlat: boolean;
    TabWidth: integer;
    TabWidthMin: integer;
    TabWidthMax: integer;
    TabHeight: integer;
    TabHeightInner: integer;
    TabSpacer: integer;
    TabPosition: integer;
    TabColorFull: boolean;
    TabShowX: integer;
    TabShowXSize: integer;
    TabShowPlus: boolean;
    TabDblClickClose: boolean;
    TabNumbers: boolean;
    TabNewNearCurrent: boolean;
    TabRecentOnClose: boolean;
    TabButtonLayout: string;
    TabPreviewFontStyle: string;
    TabSwitcherDialog: boolean;

    MaxHistoryEdits: integer;
    MaxHistoryMenu: integer;
    MaxHistoryFiles: integer;

    FindSuggestSel: boolean;
    FindSuggestWord: boolean;
    FindSuggestInSelection: boolean;
    FindSelCase: integer;
    FindShow_FindFirst: boolean;
    FindShow_MarkALl: boolean;
    FindShow_SelectAll: boolean;
    FindShow_Extract: boolean;
    FindShow_ReplaceGlobal: boolean;
    FindIndentVert: integer;
    FindIndentHorz: integer;
    FindMultiLineScale: double;
    FindSeparateForm: boolean;

    EscapeClose: boolean;
    EscapeCloseConsole: boolean;
    //ConsoleCompact: boolean;
    ConsoleWordWrap: boolean;
    InputHeight: integer;
    InitialDir: string;

    ExportHtmlNumbers: boolean;
    ExportHtmlFontName: string;
    ExportHtmlFontSize: integer;

    TreeTheme: string;
    TreeAutoSync: boolean;
    TreeTimeFill: integer;
    //TreeTimeCaret: integer;
    TreeShowIcons: boolean;
    TreeShowTooltips: boolean;
    TreeFilterLayout: integer;
    TreeSublexers: boolean;

    NewdocLexer: string;
    NewdocEnc: string;
    NewdocEnds: integer;

    DefaultEncUtf8: boolean;
    ViewerBinaryWidth: integer;

    StatusNoSel: string;
    StatusSmallSel: string;
    StatusStreamSel: string;
    StatusColSel: string;
    StatusCarets: string;
    StatusPanels: string;
    StatusHeight: integer;
    StatusTime: integer;
    StatusAltTime: integer;

    ScrollbarWidth: integer;
    ScrollbarBorderSize: integer;
    ScrollbarArrowSize: integer;

    ProgressbarWidth: integer;
    ProgressbarHeightSmall: integer;

    ShowMenubar: boolean;
    ShowStatusbar: boolean;
    ShowToolbar: boolean;
    ShowActiveBorder: boolean;
    ShowTitlePath: boolean;
    Scale: integer;
    ScaleFont: integer;

    ReopenSession: boolean;
    AutoSaveSession: boolean;
    ShowFormsOnTop: boolean;
    ShowMenuDialogsWithBorder: boolean;
    UndoPersistent: string;

    FloatGroupsInTaskbar: boolean;
    OneInstance: boolean;
    NotificationEnabled: boolean;
    NotificationTimeSeconds: integer;
    NonTextFiles: integer; //0: prompt, 1: open, 2: don't open
    NonTextFilesBufferKb: integer;
    ReloadUnsavedConfirm: boolean;
    ReloadFollowTail: boolean;
    FullScreen: string;
    MouseGotoDefinition: string;
    LogDebug: boolean;
    LogConsole: boolean;

    Emmet_AddSlashToEmptyTags: boolean;
    Emmet_CommentTags: boolean;
    Emmet_IndentNested: boolean;
    Emmet_SingleLine: boolean;
    Emmet_TrimLineMarkers: boolean;
    Emmet_WordWrap: boolean;

    HotkeyFindDialog,
    HotkeyReplaceDialog,
    HotkeyFindFirst,
    HotkeyFindNext,
    HotkeyFindPrev,
    HotkeyReplaceAndFindNext,
    HotkeyReplaceNoFindNext,
    HotkeyReplaceAll,
    HotkeyReplaceGlobal,
    HotkeyCountAll,
    HotkeyExtractAll,
    HotkeySelectAll,
    HotkeyMarkAll,
    HotkeyToggleRegex,
    HotkeyToggleCaseSens,
    HotkeyToggleWords,
    HotkeyToggleWrapped,
    HotkeyToggleInSelect,
    HotkeyToggleMultiline,
    HotkeyToggleConfirmRep,
    HotkeyToggleTokens
      : string;
  end;
var
  UiOps: TUiOps;

const
  str_FontName = 'font_name'+cOptionSystemSuffix;
  str_FontName_i = 'font_name_i'+cOptionSystemSuffix;
  str_FontName_b = 'font_name_b'+cOptionSystemSuffix;
  str_FontName_bi = 'font_name_bi'+cOptionSystemSuffix;
  str_FontSize = 'font_size'+cOptionSystemSuffix;
  str_FontSize_i = 'font_size_i'+cOptionSystemSuffix;
  str_FontSize_b = 'font_size_b'+cOptionSystemSuffix;
  str_FontSize_bi = 'font_size_bi'+cOptionSystemSuffix;
  str_FontQuality = 'font_quality'+cOptionSystemSuffix;
  str_FontLigatures = 'font_ligatures'; //+cOptionSystemSuffix;
  str_UiFontName = 'ui_font_name'+cOptionSystemSuffix;
  str_UiFontSize = 'ui_font_size'+cOptionSystemSuffix;
  str_UiFontOutputName = 'ui_font_output_name'+cOptionSystemSuffix;
  str_UiFontOutputSize = 'ui_font_output_size'+cOptionSystemSuffix;
  str_UiDoubleBuffered = 'ui_buffered'+cOptionSystemSuffix;
  str_DefEncodingIsUtf8 = 'def_encoding_utf8'+cOptionSystemSuffix;

type
  TEditorOps = record
    OpFontName: string;
    OpFontName_i: string;
    OpFontName_b: string;
    OpFontName_bi: string;
    OpFontSize: integer;
    OpFontSize_i: integer;
    OpFontSize_b: integer;
    OpFontSize_bi: integer;
    OpFontSize_original: integer;
    OpFontSize_original_i: integer;
    OpFontSize_original_b: integer;
    OpFontSize_original_bi: integer;
    OpFontQuality: TFontQuality;
    OpFontLigatures: boolean;

    OpSpacingY: integer;
    OpTabSize: integer;
    OpTabSpaces: boolean;
    OpTabMaxPosExpanded: integer;

    OpOverwriteSel: boolean;
    OpOverwriteOnPaste: boolean;
    OpUnderlineColorFiles: string;
    OpUnderlineColorSize: integer;
    OpLinks: boolean;
    OpLinksRegex: string;

    //view
    OpGutterShow: boolean;
    OpGutterFold: boolean;
    OpGutterFoldAlways: boolean;
    OpGutterFoldIcons: integer;
    OpGutterBookmarks: boolean;

    OpNumbersShow: boolean;
    OpNumbersStyle: integer;
    OpNumbersForCarets: boolean;
    OpNumbersCenter: boolean;

    OpRulerShow: boolean;
    OpRulerNumeration: integer;
    OpRulerMarkCaret: integer;

    OpMinimapShow: boolean;
    OpMinimapShowSelAlways: boolean;
    OpMinimapShowSelBorder: boolean;
    OpMinimapCharWidth: integer;
    OpMinimapAtLeft: boolean;
    OpMinimapTooltipShow: boolean;
    OpMinimapTooltipLineCount: integer;
    OpMinimapTooltipWidth: integer;
    OpMicromapShow: boolean;
    OpMicromapWidthSmall: integer;
    OpMarginFixed: integer;
    OpMarginString: string;

    OpStaplesStyle: integer;
    OpStaplesProps: string;

    //unprinted
    OpUnprintedShow: boolean;
    OpUnprintedContent: string;

    OpUnprintedReplaceSpec: boolean;
    OpUnprintedReplaceToCode: string;

    OpUnprintedTabArrowLen: integer;
    OpUnprintedSpaceDotScale: integer;
    OpUnprintedEndDotScale: integer;
    OpUnprintedEndFontScale: integer;
    OpUnprintedTabPointerScale: integer;

    //wrap
    OpWrapMode: integer;
    OpWrapIndented: boolean;
    OpWrapEnabledMaxLines: integer;

    //undo
    OpUndoLimit: integer;
    OpUndoGrouped: boolean;
    OpUndoAfterSave: boolean;

    //caret
    OpCaretBlinkTime: integer;
    OpCaretBlinkEn: boolean;
    OpCaretViewNormal: string;
    OpCaretViewOverwrite: string;
    OpCaretViewReadonly: string;
    OpCaretVirtual: boolean;
    OpCaretMulti: boolean;
    OpCaretAfterPasteColumn: integer;
    OpCaretsAddedToColumnSel: boolean;
    OpCaretKeepVisibleOnScroll: boolean;

    //general
    OpShowCurLine: boolean;
    OpShowCurLineMinimal: boolean;
    OpShowCurLineOnlyFocused: boolean;
    OpShowCurCol: boolean;
    OpShowLastLineOnTop: boolean;
    OpShowFullBackgroundSel: boolean;
    OpShowFullBackgroundSyntax: boolean;
    OpShowMouseSelFrame: boolean;
    OpCopyLineIfNoSel: boolean;
    OpCutLineIfNoSel: boolean;
    OpCopyColumnAlignedBySpaces: boolean;
    OpSavingTrimSpaces: boolean;
    OpSavingTrimFinalEmptyLines: boolean;
    OpSavingForceFinalEol: boolean;
    OpShowHintOnVertScroll: boolean;
    OpSmoothScroll: boolean;
    OpCenteringWidth: integer;
    OpCenteringForDistractionFree: integer;
    OpScrollStyleHorz: integer;
    OpLexerDynamicHiliteEnabled: boolean;
    OpLexerDynamicHiliteMaxLines: integer;
    OpLexerLineSeparators: boolean;
    OpZebra: integer;

    OpNonWordChars: UnicodeString;
    OpHexChars: UnicodeString;
    OpFoldStyle: integer;
    OpFoldTooltipShow: boolean;

    //indent
    OpIndentAuto: boolean;
    OpIndentAutoKind: integer;
    OpIndentSize: integer;
    OpIndentAutoRule: string;
    OpUnIndentKeepsAlign: boolean;
    OpIndentMakesWholeLineSel: boolean;

    //mouse
    OpMouse2ClickDragSelectsWords: boolean;
    OpMouseDragDrop: boolean;
    OpMouseDragDropFocusTarget: boolean;
    OpMouseMiddleClickNiceScroll: boolean;
    OpMouseMiddleClickPaste: boolean;
    OpMouseRightClickMovesCaret: boolean;
    OpMouseEnableColumnSelection: boolean;
    OpMouseHideCursorOnType: boolean; //don't work on lin
    OpMouseGutterClickSelectedLine: boolean;
    OpMouseWheelZoom: boolean;
    OpMouseWheelSpeedVert: integer;
    OpMouseWheelSpeedHorz: integer;
    OpMouseClickNumberSelectsEol: boolean;

    //keys
    OpKeyBackspaceUnindent: boolean;
    OpKeyBackspaceWrap: boolean;
    OpKeyTabIndents: boolean;
    OpKeyHomeToNonSpace: boolean;
    OpKeyHomeEndNavigateWrapped: boolean;
    OpKeyEndToNonSpace: boolean;
    OpKeyPageKeepsRelativePos: boolean;
    OpKeyPageUpDownSize: integer;
    OpKeyUpDownKeepColumn: boolean;
    OpKeyUpDownNavigateWrapped: boolean;
    OpKeyLeftRightSwapSel: boolean;
    OpKeyLeftRightSwapSelAndSelect: boolean;

    OpBracketHilite: boolean;
    OpBracketSymbols: string;
    OpBracketDistance: integer;
  end;
var
  EditorOps: TEditorOps;

var
  AppDir_Home: string;
  AppDir_Settings: string;
  AppDir_SettingsDefault: string;
  AppDir_Py: string;
  AppDir_Data: string;
  AppDir_Lexers: string;
  AppDir_LexersLite: string;
  AppDir_DataThemes: string;
  AppDir_DataAutocomplete: string;
  AppDir_DataAutocompleteSpec: string;
  AppDir_DataLang: string;
  AppDir_DataSidebarIcons: string;
  AppDir_DataCodetreeIcons: string;
  AppDir_DataToolbarIcons: string;
  AppDir_LastInstalledAddon: string = '';
  AppFile_OptionsDefault: string;
  AppFile_OptionsUser: string;
  AppFile_History: string;
  AppFile_HistoryFiles: string;
  AppFile_Hotkeys: string;

function GetAppLangFilename: string;
function GetAppUndoFilename(const fn: string; IsRedo: boolean): string;

function EscapeLexerFilename(const ALexName: string): string;
function GetAppLexerFilename(const ALexName: string): string;
function GetAppLexerMapFilename(const ALexName: string): string;
function GetAppLexerOpsFilename(const ALexName: string): string;
function GetAppLexerAcpFilename(const ALexName: string): string;
function GetAppLexerSpecificConfig(ALexer: string; ADefaultConfig: boolean=false): string;

function MsgBox(const Str: string; Flags: Longint): integer;
procedure MsgBadConfig(const fn: string);
procedure MsgStdout(const Str: string; AllowMsgBox: boolean = false);
procedure MsgLogConsole(const AText: string);

function AppScale(AValue: integer): integer;
function AppScaleFont(AValue: integer): integer;
//procedure AppScaleScrollbar(C: TATScroll);
function AppListboxItemHeight(AScale, ADoubleHeight: boolean): integer;
procedure AppGetFileProps(const FileName: string; out P: TAppFileProps);
procedure AppUpdateWatcherFrames;

function FixFontMonospaced(const AName: string): string;
procedure FixFormPositionToDesktop(F: TForm);
procedure FixRectPositionToDesktop(var F: TRect);

function GetAppKeymap_LexerSpecificConfig(AName: string): string;
function GetAppKeymapHotkey(const ACmdString: string): string;
function SetAppKeymapHotkey(const AParams: string): boolean;

function AppKeymapCheckDuplicateForCommand(
  AKeymapItem: TATKeymapItem;
  const ALexerName: string;
  AOverwriteAndSave: boolean): integer;
function AppKeymapHasDuplicateForKey(AHotkey, AKeyComboSeparator: string): boolean;
procedure AppKeymap_ApplyUndoList(AUndoList: TATKeymapUndoList);

function DoOps_HotkeyStringId_To_CommandCode(const AId: string): integer;
function DoOps_CommandCode_To_HotkeyStringId(ACmd: integer): string;
procedure DoOps_SaveKeyItem(K: TATKeymapItem; const path, ALexerName: string; ALexerSpecific: boolean);
procedure DoOps_SaveKey_ForPluginModuleAndMethod(AOverwriteKey: boolean;
  const AMenuitemCaption, AModuleName, AMethodName, ALexerName, AHotkey: string);

function DoLexerDetectByFilenameOrContent(const AFilename: string;
  AChooseFunc: TecLexerChooseFunc): TecSyntAnalyzer;
procedure DoLexerEnum(L: TStringList; AlsoDisabled: boolean = false);

function DoReadOneStringFromFile(const AFilename: string): string;
function DoReadContentFromFile(const AFilename: string): string;
procedure DoWriteStringToFile(const AFilename, AText: string);

function SCollapseHomeDirInFilename(const AFilename: string): string;
function SExpandHomeDirInFilename(const AFilename: string): string;

var
  AppManager: TecLexerList = nil;
  AppManagerLite: TATLiteLexers = nil;
  AppKeymap: TATKeymap = nil;
  AppKeymapInitial: TATKeymap = nil;
  AppShortcutEscape: TShortcut = 0;
  AppShortcutShiftTab: TShortcut = 0;

type
  TStrEvent = procedure(Sender: TObject; const ARes: string) of object;
  TStrFunction = function(const AStr: string): boolean of object;

type
  TAppEncodingRecord = record
    Sub,
    Name,
    ShortName: string;
  end;

const
  AppEncodings: array[0..34] of TAppEncodingRecord = (
    (Sub: ''; Name: cEncNameUtf8_NoBom; ShortName: 'utf8'),
    (Sub: ''; Name: cEncNameUtf8_WithBom; ShortName: 'utf8_bom'),
    (Sub: ''; Name: cEncNameUtf16LE_NoBom; ShortName: 'utf16le'),
    (Sub: ''; Name: cEncNameUtf16LE_WithBom; ShortName: 'utf16le_bom'),
    (Sub: ''; Name: cEncNameUtf16BE_NoBom; ShortName: 'utf16be'),
    (Sub: ''; Name: cEncNameUtf16BE_WithBom; ShortName: 'utf16be_bom'),
    (Sub: ''; Name: cEncNameUtf32LE_NoBom; ShortName: 'utf32le'),
    (Sub: ''; Name: cEncNameUtf32LE_WithBom; ShortName: 'utf32le_bom'),
    (Sub: ''; Name: cEncNameUtf32BE_NoBom; ShortName: 'utf32be'),
    (Sub: ''; Name: cEncNameUtf32BE_WithBom; ShortName: 'utf32be_bom'),
    (Sub: ''; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: 'cp1250'; ShortName: 'cp1250'),
    (Sub: 'eu'; Name: 'cp1251'; ShortName: 'cp1251'),
    (Sub: 'eu'; Name: 'cp1252'; ShortName: 'cp1252'),
    (Sub: 'eu'; Name: 'cp1253'; ShortName: 'cp1253'),
    (Sub: 'eu'; Name: 'cp1257'; ShortName: 'cp1257'),
    (Sub: 'eu'; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: 'cp437'; ShortName: 'cp437'),
    (Sub: 'eu'; Name: 'cp850'; ShortName: 'cp850'),
    (Sub: 'eu'; Name: 'cp852'; ShortName: 'cp852'),
    (Sub: 'eu'; Name: 'cp866'; ShortName: 'cp866'),
    (Sub: 'eu'; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: 'iso88591'; ShortName: 'iso88591'),
    (Sub: 'eu'; Name: 'iso88592'; ShortName: 'iso88592'),
    (Sub: 'eu'; Name: 'iso885915'; ShortName: 'iso885915'),
    (Sub: 'eu'; Name: 'mac'; ShortName: 'mac'),
    (Sub: 'mi'; Name: 'cp1254'; ShortName: 'cp1254'),
    (Sub: 'mi'; Name: 'cp1255'; ShortName: 'cp1255'),
    (Sub: 'mi'; Name: 'cp1256'; ShortName: 'cp1256'),
    (Sub: 'as'; Name: 'cp874'; ShortName:  'cp874'),
    (Sub: 'as'; Name: 'cp932'; ShortName:  'cp932'),
    (Sub: 'as'; Name: 'cp936'; ShortName:  'cp936'),
    (Sub: 'as'; Name: 'cp949'; ShortName:  'cp949'),
    (Sub: 'as'; Name: 'cp950'; ShortName:  'cp950'),
    (Sub: 'as'; Name: 'cp1258'; ShortName: 'cp1258')
  );

type
  TAppPyEventResult = record
    Val: (evrTrue, evrFalse, evrString, evrOther);
    Str: string;
  end;

type
  TAppPyEvent = (
    cEventOnKey,
    cEventOnKeyUp,
    cEventOnHotspot,
    cEventOnInsert,
    cEventOnChange,
    cEventOnChangeSlow,
    cEventOnCaret,
    cEventOnScroll,
    cEventOnMouseStop,
    cEventOnClick,
    cEventOnClickDbl,
    cEventOnClickGutter,
    cEventOnClickGap,
    cEventOnState,
    cEventOnStateEd,
    cEventOnFocus,
    cEventOnStart,
    cEventOnOpen,
    cEventOnOpenBefore,
    cEventOnOpenNone,
    cEventOnClose,
    cEventOnCloseBefore,
    cEventOnSaveAfter,
    cEventOnSaveBefore,
    cEventOnSaveNaming,
    cEventOnLexer,
    cEventOnLexerParsed,
    cEventOnComplete,
    cEventOnGotoDef,
    cEventOnGotoEnter,
    cEventOnFuncHint,
    cEventOnTabChange,
    cEventOnTabMove,
    cEventOnPaste,
    cEventOnConsoleNav,
    cEventOnOutputNav,
    cEventOnSnippet,
    cEventOnMacro,
    cEventOnExit
    );
  TAppPyEvents = set of TAppPyEvent;
  TAppPyEventsPrior = array[TAppPyEvent] of byte;
    //0: default, 1,2...: higher priority
  TAppPyEventsLazy = array[TAppPyEvent] of boolean;

var
  AppEventsMaxPriorities: array[TAppPyEvent] of integer;

const
  cAppPyEvent: array[TAppPyEvent] of string = (
    'on_key',
    'on_key_up',
    'on_hotspot',
    'on_insert',
    'on_change',
    'on_change_slow',
    'on_caret',
    'on_scroll',
    'on_mouse_stop',
    'on_click',
    'on_click_dbl',
    'on_click_gutter',
    'on_click_gap',
    'on_state',
    'on_state_ed',
    'on_focus',
    'on_start',
    'on_open',
    'on_open_pre',
    'on_open_none',
    'on_close',
    'on_close_pre',
    'on_save',
    'on_save_pre',
    'on_save_naming',
    'on_lexer',
    'on_lexer_parsed',
    'on_complete',
    'on_goto_def',
    'on_goto_enter',
    'on_func_hint',
    'on_tab_change',
    'on_tab_move',
    'on_paste',
    'on_console_nav',
    'on_output_nav',
    'on_snippet',
    'on_macro',
    'on_exit'
    );

type
  TAppCommandInfo = class
  public
    ItemModule: string;
    ItemProc: string;
    ItemProcParam: string;
    ItemCaption: string;
    ItemLexers: string;
    ItemInMenu: string;
    ItemFromApi: boolean;
  end;

type
  TAppEventInfo = class
    ItemModule: string;
    ItemLexers: string;
    ItemEvents: TAppPyEvents;
    ItemEventsPrior: TAppPyEventsPrior;
    ItemEventsLazy: TAppPyEventsLazy;
    ItemKeys: string;
  end;

type
  TAppTreeHelper = class
    ItemModule: string;
    ItemProc: string;
    ItemLexers: string;
  end;

var
  AppConsoleQueue: TAppConsoleQueue;
  AppCommandList: TFPList;
  AppEventList: TFPList;
  AppTreeHelpers: TFPList;

type
  PAppPanelProps = ^TAppPanelProps;
  TAppPanelProps = record
    Listbox: TATListbox;
    RegexStr: string;
    RegexIdLine,
    RegexIdCol,
    RegexIdName: integer;
    DefFilename: string;
    ZeroBase: boolean;
    Encoding: string;
  end;

type
  TAppMenuProps = class
  public
    CommandCode: integer;
    CommandString: string;
    TagString: string;
  end;

function AppCommandCategory(Cmd: integer): TAppCommandCategory;
function AppCommandHasConfigurableHotkey(Cmd: integer): boolean;
procedure AppCommandsClearButKeepApiItems;
procedure AppEventStringToEventData(const AEventStr: string;
  out AEvents: TAppPyEvents;
  out AEventsPrior: TAppPyEventsPrior;
  out AEventsLazy: TAppPyEventsLazy);
procedure AppEventsUpdate(const AModuleName, AEventStr, ALexerStr, AKeyStr: string);
procedure AppEventsMaxPrioritiesUpdate;

function CommandPlugins_GetIndexFromModuleAndMethod(const AText: string): integer;
procedure CommandPlugins_UpdateSubcommands(const AText: string);

function AppEncodingShortnameToFullname(const S: string): string;
function AppEncodingFullnameToShortname(const S: string): string;
function AppEncodingListAsString: string;

procedure UpdateFormOnTop(F: TForm);
procedure DoStatusbarTextByTag(AStatus: TATStatus; ATag: PtrInt; const AText: string);
procedure DoStatusbarHintByTag(AStatus: TATStatus; ATag: PtrInt; const AText: string);
function IsFileTooBigForOpening(const AFilename: string): boolean;
function IsFileTooBigForLexer(const AFilename: string): boolean;
procedure DoLexerDetect(const AFilename: string;
  out Lexer: TecSyntAnalyzer;
  out LexerLite: TATLiteLexer;
  out LexerName: string;
  AChooseFunc: TecLexerChooseFunc);
procedure DoMenuitemEllipsis(c: TMenuItem);


implementation

function MsgBox(const Str: string; Flags: Longint): integer;
begin
  Result:= Application.MessageBox(PChar(Str), PChar(msgTitle), Flags);
end;

procedure MsgBadConfig(const fn: string);
begin
  MsgBox(msgCannotReadConf+#10+fn, MB_OK+MB_ICONERROR);
end;

function InitPyLibraryPath: string;
{$ifdef windows}
var
  N: integer;
  S, SFile: string;
{$endif}
{$ifdef darwin}
var
  N: integer;
  S: string;
{$endif}
begin
  Result:= '';

  {$ifdef windows}
  //detect latest existing file python3x.dll in app folder
  S:= ExtractFilePath(Application.ExeName);
  for N:= 8 downto 4 do
  begin
    SFile:= Format('python3%d.dll', [N]);
    //don't return full filename, this loads DLL with full filename and plugins cannot load
    if FileExists(S+SFile) then
      exit(SFile);
  end;
  exit;
  {$endif}

  {$ifdef darwin}
  for N:= 5 to 8 do
  begin
    S:= Format('/Library/Frameworks/Python.framework/Versions/3.%d/lib/libpython3.%d.dylib',
      [N, N]);
    if FileExists(S) then exit(S);
  end;
  exit;
  {$endif}

  {$ifdef freebsd}
  exit('/usr/local/lib/libpython3.6m.so');
  {$endif}

  {$ifdef netbsd}
  exit('/usr/pkg/lib/libpython3.7.so');
  {$endif}

  {$ifdef solaris}
  exit('/usr/lib/amd64/libpython3.5m.so');
  {$endif}

  {$ifdef unix}
  exit('libpython3.so');
  {$endif}
end;

var
  OpDirExe: string = '';
  OpDirLocal: string = '';
  OpDirPrecopy: string = '';

function GetDirPrecopy: string;
begin
  {$ifdef linux}
  exit('/usr/share/cudatext');
  {$endif}

  {$ifdef darwin}
  exit(ExtractFileDir(OpDirExe)+'/Resources');
  {$endif}

  Result:= '';
end;

function SCollapseHomeDirInFilename(const AFilename: string): string;
var
  S: string;
begin
  Result:= AFilename;
  S:= AppDir_Home;
  if SBeginsWith(Result, S) then
    Result:= '~'+DirectorySeparator+Copy(Result, Length(S)+1, MaxInt);
end;

function SExpandHomeDirInFilename(const AFilename: string): string;
begin
  Result:= AFilename;
  if SBeginsWith(Result, '~'+DirectorySeparator) then
    Result:= AppDir_Home+Copy(Result, 3, MaxInt);
end;


function IsDistroUpdateNeeded: boolean;
begin
  with TIniFile.Create(AppDir_Settings+DirectorySeparator+'packages.ini') do
  try
    Result:= ReadString('app', 'ver', '')<>cAppExeVersion;
    if Result then
      WriteString('app', 'ver', cAppExeVersion);
  finally
    Free
  end;
end;

procedure InitDirs;
var
  S, HomeConfig: string;
begin
  OpDirExe:= ExtractFileDir(ParamStr(0));
  OpDirPrecopy:= GetDirPrecopy;
  OpDirLocal:= OpDirExe;

  //from https://github.com/graemeg/freepascal/blob/master/rtl/unix/sysutils.pp
  AppDir_Home:= GetEnvironmentVariable('HOME');
  If AppDir_Home<>'' then
    AppDir_Home:= IncludeTrailingPathDelimiter(AppDir_Home);

  {$ifdef linux}
  //not portable folder of app
  if not DirectoryExistsUTF8(OpDirExe+DirectorySeparator+'data'+DirectorySeparator+'lexlib') then
  begin
    HomeConfig:= GetEnvironmentVariable('XDG_CONFIG_HOME');
    if HomeConfig='' then
      HomeConfig:= AppDir_Home + '.config/'
    else
      HomeConfig:= IncludeTrailingPathDelimiter(HomeConfig);

    OpDirLocal:= HomeConfig+'cudatext';
    CreateDirUTF8(OpDirLocal);
  end;
  {$endif}
  {$ifdef darwin}
  OpDirLocal:= AppDir_Home+'Library/Application Support/CudaText';
  CreateDirUTF8(OpDirLocal);
  {$endif}

  AppDir_Settings:= OpDirLocal+DirectorySeparator+'settings';
  CreateDirUTF8(AppDir_Settings);
  AppDir_SettingsDefault:= OpDirLocal+DirectorySeparator+'settings_default';

  {$ifdef linux}
  if OpDirLocal<>OpDirExe then
    if IsDistroUpdateNeeded then
      if DirectoryExistsUTF8(OpDirPrecopy) then
        RunCommand('cp', ['-R', '-u', '-t',
          OpDirLocal,
          '/usr/share/cudatext/py',
          '/usr/share/cudatext/data',
          '/usr/share/cudatext/settings_default'
          ], S);
  {$endif}
  {$ifdef darwin}
  if IsDistroUpdateNeeded then
    if DirectoryExistsUTF8(OpDirPrecopy) then
      //see rsync help. need options:
      // -u (update)
      // -r (recursive)
      // -t (preserve times)
      RunCommand('rsync', ['-urt',
        OpDirPrecopy+'/',
        OpDirLocal
        ], S);
  {$endif}

  AppDir_Py:= OpDirLocal+DirectorySeparator+'py';
  AppDir_Data:= OpDirLocal+DirectorySeparator+'data';
  AppDir_Lexers:= AppDir_Data+DirectorySeparator+'lexlib';
  AppDir_LexersLite:= AppDir_Data+DirectorySeparator+'lexliblite';
  AppDir_DataThemes:= AppDir_Data+DirectorySeparator+'themes';
  AppDir_DataAutocomplete:= AppDir_Data+DirectorySeparator+'autocomplete';
  AppDir_DataAutocompleteSpec:= AppDir_Data+DirectorySeparator+'autocompletespec';
  AppDir_DataLang:= AppDir_Data+DirectorySeparator+'lang';
  AppDir_DataSidebarIcons:= AppDir_Data+DirectorySeparator+'sideicons';
  AppDir_DataCodetreeIcons:= AppDir_Data+DirectorySeparator+'codetreeicons';
  AppDir_DataToolbarIcons:= AppDir_Data+DirectorySeparator+'toolbaricons';
  AppFile_OptionsDefault:= AppDir_SettingsDefault+DirectorySeparator+'default.json';
  AppFile_OptionsUser:= AppDir_Settings+DirectorySeparator+'user.json';
  AppFile_History:= AppDir_Settings+DirectorySeparator+'history.json';
  AppFile_HistoryFiles:= AppDir_Settings+DirectorySeparator+'history files.json';
  AppFile_Hotkeys:= AppDir_Settings+DirectorySeparator+'keys.json';
end;

procedure InitEditorOps(var Op: TEditorOps);
begin
  with Op do
  begin
    OpFontName:= AppDefaultMonospacedFont;
    OpFontName_i:= '';
    OpFontName_b:= '';
    OpFontName_bi:= '';

    OpFontSize:= 9;
    OpFontSize_i:= OpFontSize;
    OpFontSize_b:= OpFontSize;
    OpFontSize_bi:= OpFontSize;
    OpFontSize_original:= OpFontSize;
    OpFontSize_original_i:= OpFontSize;
    OpFontSize_original_b:= OpFontSize;
    OpFontSize_original_bi:= OpFontSize;

    OpFontQuality:= fqDefault;
    OpFontLigatures:= true;

    OpSpacingY:= 1;

    OpTabSize:= 4;
    OpTabSpaces:= false;
    OpTabMaxPosExpanded:= 500;

    OpOverwriteSel:= true;
    OpOverwriteOnPaste:= false;

    OpUnderlineColorFiles:= '*';
    OpUnderlineColorSize:= 3;
    OpLinks:= true;
    OpLinksRegex:= ATSynEdit.cUrlRegexInitial;

    OpGutterShow:= true;
    OpGutterFold:= true;
    OpGutterFoldAlways:= true;
    OpGutterBookmarks:= true;
    OpGutterFoldIcons:= 0;

    OpNumbersShow:= true;
    OpNumbersStyle:= Ord(cNumbersAll);
    OpNumbersForCarets:= false;
    OpNumbersCenter:= true;

    OpRulerShow:= false;
    OpRulerNumeration:= 0;
    OpRulerMarkCaret:= 1;

    OpMinimapShow:= false;
    OpMinimapShowSelAlways:= false;
    OpMinimapShowSelBorder:= true;
    OpMinimapCharWidth:= 0;
    OpMinimapAtLeft:= false;
    OpMinimapTooltipShow:= false;
    OpMinimapTooltipLineCount:= 6;
    OpMinimapTooltipWidth:= 60;

    OpMicromapShow:= false;
    OpMicromapWidthSmall:= 4;

    OpMarginFixed:= 2000; //hide margin
    OpMarginString:= '';

    OpStaplesStyle:= 1; //Ord(cLineStyleSolid)
    OpStaplesProps:= '-1,40,1,1';

    OpUnprintedShow:= false;
    OpUnprintedContent:= 'se';
    OpUnprintedReplaceSpec:= false;
    OpUnprintedReplaceToCode:= 'A4';

    OpUnprintedTabArrowLen:= 1;
    OpUnprintedSpaceDotScale:= 15;
    OpUnprintedEndDotScale:= 30;
    OpUnprintedEndFontScale:= 80;
    OpUnprintedTabPointerScale:= 22;

    OpWrapMode:= 0;
    OpWrapIndented:= true;
    OpWrapEnabledMaxLines:= 60*1000;

    OpUndoLimit:= 5000;
    OpUndoGrouped:= true;
    OpUndoAfterSave:= true;

    OpCaretBlinkTime:= cInitCaretBlinkTime;
    OpCaretBlinkEn:= true;
    OpCaretViewNormal:= '2,-100';
    OpCaretViewOverwrite:= '-100,-100';
    OpCaretViewReadonly:= '-100,2';
    OpCaretVirtual:= false;
    OpCaretMulti:= true;
    OpCaretAfterPasteColumn:= Ord(cPasteCaretColumnRight);
    OpCaretsAddedToColumnSel:= true;
    OpCaretKeepVisibleOnScroll:= true;

    OpShowCurLine:= false;
    OpShowCurLineMinimal:= true;
    OpShowCurLineOnlyFocused:= false;
    OpShowCurCol:= false;
    OpShowLastLineOnTop:= true;
    OpShowFullBackgroundSel:= false;
    OpShowFullBackgroundSyntax:= true;
    OpShowMouseSelFrame:= true;
    OpCopyLineIfNoSel:= true;
    OpCutLineIfNoSel:= false;
    OpCopyColumnAlignedBySpaces:= true;
    OpSavingTrimSpaces:= false;
    OpSavingTrimFinalEmptyLines:= false;
    OpSavingForceFinalEol:= false;
    OpShowHintOnVertScroll:= false;
    OpSmoothScroll:= true;
    OpCenteringWidth:= 0;
    OpCenteringForDistractionFree:= 100;
    OpScrollStyleHorz:= 2; //hide, show, auto
    OpLexerDynamicHiliteEnabled:= false;
    OpLexerDynamicHiliteMaxLines:= 2000;
    OpLexerLineSeparators:= false;
    OpZebra:= 0;

    OpNonWordChars:= cDefaultNonWordChars;
    OpHexChars:= '';
    OpFoldStyle:= 1;
    OpFoldTooltipShow:= false;

    OpIndentAuto:= true;
    OpIndentAutoKind:= Ord(cIndentAsPrevLine);
    OpIndentSize:= 2;
    OpIndentAutoRule:= '';
    OpUnIndentKeepsAlign:= true;
    OpIndentMakesWholeLineSel:= false;

    OpMouse2ClickDragSelectsWords:= true;
    OpMouseDragDrop:= true;
    OpMouseDragDropFocusTarget:= true;
    OpMouseMiddleClickNiceScroll:= true;
    OpMouseMiddleClickPaste:= false;
    OpMouseRightClickMovesCaret:= false;
    OpMouseEnableColumnSelection:= true;
    OpMouseHideCursorOnType:= false;
    OpMouseGutterClickSelectedLine:= true;
    OpMouseWheelZoom:= false;
    OpMouseWheelSpeedVert:= 3;
    OpMouseWheelSpeedHorz:= 10;
    OpMouseClickNumberSelectsEol:= true;

    OpKeyBackspaceUnindent:= true;
    OpKeyBackspaceWrap:= true;
    OpKeyTabIndents:= true;
    OpKeyHomeToNonSpace:= true;
    OpKeyHomeEndNavigateWrapped:= true;
    OpKeyEndToNonSpace:= true;
    OpKeyPageKeepsRelativePos:= true;
    OpKeyPageUpDownSize:= Ord(cPageSizeFullMinus1);
    OpKeyUpDownKeepColumn:= true;
    OpKeyUpDownNavigateWrapped:= true;
    OpKeyLeftRightSwapSel:= true;
    OpKeyLeftRightSwapSelAndSelect:= false;

    OpBracketHilite:= false;
    OpBracketSymbols:= '()[]{}';
    OpBracketDistance:= 150;
  end;
end;


function IsDoubleBufferedNeeded: boolean;
begin
  {$ifdef linux}
  //Qt needs true (else caret dont blink, and tab angled borders paint bad)
  Exit(true);
  {$endif}

  Result:= WidgetSet.GetLCLCapability(lcCanDrawOutsideOnPaint) = LCL_CAPABILITY_YES;
end;


procedure InitUiOps(var Op: TUiOps);
begin
  with Op do
  begin
    VarFontName:= 'default';
    VarFontSize:= 9;

    OutputFontName:= VarFontName;
    OutputFontSize:= VarFontSize;

    DoubleBuffered:= IsDoubleBufferedNeeded;

    LexerThemes:= true;
    LexerMenuGrouped:= true;
    LexerDelayedParsingPause:= 400;
    LexerDelayedParsingSize:= 100*1000;
    LexerPostponeUntilShown:= true;

    SidebarShow:= true;
    SidebarOnRight:= false;
    SidebarTheme:= 'common_20x20';
    TreeTheme:= 'default_16x16';
    ToolBarTheme:= 'default_24x24';

    LangName:= '';
    ThemeUi:= '';
    ThemeSyntax:= '';
    ThemeUi_Loaded:= false;
    ThemeSyntax_Loaded:= false;

    AutocompleteHtml_Lexers:= '.*HTML.*|\bPHP\b';
    AutocompleteCss_Lexers:= 'CSS';

    PyLibrary:= InitPyLibraryPath;
    PictureTypes:= 'bmp,png,jpg,jpeg,gif,ico';

    MaxFileSizeToOpen:= 1000;
    MaxFileSizeForLexer:= 2;
    MaxRangesForCodeTree:= 9000;

    AutocompleteCss:= true;
    AutocompleteHtml:= true;
    AutocompleteAutoshowCharCount:= 0;
    AutocompleteTriggerChars:= '';
    AutocompleteCommitChars:= ' ,;/\''"';
    AutocompleteCloseChars:= '<>()[]{}=';
    AutocompleteAddOpeningBracket:= true;
    AutocompleteUpDownAtEdge:= 1; //cudWrap
    AutoCloseBrackets:= '([{';

    ListboxCentered:= true;
    ListboxSizeX:= 450;
    ListboxSizeY:= 300;
    ListboxCompleteSizeX:= 550;
    ListboxCompleteSizeY:= 200;
    ListboxFuzzySearch:= true;
    ListboxHotkeyFontSizeDelta:= 0; //2 gives too small hotkey font on Lin/Win

    TabAnimation:= false;
    TabsDisabled:= false;
    TabVarWidth:= false;
    TabMultiline:= false;
    TabAngled:= {$ifdef darwin} false {$else} true {$endif};
    TabFlat:= false;
    TabWidth:= 170;
    TabWidthMin:= 40;
    TabWidthMax:= 300;
    TabHeight:= 26;
    TabHeightInner:= TabHeight-1;
    TabSpacer:= 2;
    TabPosition:= 0;
    TabColorFull:= false;
    TabShowX:= 1; //show all
    TabShowXSize:= 14;
    TabShowPlus:= true;
    TabDblClickClose:= false;
    TabNumbers:= false;
    TabNewNearCurrent:= false;
    TabRecentOnClose:= false;
    TabButtonLayout:= '<>,v';
    TabPreviewFontStyle:= 'iu';
    TabSwitcherDialog:= true;

    MaxHistoryEdits:= 20;
    MaxHistoryMenu:= 10;
    MaxHistoryFiles:= 25;

    FindSuggestSel:= false;
    FindSuggestWord:= true;
    FindSuggestInSelection:= false;
    FindSelCase:= 2;
    FindShow_FindFirst:= true;
    FindShow_MarkALl:= true;
    FindShow_SelectAll:= true;
    FindShow_Extract:= true;
    FindShow_ReplaceGlobal:= true;
    FindIndentVert:= -5;
    FindIndentHorz:= 10;
    FindMultiLineScale:= 2.5;
    FindSeparateForm:= false;

    EscapeClose:= false;
    EscapeCloseConsole:= true;
    //ConsoleCompact:= false;
    ConsoleWordWrap:= true;
    InputHeight:= 26;
    InitialDir:= '';

    ExportHtmlNumbers:= false;
    ExportHtmlFontSize:= 12;
    ExportHtmlFontName:= 'Courier New';

    TreeAutoSync:= true;
    TreeTimeFill:= 2000;
    //TreeTimeCaret:= 300;
    TreeShowIcons:= true;
    TreeShowTooltips:= true;
    TreeFilterLayout:= 1;
    TreeSublexers:= false;

    PyChangeSlow:= 2000;
    PyInitLog:= true;

    NewdocLexer:= '';
    NewdocEnc:= 'utf8';
    NewdocEnds:= 0;

    DefaultEncUtf8:= {$ifdef windows} false {$else} true {$endif};
    ViewerBinaryWidth:= 100;

    StatusNoSel:= '{_ln} {y}, {_col} {xx}';
    StatusSmallSel:= '{_ln} {y}, {_col} {xx}, {_sel}';
    StatusStreamSel:= '{_ln} {y}, {_col} {xx}, {sel} {_linesel}';
    StatusColSel:= '{sel}x{cols} {_sel}';
    StatusCarets:= '{carets} {_carets}, {sel} {_linesel}';

    StatusPanels:= 'caret,C,180|enc,C,125|ends,A,45|lexer,C,140|tabsize,A,75|selmode,A,15|msg,L,4000';
    StatusHeight:= TabHeight;
    StatusTime:= 5;
    StatusAltTime:= 7;

    ScrollbarWidth:= 14;
    ScrollbarBorderSize:= 0;
    ScrollbarArrowSize:= 3;

    ProgressbarWidth:= 50;
    ProgressbarHeightSmall:= 6;

    ShowMenubar:= true;
    ShowStatusbar:= true;
    ShowToolbar:= false;
    ShowActiveBorder:= true;
    ShowTitlePath:= false;

    Scale:= 100;
    ScaleFont:= 100;

    ReopenSession:= true;
    AutoSaveSession:= false;
    ShowFormsOnTop:= false;
    ShowMenuDialogsWithBorder:= {$ifdef LCLGTK2} true {$else} false {$endif};
    UndoPersistent:= '';

    FloatGroupsInTaskbar:= true;
    OneInstance:= false;
    NotificationEnabled:= true;
    NotificationTimeSeconds:= 2;
    NonTextFiles:= 0;
    NonTextFilesBufferKb:= 64;
    ReloadFollowTail:= true;
    ReloadUnsavedConfirm:= true;
    FullScreen:= 'tp';
    MouseGotoDefinition:= 'a';
    LogDebug:= false;
    LogConsole:= false;

    Emmet_AddSlashToEmptyTags:= true;
    Emmet_CommentTags:= false;
    Emmet_IndentNested:= true;
    Emmet_SingleLine:= false;
    Emmet_TrimLineMarkers:= true;
    Emmet_WordWrap:= false;

    HotkeyFindDialog:= 'Ctrl+F';
    HotkeyReplaceDialog:= 'Ctrl+R';
    HotkeyFindFirst:= 'Alt+Enter';
    HotkeyFindNext:= '';
    HotkeyFindPrev:= 'Shift+Enter';
    HotkeyReplaceAndFindNext:= 'Alt+Z';
    HotkeyReplaceNoFindNext:= 'Ctrl+Alt+Z';
    HotkeyReplaceAll:= 'Alt+A';
    HotkeyReplaceGlobal:= '';
    HotkeyCountAll:= 'Alt+O';
    HotkeyExtractAll:= 'Alt+Q';
    HotkeySelectAll:= 'Alt+E';
    HotkeyMarkAll:= 'Alt+K';
    HotkeyToggleRegex:= 'Alt+R';
    HotkeyToggleCaseSens:= 'Alt+C';
    HotkeyToggleWords:= 'Alt+W';
    HotkeyToggleWrapped:= 'Alt+N';
    HotkeyToggleInSelect:= 'Alt+X';
    HotkeyToggleMultiline:= 'Alt+M';
    HotkeyToggleConfirmRep:= 'Alt+Y';
    HotkeyToggleTokens:= 'Alt+T';
  end;
end;


procedure SReplaceSpecialFilenameChars(var S: string);
begin
  S:= StringReplace(S, '/', '_', [rfReplaceAll]);
  S:= StringReplace(S, '\', '_', [rfReplaceAll]);
  S:= StringReplace(S, '*', '_', [rfReplaceAll]);
  S:= StringReplace(S, ':', '_', [rfReplaceAll]);
  S:= StringReplace(S, '<', '_', [rfReplaceAll]);
  S:= StringReplace(S, '>', '_', [rfReplaceAll]);
end;

function GetAppLexerSpecificConfig(ALexer: string; ADefaultConfig: boolean=false): string;
var
  dir: string;
begin
  //support none-lexer here
  if ALexer='' then
    ALexer:= '-';
  SReplaceSpecialFilenameChars(ALexer);

  if ADefaultConfig then
    dir:= AppDir_SettingsDefault
  else
    dir:= AppDir_Settings;

  Result:= dir+DirectorySeparator+'lexer '+ALexer+'.json';
end;

function GetAppKeymap_LexerSpecificConfig(AName: string): string;
begin
  //support none-lexer
  if AName='' then
    AName:= '-';
  SReplaceSpecialFilenameChars(AName);
  Result:= AppDir_Settings+DirectorySeparator+'keys lexer '+AName+'.json';
end;


function DoOps_HotkeyStringId_To_CommandCode(const AId: string): integer;
begin
  //plugin item 'module,method'
  if Pos(',', AId)>0 then
  begin
    Result:= CommandPlugins_GetIndexFromModuleAndMethod(AId);
    if Result>=0 then
      Inc(Result, cmdFirstPluginCommand);
  end
  else
    //usual item
    Result:= StrToIntDef(AId, -1);
end;


function DoReadOneStringFromFile(const AFilename: string): string;
var
  f: TextFile;
begin
  Result:= '';
  Assign(f, AFilename);
  Reset(f);
  if IOResult=0 then
  begin
    if not Eof(f) then
      Readln(f, Result);
    CloseFile(f);
  end;
end;

function DoReadContentFromFile(const AFilename: string): string;
var
  L: TStringList;
begin
  Result:= '';
  if not FileExistsUTF8(AFilename) then exit;

  L:= TStringList.Create;
  try
    L.LoadFromFile(AFilename);
    L.TextLineBreakStyle:= tlbsLF;
    if L.Count>0 then
      Result:= L.Text;
  finally
    FreeAndNil(L);
  end;
end;

procedure DoWriteStringToFile(const AFilename, AText: string);
var
  f: TextFile;
begin
  Assign(f, AFilename);
  Rewrite(f);
  if IOResult=0 then
  begin
    Write(f, AText);
    CloseFile(f);
  end;
end;


function DoLexerDetectByFilenameOrContent(const AFilename: string;
  AChooseFunc: TecLexerChooseFunc): TecSyntAnalyzer;
var
  Item: TAppKeyValue;
  ext, sLine, res: string;
  i: integer;
begin
  //detect by filename
  res:= AppConfig_Detect.GetValue(ExtractFileName(AFilename), '');
  if res<>'' then
    exit(AppManager.FindLexerByName(res));

  //detect by extention
  ext:= ExtractFileExt(AFilename);
  if ext<>'' then
  begin
    res:= AppConfig_Detect.GetValue('*'+ext, '');
    if res<>'' then
      exit(AppManager.FindLexerByName(res));
  end;

  //detect by first line
  if AppConfig_DetectLine.Count>0 then
  begin
    sLine:= DoReadOneStringFromFile(AFilename);
    if sLine<>'' then
    begin
      for i:= 0 to AppConfig_DetectLine.Count-1 do
      begin
        Item:= TAppKeyValue(AppConfig_DetectLine[i]);
        if SRegexMatchesString(sLine, Item.Key, true) then
          exit(AppManager.FindLexerByName(Item.Value));
      end;
    end;
  end;

  Result:= AppManager.FindLexerByFilename(AFilename, AChooseFunc);
end;

function DoOps_CommandCode_To_HotkeyStringId(ACmd: integer): string;
begin
  if AppCommandCategory(ACmd)=categ_Plugin then
    with TAppCommandInfo(AppCommandList[ACmd-cmdFirstPluginCommand]) do
    begin
      Result:= ItemModule+','+ItemProc;
      if ItemProcParam<>'' then
        Result+= ','+ItemProcParam;
    end
  else
    Result:= IntToStr(ACmd);
end;

procedure DoOps_SaveKeyItem(K: TATKeymapItem; const path, ALexerName: string;
  ALexerSpecific: boolean);
var
  c: TJSONConfig;
  sl: TStringList;
  i: integer;
begin
  c:= TJSONConfig.Create(nil);
  sl:= TStringlist.create;
  try
    try
      c.Formatted:= true;
      if ALexerSpecific then
        c.Filename:= GetAppKeymap_LexerSpecificConfig(ALexerName)
      else
        c.Filename:= AppFile_Hotkeys;
    except
      exit;
    end;

    c.SetValue(path+'/name', K.Name);

    sl.clear;
    for i:= 0 to High(TATKeyArray.Data) do
      if K.Keys1.Data[i]<>0 then
        sl.Add(ShortCutToText(K.Keys1.Data[i]));
    c.SetValue(path+'/s1', sl);

    sl.clear;
    for i:= 0 to High(TATKeyArray.Data) do
      if K.Keys2.Data[i]<>0 then
        sl.Add(ShortCutToText(K.Keys2.Data[i]));
    c.SetValue(path+'/s2', sl);
  finally
    c.Free;
    sl.Free;
  end;
end;


procedure DoOps_SaveKey_ForPluginModuleAndMethod(AOverwriteKey: boolean;
  const AMenuitemCaption, AModuleName, AMethodName, ALexerName, AHotkey: string);
const
  cKeyComboSeparator = '|';
var
  c: TJSONConfig;
  sl: TStringList;
  path, s_item: string;
  Sep: TATStringSeparator;
begin
  //check-1: is key registered for any other command?
  if not AOverwriteKey then
    if AppKeymapHasDuplicateForKey(AHotkey, cKeyComboSeparator) then exit;

  c:= TJSONConfig.Create(nil);
  sl:= TStringlist.create;
  try
    try
      c.Formatted:= true;
      if ALexerName<>'' then
        c.Filename:= GetAppKeymap_LexerSpecificConfig(ALexerName)
      else
        c.Filename:= AppFile_Hotkeys;
    except
      exit;
    end;

    path:= AModuleName+','+AMethodName;

    //check-2: this command has already any key?
    if not AOverwriteKey then
      if c.GetValue(path+'/s1', sl, '') then exit;

    c.SetValue(path+'/name', Utf8Decode(AMenuitemCaption));

    sl.Clear;
    Sep.Init(AHotkey, cKeyComboSeparator);
    repeat
      if not Sep.GetItemStr(s_item) then Break;
      sl.Add(s_item);
    until false;
    c.SetValue(path+'/s1', sl);
  finally
    c.Free;
    sl.Free;
  end;
end;

function AppListboxItemHeight(AScale, ADoubleHeight: boolean): integer;
begin
  Result:= UiOps.VarFontSize * 18 div 10 +2;

  {$ifdef windows}
  Result:= Result * Screen.PixelsPerInch div 96;
  {$endif}

  if ADoubleHeight then
    Result:= Result * 185 div 100;
  if AScale then
    Result:= AppScaleFont(Result);
end;


procedure DoLexerEnum(L: TStringList; AlsoDisabled: boolean = false);
var
  i: integer;
begin
  with AppManager do
    for i:= 0 to LexerCount-1 do
      if AlsoDisabled or not Lexers[i].Internal then
        L.Add(Lexers[i].LexerName);

  with AppManagerLite do
    for i:= 0 to LexerCount-1 do
      L.Add(Lexers[i].LexerName+msgLiteLexerSuffix);
end;

{
procedure DoLexerSave(an: TecSyntAnalyzer);
begin
  if Assigned(an) then
    an.SaveToFile(GetAppLexerFilename(an.LexerName));
end;
}

function CommandPlugins_GetIndexFromModuleAndMethod(const AText: string): integer;
var
  Sep: TATStringSeparator;
  SModule, SProc, SProcParam: string;
  AppCmd: TAppCommandInfo;
  i: integer;
begin
  Result:= -1;

  Sep.Init(AText);
  Sep.GetItemStr(SModule);
  Sep.GetItemStr(SProc);
  Sep.GetItemStr(SProcParam);

  if SModule='' then exit;
  if SProc='' then exit;

  for i:= 0 to AppCommandList.Count-1 do
  begin
    AppCmd:= TAppCommandInfo(AppCommandList[i]);
    if (AppCmd.ItemModule=SModule) and
      (AppCmd.ItemProc=SProc) and
      (AppCmd.ItemProcParam=SProcParam) then
      exit(i);
  end;
end;


procedure CommandPlugins_UpdateSubcommands(const AText: string);
const
  cSepRoot=';';
  cSepParams=#10;
  cSepNameParam=#9;
var
  Sep: TATStringSeparator;
  SModule, SProc, SParams, SItem, SItemParam, SItemCaption: string;
  CmdItem: TAppCommandInfo;
  N: integer;
begin
  Sep.Init(AText, cSepRoot);
  Sep.GetItemStr(SModule);
  Sep.GetItemStr(SProc);
  Sep.GetRest(SParams);

  //del items for module/method
  for N:= AppCommandList.Count-1 downto 0 do
    with TAppCommandInfo(AppCommandList[N]) do
      if (ItemModule=SModule) and (ItemProc=SProc) and (ItemProcParam<>'') then
        AppCommandList.Delete(N);

  //add items for SParams
  Sep.Init(SParams, cSepParams);
  repeat
    if not Sep.GetItemStr(SItem) then Break;
    SSplitByChar(SItem, cSepNameParam, SItemCaption, SItemParam);

    CmdItem:= TAppCommandInfo.Create;
    CmdItem.ItemModule:= SModule;
    CmdItem.ItemProc:= SProc;
    CmdItem.ItemProcParam:= SItemParam;
    CmdItem.ItemCaption:= SItemCaption;
    CmdItem.ItemFromApi:= true;

    AppCommandList.Add(CmdItem);
  until false;
end;


function GetAppLangFilename: string;
begin
  if UiOps.LangName='' then
    Result:= ''
  else
    Result:= AppDir_DataLang+DirectorySeparator+UiOps.LangName+'.ini';
end;

function EscapeLexerFilename(const ALexName: string): string;
begin
  Result:= ALexName;
  if Result<>'' then
  begin
    Result:= StringReplace(Result, ':', '_', [rfReplaceAll]);
    Result:= StringReplace(Result, '/', '_', [rfReplaceAll]);
    Result:= StringReplace(Result, '\', '_', [rfReplaceAll]);
    Result:= StringReplace(Result, '*', '_', [rfReplaceAll]);
  end;
end;

function GetLexerFilenameWithExt(ALexName, AExt: string): string;
begin
  if ALexName<>'' then
    Result:= AppDir_Lexers+DirectorySeparator+EscapeLexerFilename(ALexName)+AExt
  else
    Result:= '';
end;

function GetAppLexerMapFilename(const ALexName: string): string;
begin
  Result:= GetLexerFilenameWithExt(ALexName, '.cuda-lexmap');
end;

function GetAppLexerFilename(const ALexName: string): string;
begin
  Result:= GetLexerFilenameWithExt(ALexName, '.lcf');
end;

function GetAppLexerOpsFilename(const ALexName: string): string;
begin
  Result:= AppDir_Settings+DirectorySeparator+EscapeLexerFilename(ALexName)+'.cuda-lexops';
end;

function GetAppLexerAcpFilename(const ALexName: string): string;
begin
  Result:= AppDir_DataAutocomplete+DirectorySeparator+EscapeLexerFilename(ALexName)+'.acp';
end;

function GetAppUndoFilename(const fn: string; IsRedo: boolean): string;
const
  Ext: array[boolean] of string = ('.undo', '.redo');
begin
  Result:= ExtractFileDir(fn)+DirectorySeparator+
    '.cudatext'+DirectorySeparator+
    ExtractFileName(fn)+Ext[IsRedo];
end;

function GetAppKeymapHotkey(const ACmdString: string): string;
var
  NCode, NIndex: integer;
begin
  Result:= '';
  if Pos(',', ACmdString)=0 then
    NCode:= StrToIntDef(ACmdString, 0)
  else
  begin
    NIndex:= CommandPlugins_GetIndexFromModuleAndMethod(ACmdString);
    if NIndex<0 then exit;
    NCode:= NIndex+cmdFirstPluginCommand;
  end;

  NIndex:= AppKeymap.IndexOf(NCode);
  if NIndex<0 then exit;
  with AppKeymap[NIndex] do
    Result:= Keys1.ToString+'|'+Keys2.ToString;
end;


function SetAppKeymapHotkey(const AParams: string): boolean;
var
  Sep: TATStringSeparator;
  NCode, NIndex: integer;
  SCmd, SKey1, SKey2: string;
begin
  Result:= false;

  Sep.Init(AParams, '|');
  Sep.GetItemStr(SCmd);
  Sep.GetItemStr(SKey1);
  Sep.GetItemStr(SKey2);

  if Pos(',', SCmd)=0 then
    NCode:= StrToIntDef(SCmd, 0)
  else
  begin
    NIndex:= CommandPlugins_GetIndexFromModuleAndMethod(SCmd);
    if NIndex<0 then exit;
    NCode:= NIndex+cmdFirstPluginCommand;
  end;

  NIndex:= AppKeymap.IndexOf(NCode);
  if NIndex<0 then exit;
  with AppKeymap[NIndex] do
  begin
    Keys1.SetFromString(SKey1);
    Keys2.SetFromString(SKey2);

    //save to keys.json
    //Py API: no need lexer-specific
    DoOps_SaveKeyItem(AppKeymap[NIndex], SCmd, '', false);
  end;
  Result:= true;
end;


function AppKeymapCheckDuplicateForCommand(
  AKeymapItem: TATKeymapItem;
  const ALexerName: string;
  AOverwriteAndSave: boolean): integer;
var
  item: TATKeymapItem;
  itemKeyPtr: ^TATKeyArray;
  StrId: string;
  i: integer;
begin
  Result:= 0;

  for i:= 0 to AppKeymap.Count-1 do
  begin
    item:= AppKeymap.Items[i];
    if item.Command=AKeymapItem.Command then Continue;

    if (AKeymapItem.Keys1=item.Keys1) or
       (AKeymapItem.Keys2=item.Keys1) then itemKeyPtr:= @item.Keys1 else
    if (AKeymapItem.Keys1=item.Keys2) or
       (AKeymapItem.Keys2=item.Keys2) then itemKeyPtr:= @item.Keys2 else
    Continue;

    if AOverwriteAndSave then
    begin
      //clear in memory
      itemKeyPtr^.Clear;

      StrId:= DoOps_CommandCode_To_HotkeyStringId(item.Command);

      //save to: user.json
      DoOps_SaveKeyItem(item, StrId, '', false);
      //save to: lexer*.json
      if ALexerName<>'' then
        DoOps_SaveKeyItem(item, StrId, ALexerName, true);
    end
    else
      exit(item.Command);
  end;
end;

function AppKeymapHasDuplicateForKey(AHotkey, AKeyComboSeparator: string): boolean;
var
  item: TATKeymapItem;
  i: integer;
begin
  Result:= false;
  if AHotkey='' then exit;

  //KeyArrayToString has separator ' * '
  AHotkey:= StringReplace(AHotkey, AKeyComboSeparator, ' * ', [rfReplaceAll]);

  for i:= 0 to AppKeymap.Count-1 do
  begin
    item:= AppKeymap.Items[i];
    if (item.Keys1.ToString=AHotkey) or
       (item.Keys2.ToString=AHotkey) then exit(true);
  end;
end;


procedure AppKeymap_ApplyUndoList(AUndoList: TATKeymapUndoList);
var
  UndoItem: TATKeymapUndoItem;
  i, ncmd, nitem: integer;
begin
  for i:= 0 to AUndoList.Count-1 do
  begin
    UndoItem:= AUndoList[i];

    ncmd:= DoOps_HotkeyStringId_To_CommandCode(UndoItem.StrId);
    if ncmd<0 then Continue;

    nitem:= AppKeymap.IndexOf(ncmd);
    if nitem<0 then Continue;

    AppKeymap.Items[nitem].Keys1:= UndoItem.KeyArray1;
    AppKeymap.Items[nitem].Keys2:= UndoItem.KeyArray2;
  end;
end;

procedure MsgStdout(const Str: string; AllowMsgBox: boolean = false);
begin
  {$ifdef windows}
  if AllowMsgBox then
    MsgBox(Str, MB_OK+MB_ICONINFORMATION);
  {$else}
  System.Writeln(Str);
  {$endif}
end;

procedure MsgLogConsole(const AText: string);
begin
  AppConsoleQueue.Push(AText);
end;


function AppEncodingShortnameToFullname(const S: string): string;
var
  i: integer;
begin
  Result:= '';
  if S='' then exit;
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if SameText(S, ShortName) then
        Exit(Name);
end;

function AppEncodingFullnameToShortname(const S: string): string;
var
  i: integer;
begin
  Result:= '';
  if S='' then exit;
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if SameText(S, Name) then
        Exit(LowerCase(ShortName));
end;

function AppEncodingListAsString: string;
var
  i: integer;
begin
  Result:= '';
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if ShortName<>'' then
        Result:= Result + LowerCase(ShortName) + #10;
end;

procedure UpdateFormOnTop(F: TForm);
begin
  if UiOps.ShowFormsOnTop then
    F.FormStyle:= fsSystemStayOnTop
  else
    F.FormStyle:= fsNormal;
end;


procedure DoStatusbarTextByTag(AStatus: TATStatus; ATag: PtrInt; const AText: string);
var
  NIndex: integer;
begin
  NIndex:= AStatus.FindPanel(ATag);
  if NIndex>=0 then
    AStatus.Captions[NIndex]:= AText;
end;

procedure DoStatusbarHintByTag(AStatus: TATStatus; ATag: PtrInt; const AText: string);
var
  NIndex: integer;
begin
  NIndex:= AStatus.FindPanel(ATag);
  if NIndex>=0 then
    AStatus.Hints[NIndex]:= AText;
end;

function IsFileTooBigForOpening(const AFilename: string): boolean;
begin
  Result:= (AFilename<>'') and (FileSize(AFileName) div (1024*1024) >= UiOps.MaxFileSizeToOpen);
end;

function IsFileTooBigForLexer(const AFilename: string): boolean;
begin
  Result:= (AFilename<>'') and (FileSize(AFilename) div (1024*1024) >= UiOps.MaxFileSizeForLexer);
end;


procedure DoLexerDetect(const AFilename: string;
  out Lexer: TecSyntAnalyzer;
  out LexerLite: TATLiteLexer;
  out LexerName: string;
  AChooseFunc: TecLexerChooseFunc);
begin
  LexerName:= '';
  Lexer:= nil;
  LexerLite:= nil;
  if AFilename='' then exit;

  if IsFileTooBigForLexer(AFilename) then
  begin
    LexerLite:= AppManagerLite.FindLexerByFilename(AFilename);
  end
  else
  begin
    Lexer:= DoLexerDetectByFilenameOrContent(AFilename, AChooseFunc);
    if Lexer=nil then
      LexerLite:= AppManagerLite.FindLexerByFilename(AFilename);
  end;

  if Assigned(Lexer) then
    LexerName:= Lexer.LexerName
  else
  if Assigned(LexerLite) then
    LexerName:= LexerLite.LexerName+msgLiteLexerSuffix;
end;


function FixFontMonospaced(const AName: string): string; inline;
begin
  Result:= AName;
  {
  //commented, it slows down start by 10-20ms
  if (AName='') or (Screen.Fonts.IndexOf(AName)>=0) then
    Result:= AName
  else
    Result:= 'Courier';
    }
end;


procedure FixFormPositionToDesktop(F: TForm);
const
  cReservePixels = 100;
var
  R: TRect;
begin
  R:= Screen.DesktopRect;
  F.Left:= Max(F.Left, R.Left);
  F.Left:= Min(F.Left, R.Right-F.Width);
  F.Top:= Min(F.Top, R.Bottom-cReservePixels);
end;

procedure FixRectPositionToDesktop(var F: TRect);
const
  cReservePixels = 200;
var
  R: TRect;
  w, h: integer;
begin
  w:= F.Width;
  h:= F.Height;

  R:= Screen.DesktopRect;
  F.Left:= Max(F.Left, R.Left);
  F.Left:= Min(F.Left, R.Right-F.Width);
  F.Top:= Min(F.Top, R.Bottom-cReservePixels);

  F.Right:= F.Left+w;
  F.Bottom:= F.Top+h;
end;

{ TAppFileProps }

class operator TAppFileProps.= (const a, b: TAppFileProps): boolean;
begin
  Result:=
    (a.Exists=b.Exists) and
    (a.Size=b.Size) and
    (a.Age=b.Age);
end;


{ TAppKeyValues }

procedure TAppKeyValues.Add(const AKey, AValue: string);
var
  Item: TAppKeyValue;
begin
  Item:= TAppKeyValue.Create;
  Item.Key:= AKey;
  Item.Value:= AValue;
  inherited Add(Item);
end;

function TAppKeyValues.GetValue(const AKey, ADefValue: string): string;
var
  Item: TAppKeyValue;
  i: integer;
begin
  for i:= 0 to Count-1 do
  begin
    Item:= TAppKeyValue(Items[i]);
    if Item.Key=AKey then
      exit(Item.Value);
  end;
  Result:= ADefValue;
end;

function AppScale(AValue: integer): integer; inline;
begin
  Result:= AValue * UiOps.Scale div 100;
end;

function AppScaleFont(AValue: integer): integer;
begin
  if UiOps.ScaleFont=0 then
    Result:= AppScale(AValue)
  else
    Result:= AValue * UiOps.ScaleFont div 100;
end;

{
procedure AppScaleScrollbar(C: TATScroll);
begin
  C.WidthInitial:= UiOps.ScrollbarWidth;
  C.ScalePercents:= UiOps.Scale;
end;
}

procedure DoMenuitemEllipsis(c: TMenuItem);
var
  s: string;
begin
  if c=nil then exit;
  s:= c.Caption;
  while (s<>'') and (s[Length(s)]='.') do
    SetLength(s, Length(s)-1);
  c.Caption:= s+'...';
end;


procedure AppGetFileProps(const FileName: string; out P: TAppFileProps);
var
  Rec: TSearchRec;
begin
  P.Inited:= true;
  P.Exists:= FindFirst(FileName, faAnyFile, Rec)=0;
  if P.Exists then
  begin
    P.Size:= Rec.Size;
    P.Age:= Rec.Time;
    FindClose(Rec);
  end
  else
  begin
    P.Size:= 0;
    P.Age:= 0;
  end;
end;

procedure AppUpdateWatcherFrames;
var
  i: integer;
begin
  //function is called in IdleTimer, so just exit if watcher thread is busy,
  //we will try this again on next timer tick
  if AppEventWatcher.WaitFor(1)<>wrSignaled then exit;

  AppEventLister.ResetEvent;
  try
    for i:= 0 to AppFrameListDeleting.Count-1 do
      TObject(AppFrameListDeleting[i]).Free;
    AppFrameListDeleting.Clear;

    AppFrameList2.Assign(AppFrameList1);
  finally
    AppEventLister.SetEvent;
  end;
end;


function AppCommandCategory(Cmd: integer): TAppCommandCategory;
var
  N: integer;
begin
  case Cmd of
    cmdFirstPluginCommand..cmdLastPluginCommand:
      begin
        Result:= categ_Plugin;
        N:= Cmd-cmdFirstPluginCommand;
        if N<AppCommandList.Count then
          if TAppCommandInfo(AppCommandList[N]).ItemFromApi then
            Result:= categ_PluginSub;
      end;
    cmdFirstLexerCommand..cmdLastLexerCommand:
      Result:= categ_Lexer;
    cmdFirstFileCommand..cmdLastFileCommand:
      Result:= categ_OpenedFile;
    cmdFirstRecentCommand..cmdLastRecentCommand:
      Result:= categ_RecentFile;
    else
      Result:= categ_Normal;
  end;
end;

function AppCommandHasConfigurableHotkey(Cmd: integer): boolean;
begin
  Result:= AppCommandCategory(Cmd) in [categ_Normal, categ_Plugin, categ_PluginSub];
end;

function GetAlwaysNewInstance: boolean;
var
  i: integer;
begin
  for i:= 1 to ParamCount do
    if ParamStr(i)='-n' then exit(true);
  Result:= false;
end;

procedure AppEventStringToEventData(const AEventStr: string;
  out AEvents: TAppPyEvents;
  out AEventsPrior: TAppPyEventsPrior;
  out AEventsLazy: TAppPyEventsLazy);
const
  MaxPriority = 4;
var
  Sep: TATStringSeparator;
  S: string;
  event: TAppPyEvent;
  nPrior: byte;
  bLazy: boolean;
begin
  AEvents:= [];
  FillChar(AEventsPrior, SizeOf(AEventsPrior), 0);
  FillChar(AEventsLazy, SizeOf(AEventsLazy), 0);

  Sep.Init(AEventStr);
  while Sep.GetItemStr(S) do
  begin
    nPrior:= 0;
    while S[Length(S)]='+' do
    begin
      Inc(nPrior);
      SetLength(S, Length(S)-1);
    end;

    if nPrior>MaxPriority then
      nPrior:= MaxPriority;

    bLazy:= false;
    if S[Length(S)]='~' then
    begin
      bLazy:= true;
      SetLength(S, Length(S)-1);
    end;

    for event in TAppPyEvent do
      if S=cAppPyEvent[event] then
      begin
        Include(AEvents, event);
        AEventsPrior[event]:= nPrior;
        AEventsLazy[event]:= bLazy;
        Break
      end;
  end;
end;


procedure AppEventsUpdate(const AModuleName, AEventStr, ALexerStr, AKeyStr: string);
var
  EventItem: TAppEventInfo;
  i: integer;
begin
  //find index of plugin (get first empty index if not listed)
  EventItem:= nil;
  for i:= 0 to AppEventList.Count-1 do
    with TAppEventInfo(AppEventList[i]) do
      if (ItemModule=AModuleName) then
      begin
        EventItem:= TAppEventInfo(AppEventList[i]);
        Break
      end;

  if EventItem=nil then
  begin
    EventItem:= TAppEventInfo.Create;
    AppEventList.Add(EventItem);
  end;

  //update item
  with EventItem do
  begin
    if ItemModule='' then
      ItemModule:= AModuleName;
    AppEventStringToEventData(AEventStr, ItemEvents, ItemEventsPrior, ItemEventsLazy);
    ItemLexers:= ALexerStr;
    ItemKeys:= AKeyStr;
  end;

  AppEventsMaxPrioritiesUpdate;
end;

procedure AppCommandsClearButKeepApiItems;
var
  i: integer;
begin
  for i:= AppCommandList.Count-1 downto 0 do
    with TAppCommandInfo(AppCommandList[i]) do
      if (ItemModule<>'') and (not ItemFromApi) then
        AppCommandList.Delete(i);
end;

procedure AppEventsMaxPrioritiesUpdate;
var
  ev: TAppPyEvent;
  Plugin: TAppEventInfo;
  Value, i: integer;
begin
  for ev in TAppPyEvent do
  begin
    Value:= -1;
    for i:= 0 to AppEventList.Count-1 do
    begin
      Plugin:= TAppEventInfo(AppEventList[i]);
      if ev in Plugin.ItemEvents then
        Value:= Max(Value, Plugin.ItemEventsPrior[ev]);
    end;
    AppEventsMaxPriorities[ev]:= Value;
  end;
end;


initialization

  InitDirs;
  InitEditorOps(EditorOps);
  InitUiOps(UiOps);

  AppAlwaysNewInstance:= GetAlwaysNewInstance;
  AppConsoleQueue:= TAppConsoleQueue.Create;
  AppCommandList:= TFPList.Create;
  AppEventList:= TFPList.Create;
  AppTreeHelpers:= TFPList.Create;

  AppKeymap:= TATKeymap.Create;
  InitKeymapFull(AppKeymap);
  InitKeymapForApplication(AppKeymap);

  FillChar(AppEventsMaxPriorities, SizeOf(AppEventsMaxPriorities), 0);
  FillChar(AppBookmarkSetup, SizeOf(AppBookmarkSetup), 0);
  AppBookmarkImagelist:= TImageList.Create(nil);

  AppShortcutEscape:= ShortCut(VK_ESCAPE, []);
  AppShortcutShiftTab:= ShortCut(VK_TAB, [ssShift]);

  Mouse.DragImmediate:= false;
  Mouse.DragThreshold:= 12;

  AppConfig_Detect:= TAppKeyValues.Create;
  AppConfig_DetectLine:= TAppKeyValues.Create;
  AppConfig_PGroups:= TAppKeyValues.Create;

  ////detection of Shell files
  ////disabled: it detects Python files with shebang
  //AppConfig_DetectLine_Keys.Add('\#!.+');
  //AppConfig_DetectLine_Values.Add('Bash script');

  //detection of XML
  AppConfig_DetectLine.Add('<\?xml .+', 'XML');

  AppFrameList1:= TFPList.Create;
  AppFrameList2:= TFPList.Create;
  AppFrameListDeleting:= TFPList.Create;
  AppEventLister:= TEvent.Create(nil, true, true, '');
  AppEventWatcher:= TEvent.Create(nil, true, true, '');

  AppApiFlatTheme:= ATFlatTheme;

finalization

  FreeAndNil(AppEventWatcher);
  FreeAndNil(AppEventLister);
  FreeAndNil(AppFrameListDeleting);
  FreeAndNil(AppFrameList2);
  FreeAndNil(AppFrameList1);

  FreeAndNil(AppConfig_PGroups);
  FreeAndNil(AppConfig_DetectLine);
  FreeAndNil(AppConfig_Detect);
  FreeAndNil(AppKeymap);
  FreeAndNil(AppBookmarkImagelist);

  FreeAndNil(AppTreeHelpers);
  FreeAndNil(AppEventList);
  FreeAndNil(AppCommandList);
  FreeAndNil(AppConsoleQueue);

end.


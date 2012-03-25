program SimpleTextSearch;

uses
  Forms,
  MainUnit in 'MainUnit.pas' {FmSimpleReplace};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFmSimpleReplace, FmSimpleReplace);
  Application.Run;
end.


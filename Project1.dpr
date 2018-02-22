program Project1;

uses
  System.StartUpCopy,
  FMX.Forms,
  Unit1 in 'Unit1.pas' {TestForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTestForm, TestForm);
  Application.Run;
end.

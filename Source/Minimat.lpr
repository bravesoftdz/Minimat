program Minimat;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, FormPrincipal, EvalExpres, MotGraf2d, MotGraf3d, FormGraf3D,
  FormConfig, FrameCfgSynEdit, FrameCfgGeneral, FrameCfgPanCom
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.CreateForm(TfrmGraf3D, frmGraf3D);
  Application.CreateForm(TConfig, Config);
  Application.Run;
end.


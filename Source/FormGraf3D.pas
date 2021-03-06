unit FormGraf3D;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, FileUtil, SynEdit, Forms, Controls, Graphics, Dialogs,
  ActnList, Menus, ExtCtrls, StdCtrls, EvalExpres, MotGraf3d;
const
  NUM_CUAD = 20;
  ZOOM_INI = 12;

type
  { TfrmGraf3D }
  TfrmGraf3D = class(TForm)
    btnGrafic: TButton;
    ColorButton1: TColorButton;
    Edit1: TEdit;
    Label1: TLabel;
    PaintBox1: TPaintBox;
    Panel1: TPanel;
    procedure btnGraficClick(Sender: TObject);
    procedure Edit1KeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    exp: TEvalExpres;
    mot: TMotGraf;
    cuad: array[0..NUM_CUAD-1,0..NUM_CUAD-1] of Double;
  public
    procedure DibujarEjes;
  end;

var
  frmGraf3D: TfrmGraf3D;

implementation
{$R *.lfm}
procedure TfrmGraf3D.btnGraficClick(Sender: TObject);
var
  ix, iy: Integer;      //índices para la matriz
  varx, vary: Integer;  //índices a variable
  x, y: Double;         //valores de variables
  e: Texpre;
begin
  //Primera evaluación para determinar sinatxis
  varx := exp.AsigVariable('x', 0);  //crea variable
  vary := exp.AsigVariable('y', 0);  //crea variable
  exp.EvaluarLinea(Edit1.Text);   //Inicia cadena
  if exp.ErrorStr<>'' then begin
     Application.MessageBox(PChar(exp.ErrorStr), '');
     exit;
  end;
  //No hubo error. Calcula valores para graficar
  x := -10;    //Valor inicial de exploración
  y := -10;    //Valor inicial de exploración
  for ix:=0 to NUM_CUAD-1 do begin
    y:=-10;
    for iy := 0 to NUM_CUAD-1 do begin
      exp.vars[varx].valor := x;  //asigna rápidamente
      exp.vars[vary].valor := y;  //asigna rápidamente
      //Evalúa rápidamente la expresión, llamando directamente a CogExpresion
      exp.cEnt.CurPosIni;       //Inicia cursor
      e := exp.CogExpresion(0);  //coge expresión
      cuad[ix,iy] := e.valNum;
      y += 1;
    end;
    x += 1;
  end;
  PaintBox1.Invalidate;
end;

procedure TfrmGraf3D.PaintBox1Paint(Sender: TObject);
var
  ix, iy: Integer;
begin
  //Dibuja en el espacio
  mot.Clear;
  DibujarEjes;
  mot.PenColor := ColorButton1.ButtonColor;
  //Líneas en X
  for iy := 0 to NUM_CUAD-1 do begin
    for ix:=0 to NUM_CUAD-2 do begin
      mot.Line(ix  , iy, cuad[ix  , iy],
               ix+1, iy, cuad[ix+1, iy]);
    end;
  end;
  //Líneas en Y
  for ix := 0 to NUM_CUAD-1 do begin
    for iy:=0 to NUM_CUAD-2 do begin
      mot.Line(ix, iy  , cuad[ix, iy],
               ix, iy+1, cuad[ix, iy+1]);
    end;
  end;
end;
procedure TfrmGraf3D.Edit1KeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then begin
    btnGraficClick(self);
    Key := #0;
  end;
end;
procedure TfrmGraf3D.FormCreate(Sender: TObject);
begin
  exp := TEvalExpres.Create;
  mot:= TMotGraf.Create(PaintBox1);
  mot.Zoom := ZOOM_INI;
  mot.x_des:=10;
  mot.y_des:=120;
  mot.Alfa:=-0.78;
  mot.Fi:=0.78;
  mot.backColor:=clBlack;
  ColorButton1.ButtonColor:=$60FF60;
end;
procedure TfrmGraf3D.FormDestroy(Sender: TObject);
begin
  mot.Destroy;
  exp.Destroy;
end;
procedure TfrmGraf3D.DibujarEjes;
begin
  mot.PenColor := clYellow;
  mot.Line(0,0,0, 5, 0, 0);
  mot.Line(0,0,0, 0, 5, 0);
  mot.Line(0,0,0, 0, 0, 5);
  mot.polilinea3(0,0,0,3,0,0,3,3,0,0,3,0);
end;

end.


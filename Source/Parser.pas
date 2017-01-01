{}
//{$DEFINE mode_inter}  //mode_inter->Modo intérprete  mode_comp->Modo compilador
unit Parser;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, LCLType, Dialogs, lclProc, Graphics, Forms,
  SynEditHighlighter, SynFacilBasic, XPresParser, XpresBas, XpresTypes, XpresElements,
  MisUtils, GenCod;

type

 { TCompiler }

  TCompiler = class(TGenCod)
  private
    procedure CompileBlockIF;
    function ProcesaAsignacion(var newVar: string): boolean;
  protected
    //function GetOperand: TOperand; override;
    procedure TipDefecNumber(var Op: TOperand; toknum: string); override;
    procedure CaptureParams; override;
    procedure SkipWhites; override;
  public
    mem   : TStringList;   //Para almacenar el código de salida del compilador
    function EOBlock: boolean;
    function EOExpres: boolean;
    procedure ExecuteInstruction;
    procedure ExecuteStr(str: string);
    procedure ResetCompiler;
//    procedure CompileCurBlock;
//    procedure CompilarArc;
//    procedure Compilar(NombArc: string; LinArc: Tstrings);
    //Estos métodos solo sirven para hacer públicos los métodos protegidos
    procedure CreateVariable(const varName: string; typ: ttype);
    procedure CreateVariable(varName, varType: string);
  public  //Inicialización
    constructor Create; override;
    destructor Destroy; override;
  end;

{  TSecAct = ( bloNormal,  {Bloque normal, como el programa principal o el cuerpo de alguna
                           estructura "IF", lo que va entre THEN y ELSE.}
              bloEvaluac  {BLoque en donde se espera un resultado booleand para tomar
                          una decisiónm como la expresión que va entre el IF y el THEN.}
            );}
//procedure Compilar(NombArc: string; LinArc: Tstrings);
var
  cxp : TCompiler;

implementation

//Funciones de acceso al compilador. Facilitan el acceso de forma resumida.
procedure Code(cod: string);
begin
  cxp.mem.Add(cod);
end;
procedure GenError(msg: string);
begin
  cxp.GenError(msg);
end;
function HayError: boolean;
begin
  Result := cxp.HayError;
end;
procedure CreateVariable(varName, varType: string);
begin
  cxp.CreateVariable(varName, varType);
end;
{Incluye el código del compilador. Aquí tendrá acceso a todas las variables públicas
 de XPresParser}
//Métodos OVERRIDE
function TCompiler.EOBlock: boolean;
//Indica si se ha llegado el final de un bloque
begin
  Result := cIn.tokType = tkBlkDelim;
end;
function TCompiler.EOExpres: boolean;
//Indica si se ha llegado al final de una expresión
begin
  Result := (cIn.tokType = tkExpDelim) or (cIn.tokType = tkEol);
end;
function TCompiler.ProcesaAsignacion(var newVar: string): boolean;
{Verifica si la instrucción actual es de tipo asignación. Si es así, ejecuta la
 asignación. Si la variable a asignar no existe, se crea.
 Las asignaciones, se porcesan de forma diferente a las expresiones normales,
 porque, en este lenguaje, las asignaciones, también declaran variables y porque
 además se está permitiendo usar las asignaciones con el operador "=", en lugar
 del operador formal que es ":=".}
var
  posIni, posFin: TPosCont;
  Op1: TOperand;   //para representar a la variable
  opr: TxpOperator;  //para representar al operador de asignación
  exp: TOperand;   //para representar la expresión a asignar
  Nueva: Boolean;
begin
  Result := false;
  if cIn.tokType <> tkIdentif then exit;
  //Sigue un identificador, verifica si ya ha sido declarado.
  if FindPredefName(cIn.tok) = eltNone then Nueva := true
  else Nueva := false;
  //Sigue un identificador desconocido. falta ver si es asignación.
  posIni := cIn.PosAct;    //Guarda posición, por si acaso
  newVar := Cin.tok;
  cIn.Next;   //toma identificador
  cIn.SkipWhitesNoEOL;
  if (cIn.tokType = tkOperator) and
     ( cIn.tok = '=' ) then //Se acepta ambos operadores
  begin
    cIn.Next;   //toma operador
    cIn.SkipWhitesNoEOL;
    //Evalua la expresión para deducir el tipo.
//    exp := GetOperand;  //puede generar error
    GetExpression(0);
    exp := res;   //guarda el resultado, para asignarlo luego
    posFin := cIn.PosAct;   //guarda la posición final de la expresión.
    if Perr.HayError then exit(false);   //sale con el puntero en la posición del error
    //Se pudo ejecutar la expresión. Ya se sabe el tipo
    if nueva then begin
//debugln('Creando:'+newVar);
      cIn.PosAct := posIni;  //Deja quí aquí, porque es un buen lugar en caso de error en CreateVariable().
      CreateVariable(newVar, exp.typ);   //crea la variable
      if Perr.HayError then begin
        exit(false);
      end;
    end;
    cIn.PosAct := posIni;  //retorna posición, para obtener fácilmente el operando
    Op1 := GetOperand;   {Toma operando que puede ser la variable nueva creada, o algún
                          identificador concoido, al que se le prentende asignar algo.}
    if Perr.HayError then exit;
    {Ya tenemos a los, dos operandos de la asignación. Lo más apropiado es usar
     la función Evaluar, para que las cosas sigan su curso, normal.}
    opr := Op1.FindOperator('=');  //Ubica a su operador de asignación. Debe existir
    if opr = nullOper then begin
      GenError('No está definido el operador "=" para' + Op1.typ.name);
      exit;       //sale
    end;
    cIn.PosAct := posFin;  {Deja el cursor aquí, porque es el mejor lugar para el cursor
                            en caso de error, y también porque aquí se debe quedar el
                            cursor después de evaluar.}
    Evaluar(Op1, opr, exp);    //Evalua en "res". Puede geenerar error.
    if Perr.HayError then exit(false);
    exit(true);        //si es asignación
  end;
  //no sigue asignación
  cIn.PosAct := posIni;    //solo retorna posición
end;
procedure TCompiler.TipDefecNumber(var Op: TOperand; toknum: string);
{Sobreescribimos este método para que reconozca a todos los números como flotantes.}
begin
  Op.catTyp := t_float;   //es flotante
  Op.size := 8;
  Op.valFloat := StrToFloat(toknum);  //No debería fallar, si el lexer hace bien su trabajo
  Op.typ := tipFlt;  //solo hay un tipo flotante
end;
procedure TCompiler.CompileBlockIF;
var
  valor, valor2: Boolean;
begin
  cIn.Next;  //toma IF
  GetBoolExpression; //evalua expresión
  if PErr.HayError then exit;
  valor := res.valBool;
  if cIn.tokL<> 'then' then begin
    GenError('Se esperaba "then".');
    exit;
  end;
  cIn.Next;  //toma el THEN
  //Ejecuta el cuerpo del THEN
//  if valor then CompileCurBlock else CompileCurBlockNoEjec;
  if PErr.HayError then exit;
  //Debe terminar con ENDIF, ELSE o ELSEIF
  if cIn.tokL = 'endif' then begin
    //Termina sentencia
    cIn.Next;  //coge delimitador y termina normal
  end else if cIn.tokL = 'else' then begin
    //Hay un bloque ELSE
    cIn.Next;  //coge "else"
//    if valor then CompileCurBlockNoEjec else CompileCurBlock;
    if PErr.HayError then exit;
    //Debe seguir el delimitador de fin
    if cIn.tokL <> 'endif' then begin
      GenError('Se esperaba "ENDIF".');
      exit;
    end;
    cIn.Next;  //coge delimitador y termina normal
  end else if cIn.tokL = 'elseif' then begin
    //Puede haber uno o varios 'elseif'
    cIn.Next;  //coge "else"
    repeat
      GetBoolExpression; //evalua expresión
      if PErr.HayError then exit;
      valor2 := res.valBool;
      if cIn.tokL<> 'then' then begin
        GenError('Se esperaba "then".');
        exit;
      end;
      cIn.Next;  //toma el THEN
      //Ejecuta el cuerpo del THEN
//      if valor2 then CompileCurBlock else CompileCurBlockNoEjec;
      if PErr.HayError then exit;
      //Solo puede seguir ELSE, ELSEIF o ENDIF
    until cIn.tokL <> 'ELSEIF';
    //Solo puede seguir ELSE, o ENDIF
    if cIn.tokL = 'endif' then begin
      //Termina sentencia
      cIn.Next;  //coge delimitador y termina normal
    end else if cIn.tokL = 'else' then begin
      //Hay un bloque ELSE en el ELSEIF
      cIn.Next;  //coge "else"
//      if valor or valor2 then CompileCurBlockNoEjec else CompileCurBlock;
      if PErr.HayError then exit;
      //Debe seguir el delimitador de fin
      if cIn.tokL <> 'endif' then begin
        GenError('Se esperaba "ENDIF".');
        exit;
      end;
      cIn.Next;  //coge delimitador y termina normal
    end;
  end else begin  //Debe ser error
    GenError('Se esperaba "ENDIF", "ELSE" o "ELSEIF".');
    exit;
  end;
end;
procedure TCompiler.ResetCompiler;
{Reinicia toda la maquinaria del compilador}
begin
  Perr.IniError;
  ClearVars;       //limpia las variables
  ClearFuncs;      //limpia las funciones
  mem.Clear;       //limpia salida
  cIn.ClearAll;    //elimina todos los Contextos de entrada
  ExprLevel := 0;  //inicia
end;
procedure TCompiler.ExecuteInstruction;
{Ejecuta una instrucción del contexto actual, desde la posición actual, hasta enocntrar
el fin de la instrucción o el fin del contexto. Usualmente una instrucción es de una
sola línea, pero hay instrucciones que pueden ser de varias líneas, separadas con "...".
Tanbién pueden haber instrucciones de una sola línea que incluyen a varias instrucciones
juntas como: a=1;b=2;
}
var
  tmp: string;
  EsAsign: Boolean;
begin
  cIn.SkipWhites;  //ignora comentarios inciales
  //if config.fcMacros.marLin then ;
  while not cIn.Eof and not EOBlock do begin
    {Se espera una expresión o estructura. }
    EsAsign := ProcesaAsignacion(tmp);  //Verifica si es asignación
    if Perr.HayError then exit;   //puede que se haya encontrado un error
    if EsAsign then begin  //hay identificador nuevo
      //Se asume que es la asignación a una variable
      //No hay que hacer nada. Ya todo lo hizo "ProcesaAsignacion".
    end else if cIn.tokType = tkStruct then begin  //es una estructura
      if cIn.tokL = 'if' then begin  //condicional
        CompileBlockIF;
        if HayError then exit;
      end else begin
        GenError('Error de diseño. Estructura no implementada.');
        exit;
      end;
    end else begin  //debe ser una expresión
      GetExpression(0);
      if perr.HayError then exit;   //aborta
    end;
    //Se espera delimitador
    if cIn.Eof then break;  //Fin de contexto es delimitador de expresión
    //Busca delimitador de bloque
    cIn.SkipWhitesNoEOL;
    if cIn.tokType=tkEol then begin //Salto de línea es delimitador de expresión
      break;
//    end else if EOBlock then begin  //hay delimitador de bloque
//      exit;  //no lo toma
    end else begin  //hay otra cosa, debe ser un error.
      GenError('Error de sintaxis.');
      exit;
    end;
  end;
end;
procedure TCompiler.ExecuteStr(str: string);
{Ejecuta la isntrucción que está en una cadena de texto.
Solo debe haber una instrucción en la cadena. De otra forma se generará un error.
Notar que no restaura el estado de la máquina virtual, de modo que se puede ejecutar
instrucciones sucesivas}
begin
  Perr.Clear;
  cIn.NewContextFromTxt(str,'');
  ExecuteInstruction;
  //Puede salir con error
  if HayError then exit;
  if not cIn.Eof then begin
    //Algo ha quedado sin proesar
    GenError('Error de sintaxis: ' + cIn.tok);
    exit;       //sale
  end;
  cIn.RemoveContext;
end;
{procedure TCompiler.CompileCurBlock;
//Compila el bloque de código actual hasta encontrar un delimitador de bloque.
var
  tmp: string;
  EsAsign: Boolean;
begin
  cIn.SkipWhites;  //ignora comentarios inciales
  //if config.fcMacros.marLin then ;
  while not cIn.Eof and not EOBlock do begin
    {Se espera una expresión o estructura. No hay problema en llamar a ProcesaAsignacion(),
     para procesar asignaciones con "=", ya que CompileCurBlock(), no se ejecuta al
     procesar las expresiones booleanas de un IF o un WHILE. }
    EsAsign := ProcesaAsignacion(tmp);  //Verifica si es asignación
    if Perr.HayError then exit;   //puede que se haya encontrado un error
    if EsAsign then begin  //hay identificador nuevo
      //Se asume que es la asignación a una variable
      //No hay que hacer nada. Ya todo lo hizo "ProcesaAsignacion".
    end else if cIn.tokType = tkStruct then begin  //es una estructura
      if cIn.tokL = 'if' then begin  //condicional
        CompileBlockIF;
        if HayError then exit;
      end else begin
        GenError('Error de diseño. Estructura no implementada.');
        exit;
      end;
    end else begin  //debe ser una expresión
      GetExpression(0);
      if perr.HayError then exit;   //aborta
    end;
    //Se espera delimitador
    if cIn.Eof then break;  //sale por fin de archivo
    //Busca delimitador de bloque
    cIn.SkipWhitesNoEOL;
    if cIn.tokType=tkEol then begin //encontró delimitador de expresión
      cIn.Next;   //lo toma
      cIn.SkipWhites;  //quita espacios
    end else if EOBlock then begin  //hay delimitador de bloque
      exit;  //no lo toma
    end else begin  //hay otra cosa, debe ser un error.
      GenError('Error de sintaxis.');
      exit;
    end;
  end;
end;

procedure TCompiler.CompilarArc;
//Compila un programa en el contexto actual
begin
//  CompilarAct;
  Perr.Clear;
  cIn.SkipWhites;
  if cIn.Eof then begin
//    GenError('Se esperaba "begin", "var", "type" o "const".');
    exit;
  end;
  //empiezan las declaraciones
  Cod_StartData;
  Cod_StartProgram;
  //codifica el contenido
  CompileCurBlock;   //compila el cuerpo
  if Perr.HayError then exit;
  if not cIn.Eof then begin
    //Algo ha quedado sin proesar
    GenError('Error de sintaxis: ' + cIn.tok);
    exit;       //sale
  end;
  cIn.Next;   //coge "end"
end;}
{procedure TCompiler.Compilar(NombArc: string; LinArc: Tstrings);
//Ejecuta el contenido de un archivo
begin
  //se pone en un "try" para capturar errores y para tener un punto salida de salida
  //único
  if ejecProg then begin
    GenError('Ya se está ejecutando un programa actualmente.');
    exit;  //sale directamente
  end;
  try
    ejecProg := true;  //marca bandera
    frmPrincipal.ejecMac := true;  //indica que se está ejecutando la macro
    ResetCompiler;
    //compila el archivo abierto

  //  con := PosAct;   //Guarda posición y referencia a contenido actual
    cIn.NewContextFromFile(NombArc,LinArc);   //Crea nuevo contenido
    if PErr.HayError then exit;
    CompilarArc;     //puede dar error
    Cod_EndProgram;  //da oportunidad de hacer verificaciones
    cIn.RemoveContext;   //es necesario por dejar limpio
    if PErr.HayError then exit;   //sale
  //  PosAct := con;   //recupera el contenido actual

  //  PPro.GenArchivo(ArcSal);
  //  ShowResult;  //muestra el resultado
  finally
    ejecProg := false;
    //tareas de finalización
    frmPrincipal.ejecMac := false;
    frmPRincipal.ActualizarInfoPanel0;
  end;
end;
}
procedure TCompiler.CreateVariable(const varName: string; typ: ttype);
begin
  Inherited;
end;
procedure TCompiler.CreateVariable(varName, varType: string);
begin
  Inherited;
end;
procedure TCompiler.CaptureParams;
//Lee los parámetros de una función en la función interna funcs[0]
begin
  cIn.SkipWhitesNoEOL;
  func0.ClearParams;   //inicia parámetros
  if EOBlock or EOExpres then begin
    //no tiene parámetros
  end else begin
    //debe haber parámetros
    repeat
      GetExpression(0, true);  //captura parámetro
      if perr.HayError then exit;   //aborta
      //guarda tipo de parámetro, para después comparar todos los parámetros leídos
      func0.CreateParam('', res.typ);
      if cIn.tok = ',' then begin
        cIn.Next;   //toma separador
        cIn.SkipWhitesNoEOL;
      end else begin
        //no sigue separador de parámetros,
        //debe terminar la lista de parámetros
        //¿Verificar EOBlock or EOExpres ?
        break;
      end;
    until false;
  end;
end;
procedure TCompiler.SkipWhites;
{En este lenguaje, se consideran delimitadores a los saltos de línea, así que no se
 deben saltar.}
begin
  cIn.SkipWhitesNoEOL;
end;
//procedure TCompilerBase.ShowError
constructor TCompiler.Create;
begin
  inherited Create;
  mem := TStringList.Create;  //crea lista para almacenar ensamblador
  //se puede definir la sintaxis aquí o dejarlo para DefineSyntax()
  DefineSyntax;     //Debe hacerse solo una vez al inicio
  DefineOperations;
  if HayError then ShowError;
end;
destructor TCompiler.Destroy;
begin
  mem.Free;  //libera
  inherited Destroy;
end;

initialization
  //Es necesario crear solo una instancia del compilador.
  cxp := TCompiler.Create;  //Crea una instancia del compilador

finalization
  cxp.Destroy;
end.


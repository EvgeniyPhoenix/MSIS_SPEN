program msis_spen;

{$APPTYPE CONSOLE}

uses
  Windows, SysUtils, RegExpr;

type
  TMethodsList = array of string;
  TSpenStats  = ^PSpenStats;
  PSpenStats  = record
                  Spen: array of Integer;
                  ID: array of string;
                end;

const
  FILEWAY = 'G:\вторник\msis_spen\msis\source.txt';
  JAVATYPES ='(byte|short|int|long|float|double|boolean|char|Integer|Long|Float|Double|Boolean|Character|String|StringBuilder|StringBuffer|' +
  'ArrayList<[_a-zA-z]\w*?>|List<[_a-zA-z]\w*?>|Set<[_a-zA-z]\w*?>|Queue<[_a-zA-z]\w*?>|Object|FileInputStream|FileOutputStream|ObjectInput|ObjectOutput|File|void)';

var
  codeSource: string;
  regExp: TRegExpr;
  globalIdList: TSpenStats;
  methods: TMethodsList;

function ReadFile:string;
var
  srcfile: TextFile;
  temp: string;
begin
  AssignFile(srcfile, FILEWAY);
  Reset(srcfile);
  Result:= '';
  while not Eof(srcfile) do
  begin
    Readln(srcfile, temp);
    Result:= Result + temp + #13#10;
  end;
  CloseFile(srcfile);
end;
 
procedure DeleteComments(var codeSrc: string) ;
begin
  regExp.ModifierM:= True;
  regExp.Expression:='//.*?$';
  codeSrc:= regExp.Replace(codeSrc,'');
  regExp.ModifierS:= True;
  regExp.Expression:='/\*.*?\*/';
  codeSrc:= regExp.Replace(codeSrc,'');
  regExp.ModifierS:= False;
end;
 
procedure DeleteLiterals(var codeSrc: string) ;
begin
  regExp.Expression:='''.?''';
  codeSrc:= regExp.Replace(codeSrc,'''''');
  regExp.Expression:='".*?"';
  codeSrc:= regExp.Replace(codeSrc,'""');
end;
 
function SplitMethods(var codeSrc: string):TMethodsList;
var
  offset, methodsCounter, codeDepth: Integer;
begin
  regExp.ModifierS:= True;
  regExp.InputString:= codeSrc;
  regExp.Expression:= '\b' + JAVATYPES + '\s(([_a-zA-z0-9]+)\(.*?\))';
  if regExp.Exec then
  begin
    methodsCounter:= 1;
    while regExp.ExecNext do
    begin
      Inc(methodsCounter);
    end;
    SetLength(Result, methodsCounter);
  end;
  methodsCounter:= -1;
  while regExp.Exec(codeSrc) do
  begin
    offset:= regExp.MatchPos[0] + regExp.MatchLen[0];
    codeDepth:= 0;
    while codeSrc[offset] <> '{' do Inc(offset);
    repeat
      if codeSrc[offset] = '{' then
        Inc(codeDepth);
      if codeSrc[offset] = '}' then
        Dec(codeDepth);
      Inc(offset);
    until (codeDepth = 0);
    Inc(methodsCounter);
    Result[methodsCounter]:= Copy(codeSrc, regExp.MatchPos[0], offset - regExp.MatchPos[0]);
    Delete(codeSrc, regExp.MatchPos[0], offset - regExp.MatchPos[0]);
  end;
end;

function FindIDs(var codeSrc: string):TSpenStats;
var
  idCounter: Integer;
begin
  New(Result);
  regExp.InputString:= codeSrc;
  regExp.Expression:=JAVATYPES + '\s([_a-zA-z0-9]+)';
  if regExp.Exec then
  begin
    idCounter:= 1;
    while regExp.ExecNext do
    begin
      Inc(idCounter);
    end;
    SetLength(Result.Spen, idCounter);
    SetLength(Result.ID, idCounter);
  end;
  if regExp.Exec then
  begin
    idCounter:= 0;
    Result.ID[idCounter]:= regExp.Match[2];
    Result.Spen[idCounter]:= 0;
    while regExp.ExecNext do
    begin
      Inc(idCounter);
      Result.ID[idCounter]:= regExp.Match[2];
      Result.Spen[idCounter]:= 0;
    end;
  end;
end;
 
procedure MethodsAnalysis(var methods: TMethodsList; var globals: TSpenStats);
var
  output: TextFile;
  locals: TSpenStats;
  i, j, k: Integer;
  globalOverlay: Boolean;
begin
  AssignFile(output, 'F:\msis_spen\output.txt');
  Rewrite(output);
  for i:= 0 to Length(methods) - 1 do
  begin
    locals:= findIDs(methods[i]);
    regExp.InputString:= methods[i];
    regExp.Expression:= '[^\.\w]' + locals.ID[0] + '[^\w]';
    if regExp.Exec then
    begin
      Writeln('Func #', i + 1, ': ', locals.ID[0], #13#10);
      Writeln(output, 'Func #', i + 1, ': ', locals.ID[0], #13#10);
    end;
    for j:= 1 to Length(locals.Spen) - 1 do
    begin
      regExp.Expression:= '[^\.\w]' + locals.ID[j] + '[^\w]';
      if regExp.Exec then
      begin
        Inc(locals.Spen[j]);
        while regExp.ExecNext do
        begin
          Inc(locals.Spen[j]);
        end;
        Writeln(locals.ID[j], ' - ', locals.Spen[j] - 1);
        Writeln(output, locals.ID[j], ' - ', locals.Spen[j] - 1);
      end;
    end;
    for j:= 0 to Length(globals.Spen) - 1 do
    begin
      globalOverlay:= False;
      for k:= 0 to Length(locals.Spen) - 1 do
      begin
        if locals.ID[k] = globals.ID[j] then
        begin
          globalOverlay:= True;
          Break;
        end;
      end;
      if globalOverlay then
        regExp.Expression:= '[^\.\w]This\.' + globals.ID[j] + '[^\w]'
      else
        regExp.Expression:= '[^\.\w]' + globals.ID[j] + '[^\w]';
      if regExp.Exec then
      begin
        Inc(globals.Spen[j]);
        while regExp.ExecNext do
        begin
          Inc(globals.Spen[j]);
        end;
      end;
    end;
    Writeln;
    Writeln(output);
  end;
  for i:= 0 to Length(globals.Spen) - 1 do
  begin
    Writeln('Global #', i + 1, ': ', globals.ID[i], ' - ', globals.Spen[i]);
    Writeln(output, 'Global #', i + 1, ': ', globals.ID[i], ' - ', globals.Spen[i]);
  end;
end;



begin
  regExp:= TRegExpr.Create;
  codeSource:= ReadFile;
  DeleteLiterals(codeSource);
  DeleteComments(codeSource);
  methods:= SplitMethods(codeSource);
  globalIdList:= FindIDs(codeSource);
  methodsAnalysis(methods, globalIdList);
  regExp.Free;
  Readln;
end.


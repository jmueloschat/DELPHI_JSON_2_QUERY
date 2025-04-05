unit uJsonCustom;

interface

uses
  SysUtils, DbxJson, Classes, Generics.Collections;

type

  XException = class(Exception)
  private
    FCode: Integer;
  public
   constructor CreateFmt(const ciCode: Integer;const csMsg: string; const Args: array of const);
   property Code: Integer read FCode;
  end;

  TXField = Class
  private
    FField: Variant;
    procedure SetAsString(const AString: String);
    function GetAsString: String;
    procedure SetAsInteger(const AInteger: Integer);
    function GetAsInteger: Integer;
    procedure SetAsFloat(const ADouble: Double);
    function GetAsFloat: Double;
    procedure SetAsBoolean(const ABoolean: Boolean);
    function GetAsBoolean: Boolean;
  public
    property AsBoolean: Boolean read GetAsBoolean write SetAsBoolean;
    property AsString: String read GetAsString write SetAsString;
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    property AsFloat: Double read GetAsFloat write SetAsFloat;
  End;

  TJsonCustomValidate = (jsvFieldNotFound, jsvFieldRepeat);
  TArrayofBoolean = Array of Boolean;

  TJsonCustom = class
  private
    FMessage: String;
    FValidate: Array[Low(TJsonCustomValidate)..High(TJsonCustomValidate)] of Boolean;
    FMainNode: TJSONObject;
    FChildrenNode: TJSONArray;
    FChildrenNodeIndex: Integer;
    FChildrenNodeCreated: Boolean;
    FNameNode: String;
    FPreparingLimit: Boolean;
    FListXField: TObjectList<TXField>;
    constructor Create; overload;
    function Strip(s: string): string;
    procedure InternalIndex(const csNameNode: String);
  protected
    procedure PrepareLimit;
    procedure GetGreaterEqualEx;
    property Index: String write InternalIndex;
  public
    constructor Create(const AMessage: String); overload;
    constructor Create(const AJSONObject: TJSONObject); overload;
    destructor Destroy; override;

    procedure Clear;
    function Eof: Boolean;
    procedure GetNext;
    procedure GetFirst;
    function FieldByName(const csFieldName: String): TXField;
    procedure SetValidate(const ceJsonCustomValidate: TJsonCustomValidate; const cbValidate: Boolean);
    function ExtractSubNodeByName(const ANodeName: String): TJsonCustom;
    function CurrentItem: TJSONObject;

    property Message: String read FMessage;
  end;

  procedure FreeAndNilJSON(json: TJsonCustom);

implementation

uses
  Character;

const
  CNT_ASPAS_DUPLAS = '$@01';
  CNT_OUTRA_COISA2 = '$@02';
  CNT_OUTRA_COISA3 = '$@03';
  //...

{ TJsonCustom }
procedure FreeAndNilJSON(json: TJsonCustom);
begin
  if   TJSONObject(json).ToString <> 'null' then
      FreeAndNil(json);
end;
constructor TJsonCustom.Create;
begin
  inherited;
  FChildrenNodeCreated := False;
  FChildrenNode := TJSONArray.Create;

  FListXField := TObjectList<TXField>.Create;
  FValidate[jsvFieldNotFound] := True;
  FValidate[jsvFieldRepeat] := True;
  Clear;
end;

constructor TJsonCustom.Create(const AMessage: String);
var loStreamArquivo: TStringStream;
begin
  FMessage := AMessage;
  Create;
  FMainNode := TJSONObject.Create;
  loStreamArquivo := TStringStream.Create;
  try
    loStreamArquivo.WriteString(Strip(AMessage));
    FMainNode.Parse(loStreamArquivo.Bytes,0);
  finally
    FreeAndNil(loStreamArquivo);
  end;
end;

constructor TJsonCustom.Create(const AJSONObject: TJSONObject);
begin
  Create;
  FMainNode := AJSONObject;
end;

destructor TJsonCustom.Destroy;
var loXField: TXField;
begin
  FreeAndNil(FMainNode);
  FreeAndNil(FChildrenNode);
  FreeAndNil(FListXField);
  inherited;
end;

function TJsonCustom.FieldByName(const csFieldName: String): TXField;
var
  j,c: Integer;
  Aitem: TJSONObject;
  loJSONArray: TJSONArray;
  lbCampoEncontrado: boolean;
begin
  if FChildrenNodeIndex = -1 then
     raise Exception.Create('Class has not been positioned, use GetFirst!');

  asm
    mov eax,0
    mov c,eax
  end;

  Result := TXField.Create;
  FListXField.Add(Result);
  Result.AsString := '';
  Aitem := TJSONObject(FChildrenNode.Get(FChildrenNodeIndex));

  for j := 0 to Aitem.Size -1 do
    begin
      try
        lbCampoEncontrado := ( Aitem.Get(j).JsonString.Value = csFieldName) ;
      except
        break; //field not found
      end;
      if   ( lbCampoEncontrado) then
           begin
             if Aitem.Get(j).JsonValue is TJSONArray then
                raise Exception.CreateFmt('Field %s is array! Index %d Message: %s',[csFieldName,FChildrenNodeIndex,Aitem.ToString]);
             if Aitem.Get(j).JsonValue is TJSONTrue then
               Result.AsBoolean := True
             else if Aitem.Get(j).JsonValue is TJSONFalse then
               Result.AsBoolean := False
             else
               Result.AsString := Aitem.Get(j).JsonValue.Value;

             asm
               Inc c
             end;
           end;
    end;

  if FValidate[jsvFieldNotFound] and (c = 0) then
     raise Exception.CreateFmt('Field %s not found',[csFieldName]);

  if FValidate[jsvFieldRepeat] and (c > 1) then
     raise Exception.CreateFmt('Field %s repeated %d times',[csFieldName,c]);
end;

procedure TJsonCustom.Clear;
var i: Integer;
begin
  FreeAndNil(FChildrenNode);
  FChildrenNode := TJSONArray.Create;

  FChildrenNodeCreated := False;
  FChildrenNodeIndex := -1;
  FPreparingLimit := False;
  FNameNode := EmptyStr;
end;

procedure TJsonCustom.GetFirst;
var j: Integer;
begin
  Clear;

  j := 0;
  while (j < FMainNode.Size)
    and (FNameNode = EmptyStr) do
        begin
          FNameNode := FMainNode.Get(j).JsonString.Value;
          Inc(j);
        end;

  Index := FNameNode;
  PrepareLimit;
  GetGreaterEqualEx;
end;

procedure TJsonCustom.GetGreaterEqualEx;
begin
  FPreparingLimit := False;
end;

procedure TJsonCustom.GetNext;
begin
  Inc(FChildrenNodeIndex);
end;

function TJsonCustom.Eof: Boolean;
var
  Aitem: TJSONObject;
  isNull: Boolean;
begin
  if FChildrenNodeIndex = 0 then
  begin
    Aitem := TJSONObject(FChildrenNode.Get(FChildrenNodeIndex));
    isNull := Aitem.ToString = 'null';
    result := (FChildrenNodeIndex < FChildrenNode.Size) and not isNull;
  end
  else
    result := (FChildrenNodeIndex < FChildrenNode.Size);

  result := not result;
end;

procedure TJsonCustom.PrepareLimit;
begin
  FPreparingLimit := True;
  FChildrenNodeIndex := 0;
end;

procedure TJsonCustom.setValidate(const ceJsonCustomValidate: TJsonCustomValidate; const cbValidate: Boolean);
begin
  FValidate[ceJsonCustomValidate] := cbValidate;
end;

procedure TJsonCustom.InternalIndex(const csNameNode: String);
var j,c: Integer;
begin
  FNameNode := csNameNode;

  asm
    mov eax,0
    mov c,eax
  end;

  for j := 0 to FMainNode.Size -1 do
    begin
      if   (FMainNode.Get(j).JsonString.Value =  FNameNode)
      and  (FMainNode.Get(j).JsonValue is TJSONArray) then
           begin
             FreeAndNil(FChildrenNode);
             FChildrenNode := TJSONArray(FMainNode.Get(j).JsonValue.Clone);
             asm
               Inc c
             end;
           end;
    end;

  if c = 0 then
     begin
       for j := 0 to FMainNode.Size -1 do
         begin
           if   (FMainNode.Get(j).JsonString.Value =  FNameNode)
           and  not (FMainNode.Get(j).JsonValue is TJSONArray) then
                begin
                  FChildrenNodeCreated := True;
                  FChildrenNode.AddElement( TJSONValue(FMainNode.Get(j).Jsonvalue.Clone) );
                  asm
                    Inc c
                  end;
                end;
         end;
     end;

  if c = 0 then
     raise Exception.CreateFmt('Node %s not found!',[FNameNode]);

  if c > 1 then
     raise Exception.CreateFmt('Node %s repeated %d times!',[FNameNode,c]);
end;

function TJsonCustom.Strip(s: string): string;
var
  ch: char; inString: boolean;
  replace: String;
  i: Integer;
begin
  i:=0;
  Result := '';
  inString := false;
  for ch in s do
  begin
    Inc(i);

    if (ch = '"')
    and ((s[i-1] in [':',',','{']) or (s[i+1] in [':',',','}']))then
      inString := not inString;

    if TCharacter.IsWhiteSpace(ch) and not inString then
      continue;

    replace := '';
    if ch in ['\','"']  then
    begin
      case ch of
        '\': replace := '/';
        '"':
          begin
            if not(s[i-1] in [':',',','{'])
            and not(s[i+1] in [':',',','}']) then
              replace := CNT_ASPAS_DUPLAS;
          end;
      end;
    end;

    if replace <> '' then
       Result := Result + replace
    else Result := Result + ch;
  end;
end;

function TJsonCustom.CurrentItem: TJSONObject;
var Aitem: TJSONObject;
begin
  try
    Aitem := TJSONObject(FChildrenNode.Get(FChildrenNodeIndex));
    Result := Aitem;
  except
    Result := nil;
  end;
end;

function TJsonCustom.ExtractSubNodeByName(const ANodeName: String): TJsonCustom;
var
  j,c: Integer;
  loJSONObject: TJSONObject;
  Aitem: TJSONObject;
begin
  asm
    mov eax,0
    mov c,eax
  end;
  Result := nil;
  Aitem := TJSONObject(FChildrenNode.Get(FChildrenNodeIndex));
  for j := 0 to Aitem.Size -1 do
    begin
      if   Aitem.Get(j).JsonString.Value = ANodeName then
           begin
             loJSONObject := TJSONObject.Create;
             Result := TJsonCustom.Create(loJSONObject);

             if   Aitem.Get(j).JsonValue is TJSONArray then
                  begin
                    loJSONObject.AddPair( TJSONPair.Create(ANodeName, TJSONArray(Aitem.Get(j).JsonValue.Clone)) );
                  end
             else
                  begin
                    loJSONObject.AddPair( TJSONPair.Create(ANodeName, TJSONValue(Aitem.Get(j).Jsonvalue.Clone)) );
                  end;
             asm
               Inc c
             end;
           end;
    end;

  if FValidate[jsvFieldNotFound] and (c = 0) then
     raise Exception.CreateFmt('Sub-Node %s not found!',[ANodeName]);

  if FValidate[jsvFieldRepeat] and (c > 1) then
     raise Exception.CreateFmt('Sub-Node %s repeated %d times!',[ANodeName,c]);
end;

{ TXField }
function TXField.GetAsBoolean: Boolean;
begin
  Result := FField;
end;

function TXField.GetAsFloat: Double;
begin
  if FField = EmptyStr then
     Result := 0
  else Result := FField;
end;

function TXField.GetAsInteger: Integer;
begin
  if FField = EmptyStr then
     Result := 0
  else Result := FField;
end;

function TXField.GetAsString: String;
begin
  Result := StringReplace(FField,CNT_ASPAS_DUPLAS,'"',[rfReplaceAll]);
end;

procedure TXField.SetAsBoolean(const ABoolean: Boolean);
begin
  FField := ABoolean;
end;

procedure TXField.SetAsFloat(const ADouble: Double);
begin
  FField := ADouble;
end;

procedure TXField.SetAsInteger(const AInteger: Integer);
begin
  FField := AInteger;
end;

procedure TXField.SetAsString(const AString: String);
begin
  FField := AString;
end;

{ XException }
constructor XException.CreateFmt(const ciCode: Integer; const csMsg: string; const Args: array of const);
begin
  FCode := ciCode;
  inherited CreateFmt(csMsg,Args);
end;

end.

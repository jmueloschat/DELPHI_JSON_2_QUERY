unit ufrmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  uJsonCustom
  ,StrUtils
  ;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
var
  loJsonCustom: TJsonCustom;
  loFileJSON: TStringList;
begin
  loFileJSON := TStringList.Create;
  loFileJSON.LoadFromFile('file.json');
  loJsonCustom := TJsonCustom.Create(loFileJSON.Text);
  try
    loJsonCustom.GetFirst;
    if not loJsonCustom.Eof then
      begin
       Memo1.Lines.Add(loJsonCustom.FieldByName('fieldString').AsString);
       Memo1.Lines.Add(FloatToStr(loJsonCustom.FieldByName('fieldDouble').AsFloat));
       Memo1.Lines.Add(IntToStr(loJsonCustom.FieldByName('fieldInteger').AsInteger));
       Memo1.Lines.Add(ifthen(loJsonCustom.FieldByName('fieldBoolean').AsBoolean,'true','false'));
      end;
  finally
    FreeAndNil(loFileJSON);
    FreeAndNil(loJsonCustom);
  end;
end;

end.

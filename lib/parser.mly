%{
open Ast
%}

%token <int>       INT
%token <string>    STRING
%token             TRUE FALSE
%token <string>    IDENT

%token             POD SERVICE VOLUME ENUM
%token             LBRACE RBRACE LBRACK RBRACK
%token             COMMA ASSIGN
%token             EOF

%start program
%type <Ast.program> program

%%

program:
  | decl_list EOF { $1 }

decl_list:
  | decl                { [$1] }
  | decl_list decl      { $1 @ [$2] }

decl:
  | POD STRING LBRACE field_list RBRACE
      { Pod ($2, $4) }
  | SERVICE STRING LBRACE field_list RBRACE
      { Service ($2, $4) }
  | VOLUME STRING LBRACE field_list RBRACE
      { Volume ($2, $4) }
  | ENUM STRING LBRACE string_list RBRACE
    { Enum ($2, List.rev $4) }

field_list:
  | /* empty */         { [] }
  | field               { [$1] }
  | field_list field    { $1 @ [$2] }

field:
  | IDENT ASSIGN literal
      { Field ($1, $3) }

literal:
  | INT                 { Int $1 }
  | STRING              { String $1 }
  | TRUE                { Bool true }
  | FALSE               { Bool false }
  | LBRACK literal_list RBRACK { List(List.rev $2) }

literal_list:
  | /* empty */                 { [] }
  | literal                    { [$1] }
  | literal COMMA literal_list { $1 :: $3 }

string_list:
  | /* empty */                 { [] }
  | STRING                      { [$1] }
  | STRING COMMA string_list   { $1 :: $3 }


%{
open Ast
%}

%token <int>       INT
%token <string>    STRING
%token             TRUE FALSE
%token <string>    IDENT

%token             POD SERVICE VOLUME ENUM SECRET
%token             LBRACE RBRACE LBRACK RBRACK
%token             COMMA ASSIGN
%token             EOF

%start program
%type  <Ast.program> program

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

  | SECRET STRING LBRACE secret_body RBRACE
      { Secret ($2, $4) }

secret_body:
  | IDENT ASSIGN literal
      { if $1 = "value"
        then $3
        else failwith "secret block must be { value = <literal> }" }

field_list:
  |               /* empty */   { [] }
  | field                      { [$1] }
  | field_list field           { $1 @ [$2] }

field:
  | IDENT ASSIGN literal
      { Field ($1, $3) }

literal:
  | INT                         { Int   $1 }
  | STRING                      { String $1 }
  | TRUE                        { Bool  true }
  | FALSE                       { Bool  false }
  | LBRACK literal_list RBRACK  { List (List.rev $2) }
  | LBRACE obj_field_list RBRACE{ Object (List.rev $2) }
  | SECRET STRING               { SecretRef $2 }

literal_list:
  |                             /* empty */ { [] }
  | literal                              { [$1] }
  | literal COMMA literal_list           { $1 :: $3 }

obj_field_list:
  |                             /* empty */ { [] }
  | obj_field                             { [$1] }
  | obj_field_list obj_field              { $1 @ [$2] }

obj_field:
  | IDENT ASSIGN literal                  { ($1, $3) }

string_list:
  |                             /* empty */ { [] }
  | STRING                                 { [$1] }
  | STRING COMMA string_list               { $1 :: $3 }

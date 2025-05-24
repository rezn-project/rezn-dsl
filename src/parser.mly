%{
open Ast

module VarEnv = struct
  let params = ref []
  let fields = ref []

  let reset () = params := []; fields := []

  let add_param name = params := name :: !params
  let add_field name = fields := name :: !fields

  let classify name =
    if List.mem name !params then Param
    else if List.mem name !fields then Field
    else Local  (* fallback *)
end

let empty_contract = {
  pre = None;
  post = None;
  invariant = None;
}

let merge_clauses clauses =
  List.fold_left (fun acc c ->
    match c with
    | `Pre e -> { acc with pre = Some e }
    | `Post e -> { acc with post = Some e }
    | `Invariant e -> { acc with invariant = Some e }
  ) empty_contract clauses
%}

%left OR
%left AND
%nonassoc EQ NEQ
%nonassoc LT GT LE GE
%left PLUS MINUS
%left STAR SLASH

%token <string> IDENT
%token <string> STRINGLIT
%token <string> INT

%token POD SERVICE VOLUME ENUM CONTRACT
%token PRE POST INVARIANT
%token LPAREN RPAREN LBRACE RBRACE
%token COLON COMMA DOT ASSIGN
%token EQ NEQ LT GT LE GE
%token AND OR
%token TRUE FALSE
%token EOF

%start <Ast.declaration list> declarations
%type <Ast.expr> expr
%type <Ast.expr list> expr_list
%%

declarations:
  | declaration* EOF { $1 }

declaration:
  | POD STRINGLIT LBRACE fields contract_block RBRACE {
      Pod($2, $4, $5)
    }

fields:
  | field*
    { $1 }

field:
  | IDENT ASSIGN expr
    { Field($1, $3) }

contract_block:
  | CONTRACT LBRACE contract_clauses RBRACE
    { $3 }

contract_clauses:
  | /* empty */ { empty_contract }
  | clause_list { merge_clauses $1 }

clause_list:
  | clause { [$1] }
  | clause clause_list { $1 :: $2 }

clause:
  | PRE ASSIGN expr { `Pre $3 }
  | POST ASSIGN expr { `Post $3 }
  | INVARIANT ASSIGN expr { `Invariant $3 }

expr:
  | INT              { IntLit(int_of_string $1) }
  | STRINGLIT        { StringLit($1) }
  | TRUE             { BoolLit(true) }
  | FALSE            { BoolLit(false) }
  | IDENT            { Var($1) }
  | expr DOT IDENT   { FieldAccess($1, $3) }
  | expr EQ expr     { BinOp(Eq, $1, $3) }
  | expr NEQ expr    { BinOp(Neq, $1, $3) }
  | expr AND expr    { BinOp(And, $1, $3) }
  | expr OR expr     { BinOp(Or, $1, $3) }
  | expr GT expr     { BinOp(Gt, $1, $3) }
  | expr LT expr     { BinOp(Lt, $1, $3) }
  | expr GE expr     { BinOp(Ge, $1, $3) }
  | expr LE expr     { BinOp(Le, $1, $3) }
  | IDENT LPAREN expr_list RPAREN { Call($1, $3) }

expr_list:
  | expr { [$1] }
  | expr COMMA expr_list { $1 :: $3 }


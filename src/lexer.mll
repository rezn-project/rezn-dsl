{
open Parser
}

rule read = parse
  | [' ' '\t' '\r' '\n']  { read lexbuf }
  | "pod"                 { POD }
  | "contract"            { CONTRACT }
  | "pre"                 { PRE }
  | "post"                { POST }
  | "invariant"           { INVARIANT }
  | "true"                { TRUE }
  | "false"               { FALSE }
  | "{"                   { LBRACE }
  | "}"                   { RBRACE }
  | "("                   { LPAREN }
  | ")"                   { RPAREN }
  | "="                   { ASSIGN }
  | "=="                  { EQ }
  | "!="                  { NEQ }
  | "<="                  { LE }
  | ">="                  { GE }
  | "<"                   { LT }
  | ">"                   { GT }
  | "&&"                  { AND }
  | "||"                  { OR }
  | "."                   { DOT }
  | ","                   { COMMA }
  | ['0'-'9']+ as i       { INT i }
  | ['a'-'z' 'A'-'Z' '_']['a'-'z' 'A'-'Z' '0'-'9' '_' '.']* as id
                          { IDENT id }
  | '"' ([^ '"']* as s) '"' { STRINGLIT s }
  | eof                   { EOF }
  | _                     { failwith "Unrecognized token" }

open In_channel
open Ast

exception Parse_error of string
exception Lexer_error of string

let parse_file (filename : string) : program =
  with_open_text filename (fun chan ->
    let lexbuf = Lexing.from_channel chan in
    try
      Parser.program Lexer.token lexbuf
    with
    | Parser.Error ->
        let pos = lexbuf.lex_curr_p in
        let msg = Printf.sprintf "Syntax error at line %d, column %d"
          pos.pos_lnum (pos.pos_cnum - pos.pos_bol) in
        raise (Parse_error msg)
    | Failure msg ->
        raise (Lexer_error msg)
  )

let parse_string (source : string) : program =
  let lexbuf = Lexing.from_string source in
  try
    Parser.program Lexer.token lexbuf
  with
  | Parser.Error ->
      let pos = lexbuf.lex_curr_p in
      let msg = Printf.sprintf "Syntax error at line %d, column %d"
        pos.pos_lnum (pos.pos_cnum - pos.pos_bol) in
      raise (Parse_error msg)
  | Failure msg ->
      raise (Lexer_error msg)

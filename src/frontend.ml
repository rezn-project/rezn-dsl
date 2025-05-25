open In_channel
open Ast

let parse_file (filename : string) : program =
  with_open_text filename (fun chan ->
    let lexbuf = Lexing.from_channel chan in
    try
      Parser.program Lexer.token lexbuf
    with
    | Parser.Error ->
        let pos = lexbuf.lex_curr_p in
        Printf.eprintf "Syntax error at line %d, column %d\n"
          pos.pos_lnum (pos.pos_cnum - pos.pos_bol);
        exit 1
    | Failure msg ->
        Printf.eprintf "Lexer error: %s\n" msg;
        exit 1
  )

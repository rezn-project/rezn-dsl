open Lexing
open Codegen
open In_channel

let () =
  if Array.length Sys.argv <> 2 then begin
    Printf.eprintf "Usage: %s <file.rezn>\n" Sys.argv.(0);
    exit 1
  end;

  let filename = Sys.argv.(1) in

  with_open_text filename (fun chan ->
    let lexbuf = Lexing.from_channel chan in

    try
      let prog = Parser.program Lexer.token lexbuf in
      let json = program_to_json prog in
      Yojson.Basic.pretty_to_channel stdout json;
      print_newline ()
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

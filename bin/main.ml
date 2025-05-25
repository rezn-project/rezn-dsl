open Rezn.Frontend

let () =
  if Array.length Sys.argv <> 2 then begin
    Printf.eprintf "Usage: %s <file.rezn>\n" Sys.argv.(0);
    exit 1
  end;

  let filename = Sys.argv.(1) in
  try
    let prog = parse_file filename in
    let json = Rezn.Codegen.program_to_json prog in
    Yojson.Basic.pretty_to_channel stdout json;
    print_newline ()
  with
  | Rezn.Frontend.Parse_error msg ->
      Printf.eprintf "%s\n" msg;
      exit 1
  | Rezn.Frontend.Lexer_error msg ->
      Printf.eprintf "Lexer error: %s\n" msg;
      exit 1
  
